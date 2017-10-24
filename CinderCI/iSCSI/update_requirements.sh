#!/bin/bash

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
openstack/os-refresh-config openstack/requirements openstack/swift
openstack/tempest openstack/tempest-lib openstack/tripleo-heat-templates
openstack/tripleo-image-elements openstack/tripleo-incubator openstack/zaqar'

for i in ${array[@]}; do
    export j=$(echo ${i} | awk 'BEGIN {FS="/"}; {print $2}')
    echo "+ Updating ${j}..."

    cd ${BASE}/${j}
    pip install -r requirements.txt
    pip install -r test-requirements.txt
done

