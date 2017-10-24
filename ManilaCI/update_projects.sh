#!/bin/bash

export ZUUL_BRANCH=${ZUUL_BRANCH:-master}
echo "ZUUL_BRABCH is ${ZUUL_BRANCH}"

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
    if [[ "${current_b}" != "$ZUUL_BRANCH" ]]; then
        git checkout $ZUUL_BRANCH
        git reset --hard $ZUUL_BRANCH
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
    echo "+ Updating ${j}..."

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
        if [[ "${current_b}" != "$ZUUL_BRANCH" ]]; then
          git checkout $ZUUL_BRANCH
          git reset --hard $ZUUL_BRANCH
          git clean -x -f
          git merge -X theirs
        fi
    fi
done

function check_connection {
    until ping -q -w1 -c1 $1 > /dev/null
    do
        echo "ERROR: Infortrend NAS port $1 DOWN"
        sleep 100   # Wait for fix. Make sure to set `Timeout minutes`
                    # in `Time-out strategy` to about 180 for manilaCI to fail/abort the job.
    done
}

# Clear log first in case of the connection fail and the post task copies the wrong log.
rm -rf /opt/stack/logs/*
rm -rf /var/log/apache2/*
rm -rf /var/log/libvirt/*
rm -rf /var/log/openvswitch/*
rm -rf /var/log/rabbitmq/*

echo "Checking Connections..."
check_connection 11.11.11.11
check_connection 11.11.11.13
check_connection 172.27.119.158

rm -rf /opt/stack/new/*
cp -r /home/ift/ci_projects/* /opt/stack/new/
