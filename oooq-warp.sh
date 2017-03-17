#!/bin/bash
# Wrap OS of the given active user with the centos7 box and oooq
set -uxe
docker run -it --rm --privileged \
  --net=host --pid=host --uts=host --ipc=host \
  -e USER=${USER} \
  -e OOOQ_PATH=${OOOQ_PATH} \
  -e HOME=/home/${USER} \
  -e USER_KEYFILE=${USER_KEYFILE} \
  -e VIRTUALENVWRAPPER_PYTHON=/usr/bin/python \
  -v /var/lib/libvirt:/var/lib/libvirt \
  -v /run:/run \
  -v /lib/modules:/lib/modules \
  -v ${WORKSPACE}:/tmp/qs \
  -v ${HOME}/.ssh/authorized_keys:/tmp/authorized_keys:ro \
  -v ${HOME}/.ssh/known_hosts:/tmp/known_hosts:ro \
  -v ${OOOQ_PATH}:/tmp/oooq:ro \
  -v $(pwd):/tmp/scripts:ro \
  -u 1000 \
  --entrypoint /bin/bash \
  --name runner oooq-runner:0.1 \
  -c "sudo cp /tmp/scripts/*.sh /usr/local/sbin/ && \
      sudo cp /tmp/scripts/*.py /usr/local/sbin/ && \
      sudo chmod +x /usr/local/sbin/* && entry.sh"
