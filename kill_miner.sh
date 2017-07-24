#!/bin/bash -xe

find /tmp/ -maxdepth 1 -type f -delete
#top -b -n 1 | awk 'NR>6 && $9>580 {print $1" "$9"% "$12}'
target="$(top -b -n 1 | awk 'NR>6 && ($9>520 || $12 ~/\.\//) {print $0}')"

msg=""
flag=0

function append_msg {
    if [[ $msg == "" ]]; then
        msg="${1}"
    else
        msg="${msg}\n${1}"
    fi
}

function check_miner {
    miner_pid="$(echo "${target}" | awk '{print $1}')"
    miner_name="$(echo "${target}" | awk '{print $12}')"

    if [[ ${miner_name} != "/usr/bin/java" ]]; then
        kill ${miner_pid}
        append_msg "Bill - Killing suspicious process name=[${miner_name}] pid=[${miner_pid}]"
    fi
}

function check_jenkins {
    st="$(/etc/init.d/jenkins status)"
    if [[ ${st} == "" || ${st} == "Jenkins Continuous Integration Server is not running" ]]; then
        service jenkins start
        append_msg "Bill - Jenkins down detected. Starting jenkins."
        flag=1
    elif [[ ${st} == "Jenkins Continuous Integration Server is not running, but the pidfile (/var/run/jenkins/jenkins.pid) still exists" ]]; then
        service jenkins restart
        append_msg "Bill - Jenkins crash detected. Restarting jenkins."
        flag=1
    fi
}

if [[ ${target} != "" ]]; then
    check_miner
fi

check_jenkins
if [[ ${msg} != "" ]]; then
    wall ${msg}

    if [[ ${flag} == 1 ]]; then
        sleep 50
        java -jar /home/ift/jenkins-cli.jar -s http://localhost:8080/ build Check-Node-Online
    fi
fi
