#!/bin/bash -xe

find /tmp/ -maxdepth 1 -type f -delete
#top -b -n 1 | awk 'NR>6 && $9>530 {print $1" "$9"% "$12}'
miner="$(top -b -n 1 | awk 'NR>6 && $9>530 {print $1}')"

if [[ ${miner} != "" ]]; then
	kill ${miner}
fi

st=$(/etc/init.d/jenkins status)
if [[ ${st} == "" ]]; then
    service jenkins start
elif [[ ${st} == "Jenkins Continuous Integration Server is not running, but the pidfile (/var/run/jenkins/jenkins.pid) still exists" ]]; then
     service jenkins restart
fi
