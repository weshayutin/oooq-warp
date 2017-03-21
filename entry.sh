#!/bin/bash
# Stub the given user home and ssh setup
# Prepare to run oooq via ansible
set -eu
export WORKON_HOME=~/Envs
cd $HOME
sudo ln -sf /root/Envs .
sudo chown -R ${USER}: $HOME
set +u
. /usr/bin/virtualenvwrapper.sh
. ${HOME}/Envs/oooq/bin/activate
. /tmp/scripts/ssh_config
set -u
cd /tmp/oooq
echo export PLAY=oooq-under.yaml to deploy only an undercloud
echo export TEARDOWN=false to respin a failed provisioning
echo Run create_env_oooq.sh to deploy
/bin/bash
