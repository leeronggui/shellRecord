#!/bin/bash

#黑石机房金融机器初始化脚本
#
# 写日志
PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
 . /lib/lsb/init-functions
function log(){
	info="`date` $2 "
        if [ $1 -eq 0 ];then
                log_warning_msg "[成功] ${info}"
        else
                log_failure_msg "[失败] ${info}"
		exit 1
        fi
}

#set dns
setDns(){
	if [ ! -s /etc/resolvconf/resolv.conf.d/base ];then
		cat > /etc/resolvconf/resolv.conf.d/base << EOF
nameserver 10.14.1.4
nameserver 10.14.1.2
nameserver 10.14.1.3
EOF
		resolvconf -u
		log 0 "成功设置dns."
	else 
		log 1 "DNS已经设置,不需要再次设置!"
	fi
}

#set hostname
setHostname(){
	IP=`ifconfig bond1 | grep "inet addr" |awk '{print $2}' |awk -F':' '{print $NF}'`
	log $? "获取本机IP地址：$IP"
	name=`dig +time=1 +tries=1 -x 10.14.1.2 @10.14.1.4 | grep PTR |awk '{print $NF}' | grep -v PTR| awk -F. '{print $1}'`
	log $? "获取本机主机名:$name"
	hostnamectl set-hostname ${name}
	log $? "设置主机名"
	grep -q "127.0.0.1" /etc/hosts || echo "127.0.0.1  localhost" > /etc/hosts
	grep -q "$name" /etc/hosts || echo "$IP $name" >> /etc/hosts
}
#setDns

installDocker(){
	which docker >/dev/null 2>&1 && log 1 "检查是否已经安装docker."
	

}
installDocker

installNginx(){
	pass
}

install installDnsmasq(){
	which dnsmasq >/dev/null 2>&1 && log 1 "检查是否已经安装dnsmasq."
	apt-get update
	apt-get -f -y install
	apt-get install dnsmasq
	mv /etc/dnsmasq.conf /etc/dnsmasq.conf.old
	mv /etc/default/dnsamsq /etc/default/dnsamsq.old
	echo "DNSMASQ_OPTS="--addn-hosts=/etc/dnsmasq.d/ "" >> /etc/default/dnsmasq
	cat > /etc/dnsmasq.conf << EOF
no-hosts
log-queries
log-facility=/data/log/dnsmasq.log
resolv-file=/etc/resolv.conf
addn-hosts=/etc/dnsmasq.hosts
cache-size=2000
local-ttl=600

server=61.139.2.69
EOF
}
