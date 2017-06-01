#!/bin/bash -xe

BASE='/home/ift/ci_projects'
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

for i in ${array[@]}; do

    j=$(echo ${i} | awk 'BEGIN {FS="/"}; {print $2}')
    echo "Processing ${j}..."

    if [ ! -d ${BASE}/${j} ]; then
        cd ${BASE}
        git clone https://git.openstack.org/${i}
    else
        cd ${BASE}/${j}
        git remote update
        git reset --hard
        git remote prune origin
        git clean -x -f
    fi
done

function check_connection {

    until ping -q -c1 -w1 $1 > /dev/null
    do
        echo "Infortrend RAID not online yet, try again later.."
        sleep 600 # wait raid ready
    done
}

echo "Check Connections..."
check_connection 11.11.11.11
check_connection 11.11.11.13
check_connection 172.27.114.66