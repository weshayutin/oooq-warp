#!/bin/bash
# Wrap oooq with ansible
# It may as well prepare VMs by fuel-devops
# requires ansible in the given venv or host
# must be executed from the oooq root dir
set -uxe

FUEL_DEVOPS=${FUEL_DEVOPS:-false}
USER=${USER:-bogdando}
WORKSPACE=/tmp/scripts
LOG_LEVEL=${LOG_LEVEL:--v}
ANSIBLE_TIMEOUT=${ANSIBLE_TIMEOUT:-900}
ANSIBLE_FORKS=${ANSIBLE_FORKS:-10}
TEARDOWN=${TEARDOWN:-true}

function with_ansible {
  ANSIBLE_CONFIG=ansible.cfg \
  ansible-playbook \
  -b --become-user=root \
  --forks=$ANSIBLE_FORKS --timeout $ANSIBLE_TIMEOUT \
  -e teardown=$TEARDOWN \
  -e @${WORKSPACE}/nodes.yaml \
   $LOG_LEVEL $@
}

echo "Trying to ensure bridge-nf-call-iptables is disabled..."
br_netfilter=$(cat /proc/sys/net/bridge/bridge-nf-call-iptables)
if [ "$br_netfilter" = "1" ]; then
    sudo sh -c 'echo 0 > /proc/sys/net/bridge/bridge-nf-call-iptables'
fi

if [ $SLAVES_COUNT -gt 0 -a $"{FUEL_DEVOPS}" != "false" ]; then
    echo "Creating VMs with fuel-devops"
    ENV_NAME=${ENV_NAME} SLAVES_COUNT=${SLAVES_COUNT} IMAGE_PATH=${IMAGE_PATH} CONF_PATH=${CONF_PATH} env.py create_env
    SLAVE_IPS=($(ENV_NAME=${ENV_NAME} env.py get_slaves_ips | tr -d "[],'"))
    echo "Created NODES: ${SLAVE_IPS}"

    echo "Now update undercloud/overcloud hosts' IPs in the inventori.ini"
    echo "by manual or magic scripts (not included)."
    echo "Customize the nodes.yaml to fit your deployment needs,"
    echo "then PRESS ANY KEY to continue with oooq deployment"
    read
fi

echo "Checking inventory nodes"
ansible -i ${WORKSPACE}/inventory.ini -m ping all
echo "Deploying with oooq"
# FIXME(bogdando) hack a failed undercloud respinning
if [ "${TEARDOWN}" = "false" ]; then
  set +e
  sudo virsh destroy undercloud
  sudo virsh undefine undercloud
  set -e
fi

inventory=${WORKSPACE}/inventory.ini
# a hack for oooq hardcoded paths
ln -sf $HOME $HOME/.quickstart
# provision by localhost inventory
with_ansible -i ${inventory} ${WORKSPACE}/oooq-warp.yaml
# undercloud by provisioned inventory if not fuel-devops provisioned VMs
[ "${FUEL_DEVOPS}" = "false" ] &&  inventory=/home/$USER/hosts
ansible -i ${inventory} -m ping all
with_ansible -i ${inventory} ${WORKSPACE}/oooq-under.yaml
echo "To login undercloud use: ssh -F ~/ssh.config.local.ansible undercloud"
