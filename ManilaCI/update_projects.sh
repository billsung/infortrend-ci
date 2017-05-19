#!/bin/bash -xe

BASE='/opt/stack/new'
array='openstack/ceilometer openstack/ceilometermiddleware openstack/cinder
openstack-dev/devstack openstack/django_openstack_auth openstack/glance
openstack/glance_store openstack/heat openstack/heat-cfntools
openstack/heat-templates openstack/horizon openstack-infra/devstack-gate
openstack-infra/tripleo-ci openstack/keystone openstack/keystoneauth
openstack/keystonemiddleware openstack/manila openstack/manila-ui
openstack/neutron openstack/neutron-fwaas openstack/neutron-lbaas
openstack/neutron-vpnaas openstack/nova openstack/octavia
openstack/os-apply-config openstack/os-brick openstack/osc-lib
openstack/os-client-config openstack/os-collect-config openstack/os-net-config
openstack/os-refresh-config openstack/python-manilaclient
openstack/requirements openstack/swift openstack/tempest openstack/tempest-lib
openstack/tripleo-heat-templates openstack/tripleo-image-elements
openstack/tripleo-incubator openstack/zaqar'

find ${BASE}/ -maxdepth 1 -type f -delete

home=$PWD
for i in ${array[@]}; do
    echo ${i}
    j=$(echo ${i} | awk 'BEGIN {FS="/"}; {print $2}')

    if [ ! -d ${BASE}/${j} ]; then
        echo "1"
        cd ${BASE}
        git clone https://git.openstack.org/${i}
    else
        cd ${BASE}/${j}
        git reset --hard origin/master
        git pull --all
        git remote prune origin
    fi
done
cd ${home}
