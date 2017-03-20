# A warper for OOOQ

An oooq wrapper (centos7 container) that makes oooq
thinking it's running at centos, not ubuntu or the like.
While in fact it operates the host's libvirt and nested
kvm, if configured. Just like containerized nova-compute
would do.

It can also use fuel-devops to pre-create undercloud or
overcloud VMs instead of oooq (DOES NOT WORK YET).

It omits oooq's shell scripts and goes the ansible way,
which is an inventory, a play and custom vars to override.

## Build the wrapper container
```
$ packer build packer-docker-centos7.json
$ packer build packer-docker-oooq-runner.json
```

## Pre-flight checks for a warp jump

* Download overcloud/undercloud images and md5 (hereafter
  assume the work dir is /tmp/qs)
* Extract initrd and vmlinuz (does not work from the
  wrapping oooq-runner container):
  ```
  # virt-copy-out -a /tmp/qs/undercloud.qcow2 \
    /home/stack/overcloud-full.vmlinuz \
    /home/stack/overcloud-full.initrd /tmp/qs
  ```
* Export env vars as you want them, for example:
  ```
  $ export TEARDOWN=true
  $ export USER=bogdando
  $ export USER_KEYFILE=/tmp/qs/sshkey
  $ export OOOQ_PATH=${HOME}/gitrepos/tripleo-quickstart
  $ export WORKSPACE=/tmp/qs
  # mkdir -p ${WORKSPACE}
  ```
  Note, setting ``TEARDOWN=false`` speeds up redeploying
  when failed libvirt/setup stages.
* Prepare your localhost to serve as oooq's virthost:
  ```
  # cat /dev/urandom | sudo ssh-keygen -b 1024 -t rsa \
  -f "${USER_KEYFILE}" -q -N ""
  $ ssh-copy-id -i ${USER_KEYFILE} ${USER}@localhost
  $ ssh -F /dev/null -i ${USER_KEYFILE} \
    -tt ${USER}@localhost echo gotcha
  ```
* Prepare host for nested kvm:
  ```
  # echo "options kvm_intel nested=1" > /etc/modprobe.d/kvm-nested.conf
  # modprobe -r kvm_intel
  # modprobe kvm_intel
  # cat /sys/module/kvm_intel/parameters/nested
  ```
* Check for overrides in the ``node.yaml``

## Troubleshooting

If the undercloud VM refuses to start (permission deinied), try
to disable apparmor for libvirt and reconfigure qemu as well:
```
# echo "dynamic_ownership = 0" >> /etc/libvirt/qemu.conf
# echo 'group = "root"' >> /etc/libvirt/qemu.conf
# echo 'user = "root"' >> /etc/libvirt/qemu.conf
# echo 'security_driver = "none"' >> /etc/libvirt/qemu.conf
# sudo systemctl restart libvirt-bin
# sudo systemctl restart qemu-kvm
```

Details TBD.
