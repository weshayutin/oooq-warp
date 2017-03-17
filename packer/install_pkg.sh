#!/bin/bash -e
yum -y install gcc python-devel openssl-devel python-virtualenv \
  libvirt wget which sudo qemu-kvm libvirt-python \
  libguestfs-tools python-lxml polkit-pkla-compat git

