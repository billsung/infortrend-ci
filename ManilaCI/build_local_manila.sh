#!/bin/bash

export MANILA_BASE=/home/ift/manila
export IFT_DRIVER_DIR=/home/jenkins/infortrend-manila-driver

cd /home/ift
if [ -d manila ]; then
    git clone https://github.com/openstack/manila.git
else
    cd manila
    git remote update
    git reset --hard
    git clean -x -f
    git pull
fi

rm -rf ${MANILA_BASE}/manila/share/drivers/infortrend
mkdir ${MANILA_BASE}/manila/share/drivers/infortrend
cp ${IFT_DRIVER_DIR}/infortrend/* ${MANILA_BASE}/manila/share/drivers/infortrend/

sed -i '71 iimport manila.share.drivers.infortrend.driver' ${MANILA_BASE}/manila/opts.py
sed -i '143 amanila.share.drivers.infortrend.driver.infortrend_nas_opts,' ${MANILA_BASE}/manila/opts.py
echo '# Infortrend Storage driver
class InfortrendCLIException(ShareBackendException):
    message = _("Infortrend CLI exception: %(err)s "
                "Return Code: %(rc)s, Output: %(out)s")

class InfortrendNASException(ShareBackendException):
    message = _("Infortrend NAS exception: %(err)s")
' >> ${MANILA_BASE}/manila/exception.py

cp clean_nas.py ${MANILA_BASE}/
