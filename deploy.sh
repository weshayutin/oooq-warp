#!/bin/bash
# Wrap oooq with ansible
# It may as well prepare VMs by fuel-devops
# requires ansible in the given venv or host
# must be executed from the oooq root dir
set -uxe

WORKSPACE=${WORKSPACE:-/tmp/scripts}
ADMIN_USER=${USER:-admin}
ADMIN_KEY=${USER_KEYFILE:-${HOME}/.ssh/id_rsa}
CONF_PATH=${CONF_PATH:-${WORKSPACE}/fuel-devops-oooq.yaml}
ENV_NAME=${ENV_NAME:-oooq-warp}
SLAVES_COUNT=${SLAVES_COUNT:-0}
IMAGE_PATH=${IMAGE_PATH:-/tmp/qs/image.qcow2}
SSH_OPTIONS="-F /dev/null -i ${ADMIN_KEY}"
LOG_LEVEL=${LOG_LEVEL:--v}
ANSIBLE_TIMEOUT=${ANSIBLE_TIMEOUT:-600}
ANSIBLE_FORKS=${ANSIBLE_FORKS:-10}
TEARDOWN=${TEARDOWN:-true}

function with_retries {
    local retries=3
    set +e
    set -o pipefail
    for try in $(seq 1 $retries); do
        ${@}
        [ $? -eq 0 ] && break
        if [ "$try" = "$retries" ]; then
            exit 1
        fi
    done
    set +o pipefail
    set -e
}

function with_ansible {
    local tries=5
    local retry_opt=""
    playbook=$1
    retryfile=${playbook/.yml/.retry}

    until \
        ANSIBLE_CONFIG=ansible.cfg \
        ansible-playbook \
        --ssh-extra-args "-A\ -o\ StrictHostKeyChecking=no" -u $ADMIN_USER -b \
        --become-user=root -i ${WORKSPACE}/inventory.ini \
        --forks=$ANSIBLE_FORKS --timeout $ANSIBLE_TIMEOUT \
        -e ansible_ssh_user=${ADMIN_USER} \
        -e teardown=$TEARDOWN \
        -e @${WORKSPACE}/nodes.yaml \
        $retry_opt $LOG_LEVEL $@; do
            if [ $tries -gt 1 ]; then
                tries=$((tries - 1))
                echo "Deployment failed! Trying $tries more times..."
            else
                exit 1
            fi

            if test -e "$retryfile"; then
                retry_opt="--limit @${retryfile}"
            fi
    done
    rm -f "$retryfile" || true
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
  sudo virsh destroy undercloud
  sudo virsh undefine undercloud
fi
with_ansible ${WORKSPACE}/oooq-warp.yaml
#with_ansible playbooks/libvirt-teardown.yml
#with_ansible playbooks/libvirt-setup.yml
#...
