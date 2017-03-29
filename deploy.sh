#!/bin/bash
# Wrap oooq with ansible
# It may as well prepare VMs by fuel-devops
# requires ansible in the given venv or host
# must be executed from the oooq root dir
set -uxe

FUEL_DEVOPS=${FUEL_DEVOPS:-false}
USER=${USER:-bogdando}
SCRIPTS=/tmp/scripts
LOG_LEVEL=${LOG_LEVEL:--v}
ANSIBLE_TIMEOUT=${ANSIBLE_TIMEOUT:-900}
ANSIBLE_FORKS=${ANSIBLE_FORKS:-10}
TEARDOWN=${TEARDOWN:-true}
SLAVES_COUNT=${SLAVES_COUNT:-0}
PLAY=${PLAY:-oooq-warp.yaml}
WORKSPACE=${WORKSPACE:-/opt/oooq}
LWD=${LWD:-${HOME}/.quickstart}

function snap {
  set +e
  sudo virsh suspend $1
  sudo virsh snapshot-delete $1  $2
  sudo virsh snapshot-create-as --name=$2 $1 || sudo virsh snapshot $1
  sync
  sudo virsh resume $1
}

function with_ansible {
  ANSIBLE_CONFIG=ansible.cfg \
  ansible-playbook \
  --become-user=root \
  --forks=$ANSIBLE_FORKS --timeout $ANSIBLE_TIMEOUT \
  -e teardown=$TEARDOWN \
  -e @${SCRIPTS}/custom.yaml \
   $LOG_LEVEL $@
}

function with_undercloud_root {
  ssh -F ${LWD}/ssh.config.local.ansible undercloud-root $@
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
    echo "Define the custom.yaml to fit your deployment needs,"
    echo "then PRESS ANY KEY to continue with oooq deployment"
    read
fi

echo "Checking inventory nodes"
ansible -i ${SCRIPTS}/inventory.ini -m ping all
echo "Deploying with oooq"
inventory=${SCRIPTS}/inventory.ini

# provision by localhost inventory and custom work dirs vars for virthost
if [ "${TEARDOWN}" != "false" -o "${PLAY}" = "oooq-warp.yaml" ]; then
  with_ansible -u ${USER} -i ${inventory} ${SCRIPTS}/oooq-warp.yaml
  snap undercloud ready
  # save state
  sudo cp -af ${LWD}/* ${WORKSPACE}/
fi

# Use the provisioned inventory, if not used fuel-devops for provisioned VMs
[ "${FUEL_DEVOPS}" = "false" ] &&  inventory=${LWD}/hosts

# FIXME: rework stack as undercloud_user env var
function finalize {
  with_undercloud_root \
    "cp -nu /root/stackrc /home/stack/ && chown stack /home/stack/stackrc"
  with_undercloud_root \
    "which fuel-log-parse || \
    curl https://raw.githubusercontent.com/bogdando/fuel-log-parse/master/fuel-log-parse.sh >|\
    /usr/local/sbin/fuel-log-parse && chmod +x /usr/local/sbin/fuel-log-parse"
  echo "######## Captured errors: ########"
  with_undercloud_root \
    "cd /home/stack; fuel-log-parse -g -x WARN; cd /var/log; \
    fuel-log-parse -g -rfc3164; fuel-log-parse -g"
}

trap finalize EXIT

# Check undercloud node connectivity and deploy
ansible -i ${inventory} -m ping all
if [ "${PLAY}" = "oooq-under.yaml" ]; then
  # FIXME:tail logs from the undercloud VM as install.sh hides them
  ssh -F ${LWD}/ssh.config.local.ansible undercloud touch /home/stack/undercloud_install.log
  ssh -F ${LWD}/ssh.config.local.ansible undercloud tail -f /home/stack/undercloud_install.log&
  # FIXME:user and work dirs for undercloud doesn't play well with those for virthost
  with_ansible -i ${inventory} ${SCRIPTS}/oooq-under.yaml \
    -u stack -e ansible_ssh_user=stack \
    -e local_working_dir=/home/stack/.quickstart \
    -e working_dir=/home/stack
  snap undercloud deployed
elif [ "${PLAY}" != "oooq-warp.yaml" ]; then
  with_ansible -i ${inventory} ${SCRIPTS}/${PLAY}
fi
