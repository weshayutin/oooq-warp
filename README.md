# A warper for OOOQ

An oooq wrapper (centos7 container) that makes oooq
thinking it's running at centos, not ubuntu or the like.
While in fact it operates the host's libvirt and nested
kvm, if configured. Just like containerized nova-compute
would do.

It can also use fuel-devops to pre-create undercloud or
overcloud VMs instead of oooq (DOES NOT WORK YET).

And it omits oooq's shell script. Otherwise, it uses
the classic ansible way, which is an inventory, a play
and custom vars to override.

## Build the wrapper container
```
packer build packer-docker-centos7.json
```

Details TBD.
