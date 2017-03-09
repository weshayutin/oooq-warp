#!/bin/bash
# Stub the given user home and ssh setup
# Prepare to run oooq via ansible
set -eu
export WORKON_HOME=~/Envs
sudo mkdir -p /home/${USER}/.ssh
sudo chown -R ${USER}: /home/${USER}
cd $HOME
sudo cp /tmp/authorized_keys .ssh/
sudo cp /tmp/known_hosts .ssh/
sudo cp ${USER_KEYFILE} .ssh/id_rsa
sudo ln -sf /root/Envs .
sudo chown -R ${USER}: $HOME
set +u
. /usr/bin/virtualenvwrapper.sh
#workon oooq
. ${HOME}/Envs/oooq/bin/activate
set -u
cd /tmp/oooq
ssh -tt ${USER}@localhost echo gotcha
/bin/bash
#create_env_oooq.sh
