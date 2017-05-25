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

# Delete previous logs
find /opt/stack/new/ -maxdepth 1 -type f -delete
find /opt/stack/new/ -maxdepth 1 -type l -delete

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
        git reset --hard
        git pull --all
        git remote prune origin
        git checkout master
        git clean -x -f
    fi
done
cd ${home}

chown stack ${BASE}/*
chown stack ${BASE}/.*

mysql --user="root" --execute="DROP DATABASE cinder;"
mysql --user="root" --execute="DROP DATABASE glance;"
mysql --user="root" --execute="DROP DATABASE keystone;"
mysql --user="root" --execute="DROP DATABASE manila;"
mysql --user="root" --execute="DROP DATABASE neutron;"
mysql --user="root" --execute="DROP DATABASE nova;"
mysql --user="root" --execute="DROP DATABASE nova_api;"
mysql --user="root" --execute="DROP DATABASE nova_cell0;"
