#!/bin/bash

if [[ ! -e devstack-gate ]]; then
    git clone https://git.openstack.org/openstack-infra/devstack-gate
else
    cd devstack-gate
    git remote set-url origin https://git.openstack.org/openstack-infra/devstack-gate
    git remote update
    git reset --hard
    git clean -x -f
    git merge -X theirs
    export current_b=$(git rev-parse --abbrev-ref HEAD)
    if [[ "${current_b}" != "master" ]]; then
        git checkout master
        git reset --hard remotes/origin/master
        git clean -x -f
        git merge -X theirs
    fi
fi

export BASE='/home/ift/ci_projects'
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

    export j=$(echo ${i} | awk 'BEGIN {FS="/"}; {print $2}')
    echo "Processing ${j}..."

    if [ ! -d ${BASE}/${j} ]; then
        cd ${BASE}
        git clone https://git.openstack.org/${i}
    else
        cd ${BASE}/${j}
        git remote update
        git reset --hard
        git clean -x -f
        git merge -X theirs
        export current_b=$(git rev-parse --abbrev-ref HEAD)
        if [[ "${current_b}" != "master" ]]; then
          git checkout master
          git reset --hard remotes/origin/master
          git clean -x -f
          git merge -X theirs
        fi
    fi
done

function check_connection {

    ping -c1 -w1 $1 > /dev/null
    if [ $? -ne 0 ]; then
        echo "ERROR: Infortrend NAS port $1 DOWN"
        sleep 600 # wait raid read
        exit 1
    fi
}

echo "Check Connections..."
check_connection 11.11.11.11
check_connection 11.11.11.13
check_connection 172.27.114.66

rm -rf /opt/stack/new/*
cp -r /home/ift/ci_projects/* /opt/stack/new/
