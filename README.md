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
  $ export OOOQ_PATH=${HOME}/gitrepos/tripleo-quickstart
  $ export WORKSPACE=/tmp/qs
  $ export OOOQE_BRANCH=dev
  $ export OOOQE_FORK=johndoe
  $ export VENV=hostpath
  $ export VPATH=${HOME}/.venvs/oooq
  # mkdir -p ${WORKSPACE}
  ```
Note, setting ``TEARDOWN=false`` speeds up redeploying
when failed libvirt/setup stages.

By default, the wrapper uses predefined python virtual env named oooq.
Container build time, upstream dependencies are installed into it.
If you want to mount in your custom venv, configure as in the example
above. That env must contain at least oooq and oooq-extras dependencies.

An alternative shortcut for overriding only OOOQ-extras playbooks and roles,
is to use ``VENV=local`` and override its stock setup by the env vars
``OOOQE_BRANCH`` and ``OOOQE_FORK``. For the given above example, it would do:
  ```
  pip install git+https://github.com/johndoe/tripleo-quickstart-extras@dev
  ```
  right into the local oooq venv at the container entry point.

* Prepare host for nested kvm:
  ```
  # echo "options kvm_intel nested=1" > /etc/modprobe.d/kvm-nested.conf
  # modprobe -r kvm_intel
  # modprobe kvm_intel
  # cat /sys/module/kvm_intel/parameters/nested
  ```
* Check for overrides in the ``node.yaml``
* Git checkout the wanted branch of the local OOQ repo. It will be mounted
  into the wrapper container by the given ``OOOQ_PATH``.

# Respinning a failed env

If you want to reuse existing customized by oooq images and omit
all of the long playing oooq provisioning steps:
* Make sure your ``local_working_dir`` is a persistent host path
  Otherwise, when the container exited, you loose the updated
  inventory and ssh keys and must start from the scratch.
* export ``TEARDOWN=false`` then run ``./oooq-warp.sh``.
* Or copy those to be persisted from the container, then exit it:
  ```
  (oooq) sudo cp ~/hosts /tmp/qs/
  (oooq) sudo cp ~/id_* /tmp/qs/
  (oooq) sudo cp ~/ssh* /tmp/qs/
  ```
  So you could put them back to respin the deploy from the newly
  started container.

To start from the scratch, overwrite customized images by the original
(non customized) images you have downloaded before. For example, given
the example above ``WORKSPACE=/tmp/qs/``:
```
# cp /home/$USER/.quickstart/undercloud.qcow2* /tmp/qs/
```
Then export ``TEARDOWN=true`` and run ``./oooq-warp.sh``.

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
