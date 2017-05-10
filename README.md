# A warper for TripleO-QuickStart

An OOOQ wrapper (centos7 container) that makes oooq
thinking it's running at centos, not ubuntu or the like.
While in fact it operates the host's libvirt and nested
kvm, if configured. Just like containerized nova-compute
would do.

It omits oooq's shell scripts and goes the ansible way,
which is an inventory, a play and custom vars to override.

If you want to deploy with quickstart.sh instead, use
``QUICKSTARTISH=true``.

WIP: deploy with traas and openstack provider

## Requirements for the host OS

* Packer >= 0.12
* Docker >= 1.13
* Libvirt and kvm (latest perhaps) with HW access/nested
  virtualization enabled

Note, cloud providers may not allow HW enabled kvm. OOOQ
will not work on QEMU, sorry!

## Build the wrapper container
```
$ packer build packer-docker-centos7.json
$ packer build packer-docker-oooq-runner.json
```
Note, adapt those for your case or jut use existing images. It also requires
``OOOQ_PATH`` set, see below.

## Pre-flight checks for a warp jump

To start a scratch local dev env with libvirt and kvm:

* Download overcloud/undercloud images and md5 into the ``IMAGECACHE``.
  For master dev envs, you may want to pick any of these sources:
  * [The most recent, the less stable](http://artifacts.ci.centos.org/rdo/images/master/delorean/current-tripleo/testing/),
    for hardcore devs (a [mirror](https://images.rdoproject.org/master/delorean/current-tripleo/testing/))
  * [The consistent, the longest upgrade path](http://artifacts.ci.centos.org/rdo/images/master/delorean/consistent/),
    it is also the default OOOQ choice (a [mirror](https://images.rdoproject.org/master/delorean/consistent/)).
  * [The one from](https://buildlogs.centos.org/centos/7/cloud/x86_64/tripleo_images/master/delorean/) the
    [docs](http://tripleo.org/basic_deployment/basic_deployment_cli.html), for RTFM ppl.
* Export env vars as you want them, for example:
  ```
  $ export USER=bogdando
  $ export OOOQ_PATH=${HOME}/gitrepos/tripleo-quickstart
  $ export WORKSPACE=/opt/oooq
  $ export IMAGECACHE=/opt/cache
  $ export LWD=/home/{USER}/.quickstart
  $ export OOOQE_BRANCH=dev
  $ export OOOQE_FORK=johndoe
  $ export VENV=hostpath
  $ export VPATH=${HOME}/.venvs/oooq
  # mkdir -p ${WORKSPACE}
  ```
* Export a custom PLAY name to start with. The default play is
  is ``oooq-warp.yaml``:
  ```
  $ export PLAY=oooq-under.yaml
  ```
  Note, setting ``TEARDOWN=false`` speeds up respinning of failed
  deployments. Also note that quickstart.sh would expect another TEARDOWN
  values, see its docs for details.
* Extract initrd and vmlinuz (does not work from the
  wrapping oooq-runner container):
  ```
  # virt-copy-out -a ${IMAGECACHE}/undercloud.qcow2 \
    /home/stack/overcloud-full.vmlinuz \
    /home/stack/overcloud-full.initrd ${WORKSPACE}
  ```
* Prepare host for nested kvm:
  ```
  # echo "options kvm_intel nested=1" > /etc/modprobe.d/kvm-nested.conf
  # modprobe -r kvm_intel
  # modprobe kvm_intel
  # cat /sys/module/kvm_intel/parameters/nested
  ```
* Copy data vars ``custom.yaml_example`` as ``custom.yaml`` and check for
  needed data overrides.
* Git checkout the wanted branch of the local OOQ repo. It will be mounted
  into the wrapper container by the given ``OOOQ_PATH``.

Normally, the plays to be executed are: the default ``oooq-warp.yaml``
with either provisioning steps omitted (``TEARDOWN=true``) or not, then
the ``oooq-under.yaml`` or the given custom ``PLAY``.

## Dev branches and venvs

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
right into the local oooq venv at the container entry point stage.


For the rest of components, like t-h-t, puppet modules, heat-agent,
define a custom repo/branch/refspec:
```
overcloud_templates_repo: https://github.com/johndoe/tripleo-heat-templates
overcloud_templates_branch: dev
undercloud_templates_repo: https://github.com/johndoes/tripleo-heat-templates
undercloud_templates_branch: superdev
undercloud_install_script: undercloud-deploy-dev.sh.j2
```
Then create the custom ``undercloud-deploy-dev.sh.j2`` script.
Inside, make sure to checkout/install required dev branches of components under
dev/test. Then define a composable role (a heat environemnt) for the undercloud
for the given script as well. For overcloud custom roles, see OOOQ docs.

## Respinning a failed env omitting oooq provisioning steps

If you want to reuse existing customized by oooq images and omit
all of the long playing oooq provisioning steps:
* Make sure your ``local_working_dir`` is a persistent host path
  Otherwise, when the container exited, you loose the updated
  inventory and ssh keys and may only start from the scratch.
* Export ``TEARDOWN=false`` then rerun the deploy inside of the
  container. Or use `none`, if QUICKSTARTISH.

To start from the scratch, remove existing VMs' snapshots, export or
unset``TEARDOWN=true``, unset ``PLAY``, exit container and re-run
``./oooq-warp.sh`` and grap some cofee, it won't be ready soon.

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

## Traas deployment with openstack provider

Copy ``oooq-traas.yaml`` as ``traas.yaml`` and update with required info, like
the openstack cloud provider access secrets and endpoints.

Start with altering vars described at the pre-flight checks steps above:
```
$ export PLAY=traas.yaml
$ export TEARDOWN=false
```
Make sure there are no artificial undercloud node entries remaining at the
``$LWD/hosts``. Then run
```
$ ./oooq-warp.sh
$ create_env_oooq.sh
```
It replaces the ansible inventory with existing openstack instaces (see
[traas](https://github.com/bogdando/traas) heat templates). Note, it places
the given openstack cloud provider access secrets under ``$LWD/clouds.yaml`` or
``$LWD/stackrc``. The ``$LWD`` dir is bind-mounted into the wrapper container
and may be not ephemeral, so take care of your secrets on your own!

Then deploy with custom tripleo-extras roles, like:
```
$ export PLAY=oooq-traas-under.yaml
$ /oooq-warp.sh
$ create_env_oooq.sh
```
