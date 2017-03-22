set -ux
# Don't create additional VMs by fuel-devops
# Add slaves_count, if you want some under/over cloud VMs
export SLAVES_COUNT=0
export SLAVE_NODE_MEMORY=4096
export SLAVE_NODE_CPU=2
export NODE_VOLUME_SIZE=30
export INTERFACE_MODEL=e1000
export IMAGE_PATH=/opt/centos7.qcow2
export CONF_PATH=fuel-devops-oooq.yaml
export ENV_NAME="${1:-oooq-warp}"
export SNAPSHOTS_EXTERNAL=false
export SNAPSHOTS_EXTERNAL_DIR=~/.devops/snap
export DEVOPS_DB_NAME=~/.devops/fuel-devops3
export DEVOPS_DB_ENGINE=django.db.backends.sqlite3
export VENV_PATH=${HOME}/.virtualenvs/devops30
