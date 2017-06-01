#!/bin/bash -xe

# IFT Manlia Driver REPO
export CLONE_DRIVER_FROM_GIT=1
export MANILA_REPO=https://github.com/infortrend-openstack/infortrend-manila-driver.git
export MANILA_DRIVER_DIR=/home/jenkins/infortrend-manila-driver
export MANILA_REPO_BRANCH=master

export GIT_BASE=${GIT_BASE:-https://git.openstack.org}
export GIT_BRANCH=${GIT_BRANCH:-master}
export PYTHONUNBUFFERED=true
export BUILD_TIMEOUT=10800000

export DEVSTACK_GATE_TEMPEST=0
export TEMPEST_CONCURRENCY=1    # Using #>1 will fail in some cases. (RAID has no parallel)
export 'DEVSTACK_GATE_TEMPEST_REGEX=^(?=manila_tempest_tests.tests.api)(?!.*admin.test_migration)(?!.*admin.test_snapshot_manage)(?!.*test_shares.SharesCIFSTest.test_create_share_from_snapshot)(?!.*test_shares.SharesNFSTest.test_create_share_from_snapshot).*'

export OVERRIDE_ENABLED_SERVICES=dstat,g-api,g-reg,horizon,key,mysql,n-api,n-cauth,n-cond,n-cpu,n-novnc,n-obj,n-sch,peakmem_tracker,placement-api,q-agt,q-dhcp,q-l3,q-meta,q-metering,q-svc,rabbit,tempest
export PROJECTS="openstack/python-manilaclient $PROJECTS"

rm -rf /opt/stack/new/*
cp -r /home/ift/ci_projects/* /opt/stack/new/

if [ -z "$ZUUL_PROJECT" ]; then
    export ZUUL_PROJECT=openstack/manila
fi
if [ -z "$ZUUL_BRANCH" ]; then
    export ZUUL_BRANCH=master
fi

export 'DEVSTACK_LOCAL_CONFIG=[[local|localrc]]
# DEST=/opt/stack/new
GIT_BASE=http://git.openstack.org
MANILA_ENABLED_BACKENDS=ift-manila-1,ift-manila-2
MANILA_SERVICE_IMAGE_ENABLED=False

# Enable Manila
enable_plugin manila https://github.com/openstack/manila

[[test-config|$TEMPEST_CONFIG]]
[cli]
enabled=True
[service_available]
manila=True
[share]
backend_names=ift-manila-1,ift-manila-2
share_creation_retry_number=3
enable_ip_rules_for_protocols=nfs
enable_user_rules_for_protocols=cifs
multitenancy_enabled=False
enable_protocols=nfs,cifs
username_for_user_rules=tempest
multi_backend=True
run_quota_tests=True
run_extend_tests=True
run_shrink_tests=True
run_snapshot_tests=False
run_mount_snapshot_tests=False
run_consistency_group_tests=False
run_replication_tests=False
run_migration_tests=False
run_manage_unmanage_tests=True
run_manage_unmanage_snapshot_tests=False

[[post-config|$MANILA_CONF]]
[ift-manila-1]
share_backend_name=ift-manila-1
share_driver=manila.share.drivers.infortrend.driver.InfortrendNASDriver
driver_handles_share_servers=False
infortrend_nas_ip=172.27.114.66
infortrend_nas_user=manila
infortrend_nas_password=qwer1234
infortrend_share_pools=InfortrendShare-1
infortrend_share_channels=0
[ift-manila-2]
share_backend_name=ift-manila-2
share_driver=manila.share.drivers.infortrend.driver.InfortrendNASDriver
driver_handles_share_servers=False
infortrend_nas_ip=172.27.114.66
infortrend_nas_user=manila
infortrend_nas_password=qwer1234
infortrend_share_pools=InfortrendShare-2
infortrend_share_channels=1
'

function pre_test_hook {

    if [ -n "$ZUUL_REF" ]; then
        temp_dir=$PWD
        cd $BASE/new/manila/
        sudo git pull ift@master:/var/lib/zuul/git/$ZUUL_PROJECT $ZUUL_REF
        cd $temp_dir
    fi

    if [[ "$CLONE_DRIVER_FROM_GIT" == 1 ]]; then
        rm -rf ${MANILA_DRIVER_DIR}
        git clone ${MANILA_REPO} ${MANILA_DRIVER_DIR} -b ${MANILA_REPO_BRANCH}
        rm -rf ${BASE}/new/manila/manila/share/drivers/infortrend/*
        mkdir ${BASE}/new/manila/manila/share/drivers/infortrend
        cp ${MANILA_DRIVER_DIR}/infortrend/* ${BASE}/new/manila/manila/share/drivers/infortrend/
    fi
    echo "Adding Infortrend opts and exceptions.."
    sed -i '71 iimport manila.share.drivers.infortrend.driver' ${BASE}/new/manila/manila/opts.py
    sed -i '143 amanila.share.drivers.infortrend.driver.infortrend_nas_opts,' ${BASE}/new/manila/manila/opts.py
    echo '# Infortrend Storage driver
class InfortrendCLIException(ShareBackendException):
    message = _("Infortrend CLI exception: %(err)s "
                "Return Code: %(rc)s, Output: %(out)s")

class InfortrendNASException(ShareBackendException):
    message = _("Infortrend NAS exception: %(err)s")
' >> ${BASE}/new/manila/manila/exception.py

    echo "Fix for our CIDR which only supports mask number <32"
    sed -i 's#1.2.3.4/32#1.2.3.4/31#g' ${BASE}/new/manila/manila_tempest_tests/tests/api/test_rules.py

    if ! grep tempest "/etc/passwd"; then
        sudo useradd tempest
    fi
}

function post_test_hook {
    set +o errexit
    cd $BASE/new/tempest
    sudo chown -R tempest:stack $BASE/new/tempest
    sudo chown -R tempest:stack $BASE/data/tempest
    sudo chmod -R o+rx $BASE/new/devstack/files
    sudo -H -u tempest tox -eall-plugin -- $DEVSTACK_GATE_TEMPEST_REGEX --concurrency=$TEMPEST_CONCURRENCY
}

export -f pre_test_hook
export -f post_test_hook

export KEEP_LOCALRC=true

cp devstack-gate/devstack-vm-gate-wrap.sh ./safe-devstack-vm-gate-wrap.sh

# in safe-devstack-vm-gate-wrap, move logs to jenkins workspace
sed -i 's#exit_handler $RETVAL# \
sudo mv $BASE/logs/* $WORKSPACE/logs \
sudo rm $PWD/logs/libvirt/libvirtd.log* \
exit_handler $RETVAL#g' safe-devstack-vm-gate-wrap.sh

#2017/04/05 fix bug for functions.sh line:521
sed -i 's#    local cache_dir=$BASE/cache/files/#    local cache_dir=$BASE/cache/files/\
    sudo mkdir -p $cache_dir\
    sudo chown -R $USER:$USER $cache_dir#g' devstack-gate/functions.sh

# clear log if exist previous job's log
sudo rm -rf /opt/stack/logs/*
sudo rm -rf /var/log/apache2/*

# execute jobs!
./safe-devstack-vm-gate-wrap.sh
