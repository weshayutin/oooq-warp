#!/bin/bash
set -eux
useradd --create-home --shell /bin/bash ${USER}
mkdir -p /home/${USER}/.ssh
yum -y install gcc python-devel openssl-devel python-virtualenv \
  libvirt wget which sudo qemu-kvm libvirt-python \
  libguestfs-tools python-lxml polkit-pkla-compat git
echo "${USER} ALL=(root) NOPASSWD:ALL" > /etc/sudoers.d/${USER}
usermod -aG kvm ${USER}
set +u
easy_install pip
pip install -U virtualenvwrapper
echo 'export WORKON_HOME=~/Envs' >> ${HOME}/.bashrc
. $HOME/.bashrc
mkdir -p ~/Envs
echo 'export VIRTUALENVWRAPPER_PYTHON=/usr/bin/python' >> ${HOME}/.bashrc
echo '. /usr/bin/virtualenvwrapper.sh' >> ${HOME}/.bashrc
. $HOME/.bashrc
. /usr/bin/virtualenvwrapper.sh
mkvirtualenv oooq
#workon oooq
. ${HOME}/Envs/oooq/bin/activate
cd /tmp/oooq
pip install --no-cache-dir -r requirements.txt -r quickstart-extras-requirements.txt
