#!/bin/bash
# Wrap OS of the given active user with the centos7 box and oooq
set -uxe

DEV=${DEV:-/dev/sda}
IOPSW=${IOPSW:-60}
IOPSR=${IOPSR:-60}
IOW=${IOW:-35mb}
IOR=${IOR:-60mb}
CPU=${CPU:-800}
MEM=${MEM:-7G}

# defaults
TEARDOWN=${TEARDOWN:-true}
USER=${USER:-bogdando}
OOOQE_BRANCH=${OOOQE_BRANCH:-master}
OOOQE_FORK=${OOOQE_FORK:-openstack}
WORKSPACE=${WORKSPACE:-/tmp/qs}
PLAY=${PLAY:-oooq-warp.yaml}
VENV=local
VMOUNT=""
[ "${VENV}" != "local" ] && VMOUNT="-v ${VPATH}:/home/${USER}/Envs"

docker run -it --rm --privileged \
  --device-read-bps=${DEV}:${IOR} \
  --device-write-bps=${DEV}:${IOW} \
  --device-read-iops=${DEV}:${IOPSR} \
  --device-write-iops=${DEV}:${IOPSW} \
  --cpus=4 --cpu-shares=${CPU} \
  --memory-swappiness=0 --memory=${MEM} \
  --net=host --pid=host --uts=host --ipc=host \
  -e USER=${USER} \
  -e PLAY=${PLAY} \
  -e OOOQ_PATH=${OOOQ_PATH} \
  -e HOME=/home/${USER} \
  -e TEARDOWN=${TEARDOWN} \
  -e VIRTUALENVWRAPPER_PYTHON=/usr/bin/python \
  -e VENV=${VENV} \
  -e OOOQE_BRANCH=${OOOQE_BRANCH} \
  -e OOOQE_FORK=${OOOQE_FORK} \
  ${VMOUNT} \
  -v /var/lib/libvirt:/var/lib/libvirt \
  -v /run:/run \
  -v /dev:/dev:ro \
  -v /lib/modules:/lib/modules \
  -v ${WORKSPACE}:/tmp/qs \
  -v ${OOOQ_PATH}:/tmp/oooq:ro \
  -v $(pwd):/tmp/scripts:ro \
  -u 1000 \
  --entrypoint /bin/bash \
  --name runner bogdando/oooq-runner:0.1 \
  -c "sudo cp /tmp/scripts/*.sh /usr/local/sbin/ && \
      sudo cp /tmp/scripts/*.py /usr/local/sbin/ && \
      sudo chmod +x /usr/local/sbin/* && entry.sh"
