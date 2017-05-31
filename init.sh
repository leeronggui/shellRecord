#!/bin/bash
#author: lironggui 
#email: ronggui.li@56qq.com
#黑石机房金融机器初始化脚本
#
PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
 . /lib/lsb/init-functions
apt-get update >/dev/null 2>&1 
apt-get -f -y install
mkdir -p /data/logs /var/logs
ln -sf /data/logs /var/logs

# 写日志

function log(){
	info="`date` $2 "
		if [ $1 -eq 0 ];then
				log_warning_msg "[成功] ${info}"
		else
				log_failure_msg "[失败] ${info}"
		fi
}

setLocale(){
	if grep -qE "LANG=\"en_US.UTF-8\"" /etc/default/locale ;then
		log 0 "字符编码已经设置,不用再次设置"
	elif grep -qE "LANG=\"en_US\"" /etc/default/locale;then
		sed -i 's/LANG="en_US"/LANG="en_US.UTF-8"/g' /etc/default/locale 
		log $? "设置字符编码"
	fi

}

setLimit(){
	if grep -q "1000000" /etc/security/limits.conf ;then
		log 0 "limit 已经配置,不需要重新配置."
	else
		echo "* soft nofile 1000000" >> /etc/security/limits.conf
		echo "* hard nofile 1000000" >> /etc/security/limits.conf
		log 0 "limit 配置成功."
	fi  
}

setSysctl(){
	num=$(egrep "net.ipv4.tcp_syn_retries|\
net.ipv4.tcp_synack_retries|\
net.ipv4.tcp_keepalive_time|\
net.ipv4.tcp_keepalive_probes|\
net.ipv4.tcp_keepalive_intvl|\
net.ipv4.tcp_fin_timeout|\
net.ipv4.tcp_max_syn_backlog|\
net.ipv4.tcp_tw_recycle|\
net.ipv4.tcp_max_syn_backlog|\
net.ipv4.tcp_tw_reuse|\
net.ipv4.ip_local_port_range|\
net.core.somaxconn" /etc/sysctl.conf | wc -l)
	if [[ $num -eq 11 ]];then
		log 0 "sysctl系统参数已经设置，跳过该配置."	
	elif [[ $num -eq 0 ]];then
		echo "
net.ipv4.tcp_syn_retries = 1
net.ipv4.tcp_synack_retries = 1
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_keepalive_probes = 1
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_max_syn_backlog = 4096
net.ipv4.tcp_tw_recycle = 0
net.ipv4.tcp_tw_reuse = 1
net.ipv4.ip_local_port_range = 1024    65535
net.core.somaxconn=32768
">>/etc/sysctl.conf
		sysctl -p 
		log 0 "sysctl 系统参数设置成功."
	else
		log 1 "sysctl参数已经有相关配置，请检查,配置失败."
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
	elif [[ $(grep -c "10.14." /etc/resolvconf/resolv.conf.d/base) -eq 3 ]];then
		log 0 "DNS已经设置,不需要再次设置!"
	else
				cat > /etc/resolvconf/resolv.conf.d/base << EOF
nameserver 10.14.1.4
nameserver 10.14.1.2
nameserver 10.14.1.3
EOF
		resolvconf -u
				log 0 "成功设置dns."
	
	fi
}
baseInstall(){
	which curl || apt-get -y install curl

}

#set hostname
setHostname(){
	dnsserver=10.14.1.4
	IP=`ifconfig bond1 | grep "inet addr" |awk '{print $2}' |awk -F':' '{print $NF}'`
	log $? "获取本机IP地址：$IP"
	name=`dig +time=1 +tries=1 -x ${IP} @${dnsserver} | grep PTR |awk '{print $NF}' | grep -v PTR| awk -F. '{print $1}'`
	log $? "获取本机主机名:$name"
	hostname | grep -q $name && log 0 "已经设置hostname."
	hostnamectl set-hostname ${name}
	log $? "设置主机名"
	grep -q "127.0.0.1" /etc/hosts || echo "127.0.0.1  localhost" > /etc/hosts
	grep -q "$name" /etc/hosts || echo "$IP $name" >> /etc/hosts
}
#installDocker

