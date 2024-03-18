#!/usr/bin/bash
gen_ipv6_64() {
	#Backup File
	rm $WORKDIR/ipv6.txt
	count_ipv6=1
	while [ "$count_ipv6" -le $MAXCOUNT ]
	do
		array=( 1 2 3 4 5 6 7 8 9 0 a b c d e f )
		ip64() {
			echo "${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}"
		}
		echo $IP6:$(ip64):$(ip64):$(ip64):$(ip64):$(ip64) >> $WORKDIR/ipv6.txt
		let "count_ipv6 += 1"
	done
}

gen_3proxy_cfg() {
	echo daemon
	echo maxconn 5000
	echo nserver 1.1.1.1
	echo nserver [2404:6800:4005:805::1111]
	echo nserver [2404:6800:4005:805::1001]
	echo nserver [2404:6800:4005:805::8888]
	echo nscache 65536
	echo timeouts 1 5 30 60 180 1800 15 60
	echo setgid 65535
	echo setuid 65535
	echo stacksize 6291456 
	echo flush
    echo auth none
	
	port=$START_PORT
	while read ip; do
		echo "proxy -6 -n -a -p$port -i$IP4 -e$ip"
		((port+=1))
	done < $WORKDIR/ipv6.txt
	echo "proxy -4 -n -a -p$rd -e$IP4"
	
}


gen_ifconfig() {
	while read line; do    
		echo "ifconfig $IFCFG inet6 add $line/64"
	done < $WORKDIR/ipv6.txt
}


if [ "x$(id -u)" != 'x0' ]; then
    echo 'Error: this script can only be executed by root'
    exit 1
fi

service network restart

ulimit -n 65535




echo "Cáº¥u hÃ¬nh xoay"
echo "Kiá»m tra káº¿t ná»i IPv6 ..."
if ip -6 route get 2404:6800:4005:805::1111 &> /dev/null
then
	IP4="192.168.1.151"
	IP6="2001:ee0:0"
	main_interface="eth0"
	
    echo "[OKE]: ThÃ nh cÃ´ng"
    	echo "IPV4: 192.168.1.151"
	echo "IPV6: 2001:ee0:0"
	echo "Máº¡ng chÃ­nh: eth0"
else
    echo "[ERROR]:  tháº¥t báº¡i! vui lÃ²ng kiá»m tra láº¡i máº¡ng hoáº·c liÃªn há» https://www.facebook.com/VivuCloud!"
	exit 1
fi

rd=6682
IFCFG="eth0" 
WORKDIR="/home/xpx/vivucloud"
m=""
START_PORT=10000
MAXCOUNT="5000"

echo "Äang táº¡o $MAXCOUNT IPV6 > ipv6.txt"
gen_ipv6_64


echo "Äang táº¡o IPV6 gen_ifconfig.sh"
gen_ifconfig >$WORKDIR/boot_ifconfig.sh
bash $WORKDIR/boot_ifconfig.sh

echo "Vivu Cloud Proxy Start"
gen_3proxy_cfg > /etc/3proxy/3proxy.cfg
killall 3proxy
service 3proxy start

echo "ÄÃ£ Reset IP thÃ nh cÃ´ng, tool by VivuCloud"
