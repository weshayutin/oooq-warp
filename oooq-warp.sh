#!/bin/bash
# Wrap OS of the given active user with the centos7 box and oooq
set -uxe

DEV=${DEV:-/dev/sda}
IOPSW=${IOPSW:-25}
IOPSR=${IOPSR:-35}
IOW=${IOW:-30mb}
IOR=${IOR:-50mb}
CPU=${CPU:-600}
MEM=${MEM:-3G}

docker run -it --rm --privileged \
  --device-read-bps=${DEV}:${IOR} \
  --device-write-bps=${DEV}:${IOW} \
  --device-read-iops=${DEV}:${IOPSR} \
  --device-write-iops=${DEV}:${IOPSW} \
  --cpus=4 --cpu-shares=${CPU} \
  --memory-swappiness=0 --memory=${MEM} \
  --net=host --pid=host --uts=host --ipc=host \
  -e USER=${USER} \
  -e OOOQ_PATH=${OOOQ_PATH} \
  -e HOME=/home/${USER} \
  -e TEARDOWN=${TEARDOWN} \
  -e VIRTUALENVWRAPPER_PYTHON=/usr/bin/python \
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