installDocker(){
	if which docker >/dev/null 2>&1;then
		log 0 "已经安装了docker,不需要重新安装."
	else
		apt-get update
		apt-get -y install curl
		curl -sSL http://acs-public-mirror.oss-cn-hangzhou.aliyuncs.com/docker-engine/internet | sh -	
		grep -qE "/data/docker" /etc/default/docker || echo 'DOCKER_OPTS="-g /data/docker --insecure-registry docker.56qq.cn:5000 -H 0.0.0.0:2375 -H unix:///var/run/docker.sock "' >> /etc/default/docker
		service docker restart
	fi
	if [ -f /root/.docker/config.json ];then
		log 0 "已经配置了docker认证信息，不需要重新配置."
	else
		mkdir -p /root/.docker/
		echo "{\"auths\": {\"docker.56qq.com\": {\"auth\": \"aGNiOjU2cXEuZG9ja2VyMg==\",\"email\": \"tao.feng@56qq.com\"}}}" > /root/.docker/config.json
		chmod 400 /root/.docker/config.json && chmod 700 /root/.docker
		log $? "配置docker认证信息."
	fi
	service docker restart
	log $? "重启docker服务"
	sed -i  "/GRUB_CMDLINE_LINUX=/c GRUB_CMDLINE_LINUX='console=ttyS0 console=tty0 printk.time=1 crashkernel=1800M-4G:128M,4G-:168M panic=5 net.ifnames=0 biosdevname=0 intel_idle.max_cstate=1 processor.max_cstate=1  intel_pstate=disable cgroup_enable=memory swapaccount=1'" /etc/default/grub
	update-grub
	log $? "更新docker limit配置"
	#del route
	d=`route -n| grep ^172 | grep bond1 | awk '{print $NF}'`
	if [ "$d" == "bond1" ];then
       	 route del -net 172.16.0.0 netmask 255.240.0.0
       	 sed -i  '/172.16.0.0 netmask 255.240.0.0/d' /etc/network/interfaces
		log $? "docker network route 已经处理"
	else
		log 0 "docker network route 已经处理.不需要重复处理"
	fi
}

#installNginx

installNginx(){
	if which nginx > /dev/null 2>&1;then
		log 0 "已经安装nginx,不需要重新安装."
	else
		apt-get -y install nginx > /dev/null 2>&1
cat > /etc/nginx/nginx.conf << EOF
user www-data;
worker_processes 16;
worker_rlimit_nofile 65535;
pid /run/nginx.pid;

events {
        worker_connections 65535;
}

http {
        sendfile on;
        tcp_nopush on;
        tcp_nodelay on;
        keepalive_timeout 65;
        types_hash_max_size 2048;
        server_tokens off;
        client_max_body_size 100m;

        log_format  main  '$remote_addr clientip:$http_cdn_Src_Ip cdnip:$http_x_forwarded_for $http_host [$time_local] "$request" $status  $body_bytes_sent "$http_user_agent" $upstream_addr $upstream_status $request_time $upstream_response_time';

        include /etc/nginx/mime.types;
        default_type application/octet-stream;

        access_log /data/logs/nginx/access.log main;
        error_log /data/logs/nginx/error.log;

        gzip on;
        gzip_disable "msie6";

        gzip_vary on;
        gzip_proxied any;
        gzip_comp_level 6;
        gzip_buffers 16 8k;
        gzip_http_version 1.1;
        gzip_types text/plain text/css application/json text/json application/x-javascript text/xml application/xml application/xml+rss text/javascript;

        include /etc/nginx/vhosts/*.conf;
}
EOF
		log $? "安装nginx."
	fi
	
}

installDnsmasq(){
	which dnsmasq >/dev/null 2>&1 && log 1 "检查是否已经安装dnsmasq."
	apt-get update
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

case $1 in
	app)
		setDns
		setLimit
		setSysctl
		setHostname
		setLocale
		installDocker
	;;
	nginx)
		installNginx
	;;		
	docker)
		installDocker
	;;
	dns)
		installDnsmasq
	;;
esac
