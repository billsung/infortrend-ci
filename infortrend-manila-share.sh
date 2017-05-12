#!/bin/bash -xe

export CLONE_DRIVER_FROM_GIT=1
export MANILA_REPO=https://github.com/infortrend-openstack/infortrend-manila-driver.git
export MANILA_DRIVER_DIR=/home/jenkins/infortrend-manila-driver
export MANILA_REPO_BRANCH=chengwei

export GIT_BASE=${GIT_BASE:-https://git.openstack.org}
export PYTHONUNBUFFERED=true
export BUILD_TIMEOUT=21600000

export DEVSTACK_GATE_TEMPEST=1
# This can set to skip tempest started by devstack-vm-gate.
#export DEVSTACK_GATE_TEMPEST_NOTESTS=1
export DEVSTACK_GATE_TEMPEST_ALL_PLUGINS=1
export TEMPEST_CONCURRENCY=1
export 'DEVSTACK_GATE_TEMPEST_REGEX=^(?=manila_tempest_tests.tests.api.*)'
export OVERRIDE_ENABLED_SERVICES=dstat,g-api,g-reg,horizon,key,mysql,n-api,n-cauth,n-cond,n-cpu,n-novnc,n-obj,n-sch,peakmem_tracker,placement-api,neurton,q-agt,q-dhcp,q-l3,q-meta,q-metering,q-svc,rabbit

export PROJECTS="openstack/manila $PROJECTS"
export PROJECTS="openstack/python-manilaclient $PROJECTS"

if [ -z "$ZUUL_PROJECT" ]; then
    export ZUUL_PROJECT=openstack/manila
fi
if [ -z "$ZUUL_BRANCH" ]; then
    export ZUUL_BRANCH=master
fi

function pre_test_hook {

    if [[ "$CLONE_DRIVER_FROM_GIT" == 1 ]]; then
        rm -rf ${MANILA_DRIVER_DIR}
        git clone ${MANILA_REPO} ${MANILA_DRIVER_DIR} -b ${MANILA_REPO_BRANCH}
        rm -rf ${BASE}/new/manila/manila/share/drivers/infortrend/*
        mkdir ${BASE}/new/manila/manila/share/drivers/infortrend
        cp ${MANILA_DRIVER_DIR}/infortrend/* ${BASE}/new/manila/manila/share/drivers/infortrend/
    fi

    if [ -n "$ZUUL_REF" ]; then
        temp_dir=$PWD
        cd $BASE/new/cinder/
        sudo git pull ift@master:/var/lib/zuul/git/$ZUUL_PROJECT $ZUUL_REF
        cd $temp_dir
    fi

    sed -i 's/rm\ -f\ $MANILA_CONF//g' /opt/stack/new/manila/devstack/plugin.sh

    export MANILA_CONF=/etc/manila/manila.conf
    rm -f $MANILA_CONF

    iniset $MANILA_CONF ift-manila-1 share_backend_name ift-manila-1
    iniset $MANILA_CONF ift-manila-1 share_driver manila.share.drivers.infortrend.driver.InfortrendNASDriver
    iniset $MANILA_CONF ift-manila-1 driver_handles_share_servers False
    iniset $MANILA_CONF ift-manila-1 infortrend_nas_ip 172.27.114.66
    iniset $MANILA_CONF ift-manila-1 infortrend_nas_user manila
    iniset $MANILA_CONF ift-manila-1 infortrend_nas_password qwer1234
    iniset $MANILA_CONF ift-manila-1 infortrend_share_pools InfortrendShare-1
    iniset $MANILA_CONF ift-manila-1 infortrend_share_channels 0,1

    iniset $MANILA_CONF ift-manila-2 share_backend_name ift-manila-2
    iniset $MANILA_CONF ift-manila-2 share_driver manila.share.drivers.infortrend.driver.InfortrendNASDriver
    iniset $MANILA_CONF ift-manila-2 driver_handles_share_servers False
    iniset $MANILA_CONF ift-manila-2 infortrend_nas_ip 172.27.114.66
    iniset $MANILA_CONF ift-manila-2 infortrend_nas_user manila
    iniset $MANILA_CONF ift-manila-2 infortrend_nas_password qwer1234
    iniset $MANILA_CONF ift-manila-2 infortrend_share_pools InfortrendShare-2
    iniset $MANILA_CONF ift-manila-2 infortrend_share_channels 0,1

    sudo chmod 777 $MANILA_CONF

    #source $BASE/new/devstack/openrc admin demo
    #manila type-key default set driver_handles_share_servers=False

    cat <<EOF >$BASE/new/devstack/local.conf
[[local|localrc]]
DEST=/opt/stack/new
GIT_BASE=http://git.openstack.org
# Enable Manila
enable_plugin manila https://github.com/openstack/manila
MANILA_ENABLED_BACKENDS=ift-manila-1,ift-manila-2

[[test-config|\$TEMPEST_CONFIG]]
[compute-feature-enabled]
attach_encrypted_volume=false
[cli]
enabled=True
[service_available]
manila=True
[share]
capability_snapshot_support=False
backend_names=ift-manila-1,ift-manila-2
multitenancy_enabled=False
enable_protocols=nfs,cifs
enable_ip_rules_for_protocols=nfs
enable_user_rules_for_protocols=cifs
username_for_user_rules=tempest
run_quota_tests=True
run_extend_tests=True
run_shrink_tests=True
run_snapshot_tests=False
run_consistency_group_tests=False
run_replication_tests=False
run_migration_tests=True
run_manage_unmanage_tests=True
run_manage_unmanage_snapshot_tests=False

EOF

}

export -f pre_test_hook

export KEEP_LOCALRC=true

cp devstack-gate/devstack-vm-gate-wrap.sh ./safe-devstack-vm-gate-wrap.sh

# in safe-devstack-vm-gate-wrap, move logs to jenkins workspace
sed -i 's#exit_handler $RETVAL# \
sudo mv $BASE/logs/* $WORKSPACE/logs \
sudo rm $PWD/logs/libvirt/libvirtd.log* \
sudo rm -rf $BASE/new/* \
exit_handler $RETVAL#g' safe-devstack-vm-gate-wrap.sh

sed -i 's,^\(\s*\)\(/tmp/ansible/bin/ara .*\)$,\1#(sam) remove ARA report because it is both time and space consuming\n\1#\2,g' safe-devstack-vm-gate-wrap.sh

#2017/04/05 fix bug for functions.sh line:521
sed -i 's#    local cache_dir=$BASE/cache/files/#    local cache_dir=$BASE/cache/files/\
    sudo mkdir -p $cache_dir\
    sudo chown -R $USER:$USER $cache_dir#g' devstack-gate/functions.sh

# clear log if exist previous job's log
sudo rm -rf /opt/stack/logs/*
sudo rm -rf /var/log/apache2/*

# execute jobs!
./safe-devstack-vm-gate-wrap.sh
