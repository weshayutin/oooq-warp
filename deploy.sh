#!/bin/bash
# Wrap oooq with ansible
# It may as well prepare VMs by fuel-devops
# requires ansible in the given venv or host
# must be executed from the oooq root dir
set -uxe

WORKSPACE=/tmp/scripts
ADMIN_USER=${USER:-admin}
ADMIN_KEY=${USER_KEYFILE:-${HOME}/.ssh/id_rsa}
CONF_PATH=${CONF_PATH:-${WORKSPACE}/fuel-devops-oooq.yaml}
ENV_NAME=${ENV_NAME:-oooq-warp}
SLAVES_COUNT=${SLAVES_COUNT:-0}
IMAGE_PATH=${IMAGE_PATH:-/tmp/qs/image.qcow2}
LOG_LEVEL=${LOG_LEVEL:--v}
ANSIBLE_TIMEOUT=${ANSIBLE_TIMEOUT:-600}
ANSIBLE_FORKS=${ANSIBLE_FORKS:-10}
TEARDOWN=${TEARDOWN:-true}

function with_ansible {
  ANSIBLE_CONFIG=ansible.cfg \
  ansible-playbook \
  -u $ADMIN_USER -b \
  --become-user=root -i ${WORKSPACE}/inventory.ini \
  --forks=$ANSIBLE_FORKS --timeout $ANSIBLE_TIMEOUT \
  -e ansible_ssh_user=${ADMIN_USER} \
  -e teardown=$TEARDOWN \
  -e @${WORKSPACE}/nodes.yaml \
   $LOG_LEVEL $@
}

echo "Trying to ensure bridge-nf-call-iptables is disabled..."
br_netfilter=$(cat /proc/sys/net/bridge/bridge-nf-call-iptables)
if [ "$br_netfilter" = "1" ]; then
    sudo sh -c 'echo 0 > /proc/sys/net/bridge/bridge-nf-call-iptables'
fi

if [ $SLAVES_COUNT -gt 0 ]; then
    echo "Creating VMs with fuel-devops"
    ENV_NAME=${ENV_NAME} SLAVES_COUNT=${SLAVES_COUNT} IMAGE_PATH=${IMAGE_PATH} CONF_PATH=${CONF_PATH} env.py create_env
    SLAVE_IPS=($(ENV_NAME=${ENV_NAME} env.py get_slaves_ips | tr -d "[],'"))
    echo "Created NODES: ${SLAVE_IPS}"

    echo "Now update admin/target hosts' IPs in the inventori.ini by manual,"
    echo "Ensure 'ssh -tt admin_user@admin_host sudo echo gotcha' worked,"
    echo "Customize the oooq-warp.yaml/nodes.yaml to fit your deployment needs,"
    echo "then PRESS ANY KEY to continue with oooq deployment"
    read
fi

echo "Checking inventory nodes"
ansible -u ${ADMIN_USER} -i ${WORKSPACE}/inventory.ini -m ping all
echo "Deploying with oooq"
# FIXME(bogdando) hack a failed undercloud respinning
if [ "${TEARDOWN}" = "false" ]; then
  set +e
  sudo virsh destroy undercloud
  sudo virsh undefine undercloud
  set -e
fi

# hack oooq hardocded paths
. ${WORKSPACE}/ssh_config
touch $SSH_CONFIG
ln -sf $HOME $HOME/.quickstart
with_ansible ${WORKSPACE}/oooq-warp.yaml
echo "To login undercloud use: ssh -F ~/ssh.config.local.ansible undercloud"
