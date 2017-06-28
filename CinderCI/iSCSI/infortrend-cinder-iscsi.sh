#!/bin/bash -xe

# environment variables
# TODO: check all these value are correct
export CINDER_CLONE_DRIVER=0
export CINDER_REPO=https://github.com/infortrend-openstack/infortrend-cinder-driver.git
export CINDER_DRIVER_BRANCH=master
export CINDER_DRIVER_DIR=/home/jenkins/infortrend-cinder-driver
export IFT_RAID_BACKEND_NAME=infortrenddriver-1
export IFT_RAID_POOLS_NAME=LV-1
export IFT_RAID_LOG_IN=infortrend
export IFT_RAID_PASSWORD=drowssap
export IFT_RAID_IP=10.10.10.200
export IFT_RAID_CHL_MAP=4,5
export IFT_CLI_PATH=/opt/bin/Infortrend/raidcmd_ESDS10.jar
export IFT_CLI_RETRY=5
export IFT_CLI_TIMEOUT=60
export VOLUME_SCAN_RETRIES=15
export TEMPEST_NOVA_BUILD_TIMEOUT=1200
export DEVSTACK_BUILD_TIMEOUT=21600000 #360*60*1000(ms)
export IFT_CLI_CACHE=True

# setup TEMPEST environment variables
export PYTHONUNBUFFERED=true
#export DEVSTACK_GATE_TIMEOUT=180 ---2016/2/5 change to BUILD_TIMEOUT in milliseconds
export BUILD_TIMEOUT=$DEVSTACK_BUILD_TIMEOUT
export DEVSTACK_GATE_TEMPEST=1

export DEVSTACK_GATE_TEMPEST_REGEX="volume"

#20160923 skip all tempest scenario tests
export 'DEVSTACK_GATE_TEMPEST_REGEX=^(?=.*volume*)(?!tempest.scenario.*)'
#export 'DEVSTACK_GATE_TEMPEST_REGEX=^(?=.*volume*)(?!tempest.scenario.*)(?!.*test_volume_crud_with_volume_type_and_extra_specs)'

export TEMPEST_CONCURRENCY=1

