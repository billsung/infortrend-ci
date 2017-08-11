#!/bin/bash -xe

WORKPATH="/root/kill_miner"

find /tmp/ -maxdepth 1 ! -name hudson* -type f -delete
#target="$(top -b -n 1 | awk 'NR>6 && ($9>520 || $12 ~/\.\//) {print $0}')"

if [ -f ${WORKPATH}/temp.txt ]; then
    rm ${WORKPATH}/temp.txt
fi
ps -u jenkins uh >> ${WORKPATH}/temp.txt
now=$(date '+%Y-%m-%d %H:%M:%S')

function check_miner {
    killflag=0
    trim_name=${4##*/}
    if [[ ${3} != "/usr/bin/java" ]]; then
        if [[ ${1} > 520 ]]; then
            killflag=1
        elif [[ ${4} == ./* ]]; then
            killflag=1
        elif [[ ${trim_name} == hop || ${trim_name} == rmv || ${trim_name} == irqbalanc1 || ${trim_name} == irc || ${trim_name} == idlez ]]; then
            killflag=1
        fi
    fi

    if [[ ${killflag} == 1 ]]; then
        kill ${this_pid}
        echo "${now} | Kill process [${3}] name=[${4}] usage=[${1}%] pid=[${2}]" >> ${WORKPATH}/kill_miner.log
    fi
}

while IFS='' read -r line || [[ -n "$line" ]]; do
    cpu_usage="$(echo "${line}" | awk '{print $3}')"
    this_pid="$(echo "${line}" | awk '{print $2}')"
    this_proc="$(echo "${line}" | awk '{print $11}')"
    this_name="$(echo "${line}" | awk '{print $12}')"
    check_miner ${cpu_usage} ${this_pid} ${this_proc} ${this_name}
done < ${WORKPATH}/temp.txt

flag=0
st="$(/etc/init.d/jenkins status)"

if [[ ${st} == "" || ${st} == "Jenkins Continuous Integration Server is not running" ]]; then
    service jenkins start
    echo "${now} | Jenkins down detected. Starting jenkins." >> ${WORKPATH}/kill_miner.log
    flag=1
elif [[ ${st} == "Jenkins Continuous Integration Server is not running, but the pidfile (/var/run/jenkins/jenkins.pid) still exists" ]]; then
    service jenkins restart
    echo "${now} | Jenkins crash detected. Restarting jenkins." >> ${WORKPATH}/kill_miner.log
    flag=1
fi

if [[ ${flag} == 1 ]]; then
    sleep 50
    su -c 'java -jar /home/ift/jenkins-cli.jar -s http://localhost:8080/ build Check-Node-Online' ift >> ${WORKPATH}/kill_miner.log
fi