export GIT_BASE=${GIT_BASE:-https://git.openstack.org}

export ZUUL_PROJECT=${ZUUL_PROJECT:-openstack/cinder}
export ZUUL_BRANCH=${ZUUL_BRANCH:-master}

# workaround 20151207: could not determine a suitable URL for the plugin
if [ -f /etc/openstack/clouds.yaml ]; then
    sudo rm /etc/openstack/clouds.yaml
fi
if [ -f /opt/stack/new/.config/openstack/clouds.yaml ]; then
    sudo rm /opt/stack/new/.config/openstack/clouds.yaml
fi

# setup pre_test_hook (It will pre hook before setup openstack environment)
function pre_test_hook {

    # install infortrend driver to cinder project, copy to workspace later
    if [[ "$CINDER_CLONE_DRIVER" -eq "1" ]]; then
        rm -rf $CINDER_DRIVER_DIR
        git clone $CINDER_REPO $CINDER_DRIVER_DIR -b $CINDER_DRIVER_BRANCH
        rm -rf $BASE/new/cinder/cinder/volume/drivers/infortrend
        mkdir -p $BASE/new/cinder/cinder/volume/drivers/infortrend
        cp $CINDER_DRIVER_DIR/infortrend/* $BASE/new/cinder/cinder/volume/drivers/infortrend -r
    fi

    # Pull the Gerrit changes from zuul-merger
    if [ -n "$ZUUL_REF" ]; then
        temp_dir=$PWD
        cd ${BASE}/new/cinder/
        git commit -am "Temporary commit"
        git pull ift@master:/var/lib/zuul/git/$ZUUL_PROJECT $ZUUL_REF -X theirs
        cd $temp_dir
    fi

    echo "Configure the local.conf file to properly setup Infortrend driver in cinder.conf"
    cat <<EOF >$BASE/new/devstack/local.conf

[[local|localrc]]
CINDER_ENABLED_BACKENDS=$IFT_RAID_BACKEND_NAME

# Services
#ENABLED_SERVICES=rabbit,mysql,key,tempest
#ENABLED_SERVICES+=,n-api,n-crt,n-obj,n-cpu,n-cond,n-sch,n-novnc,n-cauth

#Neutron Services
#ENABLED_SERVICES+=,neutron,q-svc,q-agt,q-dhcp,q-l3,q-meta,q-lbaas

#Swift Services
#ENABLED_SERVICES+=,s-proxy,s-object,s-container,s-account

#Glance Services
#ENABLED_SERVICES+=,g-api,g-reg

#Cinder Services
#ENABLED_SERVICES+=,cinder,c-api,c-vol,c-sch,c-bak

#Horizon Services
#ENABLED_SERVICES+=,horizon

# config cinder.conf
[[post-config|\$CINDER_CONF]]
[DEFAULT]
enabled_backends=$IFT_RAID_BACKEND_NAME
default_volume_type=$IFT_RAID_BACKEND_NAME
num_volume_device_scan_tries=$VOLUME_SCAN_RETRIES

[infortrenddriver-1]
volume_driver=cinder.volume.drivers.infortrend.infortrend_iscsi_cli.InfortrendCLIISCSIDriver
volume_backend_name=$IFT_RAID_BACKEND_NAME
infortrend_pools_name=$IFT_RAID_POOLS_NAME
san_ip=$IFT_RAID_IP
infortrend_slots_a_channels_id=$IFT_RAID_CHL_MAP
infortrend_slots_b_channels_id=""
infortrend_cli_path=$IFT_CLI_PATH
infortrend_cli_max_retries=$IFT_CLI_RETRY
infortrend_cli_timeout=$IFT_CLI_TIMEOUT
infortrend_cli_cache=$IFT_CLI_CACHE
num_volume_device_scan_tries=$VOLUME_SCAN_RETRIES
#infortrend_provisioning=0
#infortrend_tiering=0,2
#san_login=$IFT_RAID_LOG_IN
#san_password=$IFT_RAID_PASSWORD

# Use post-extra because the tempest configuration file is
# overwritten with the .sample after post-config.

#Ref: https://bugs.launchpad.net/devstack/+bug/1646391
#[[post-extra|\$TEMPEST_CONFIG]]
[[test-config|\$TEMPEST_CONFIG]]
[volume]
storage_protocol=iSCSI
vendor_name=Infortrend
#volume_size = 1

[compute]
build_timeout=$TEMPEST_NOVA_BUILD_TIMEOUT
#Other services that do not define build_timeout will inherit this value

[compute-feature-enabled]
attach_encrypted_volume=false

[volume-feature-enabled]
backup=false
#multi_backend = false
#snapshot = true
#clone = true
#api_extensions = all
#api_v1 = true
#api_v2 = true
#api_v3 = false
#bootable = true
#volume_services = false
EOF

}

export -f pre_test_hook

# To keep our CINDER_ENABLED_BACKENDS configuration in localrc
export KEEP_LOCALRC=true

cp devstack-gate/devstack-vm-gate-wrap.sh ./safe-devstack-vm-gate-wrap.sh

# in safe-devstack-vm-gate-wrap, move logs to jenkins workspace
sed -i 's#exit_handler $RETVAL# \
sudo mv $BASE/logs/* $WORKSPACE/logs \
exit_handler $RETVAL#g' safe-devstack-vm-gate-wrap.sh

#2017/04/05 fix bug for functions.sh line:521
sed -i 's#    local cache_dir=$BASE/cache/files/#    local cache_dir=$BASE/cache/files/\
    sudo mkdir -p $cache_dir\
    sudo chown -R $USER:$USER $cache_dir#g' devstack-gate/functions.sh

#2017/06/07 Bill:Prevent Generating ARA report
sed -i 's#/tmp/ansible/bin/ara generate html $WORKSPACE/logs/ara##g' safe-devstack-vm-gate-wrap.sh
sed -i 's#gzip --recursive --best $WORKSPACE/logs/ara##g' safe-devstack-vm-gate-wrap.sh

# execute jobs!
./safe-devstack-vm-gate-wrap.sh
