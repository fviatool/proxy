#!/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

random() {
	tr </dev/urandom -dc A-Za-z0-9 | head -c5
	echo
}

array=(1 2 3 4 5 6 7 8 9 0 a b c d e f)

gen64() {
	ip64() {
		echo "${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}"
	}
	echo "$1:$(ip64):$(ip64):$(ip64):$(ip64)"
}

install_3proxy() {
	echo "Đang cài đặt 3proxy..."
	URL="https://github.com/z3APA3A/3proxy/archive/3proxy-0.8.6.tar.gz"
	wget -qO- $URL | bsdtar -xvf-
	cd 3proxy-3proxy-0.8.6
	make -f Makefile.Linux
	mkdir -p /usr/local/etc/3proxy/{bin,logs,stat}
	cp src/3proxy /usr/local/etc/3proxy/bin/
	cd $WORKDIR
}

gen_3proxy() {
	cat <<EOF
daemon
maxconn 3000
nserver 1.1.1.1
nserver 8.8.4.4
nserver 2001:4860:4860::8888
nserver 2001:4860:4860::8844
nscache 65536
timeouts 1 5 30 60 180 1800 15 60
setgid 65535
setuid 65535
stacksize 6291456 
flush
$(awk -F "/" '{print "\n" \
"" $1 "\n" \
"proxy -6 -n -a -p" $4 " -i" $3 " -e"$5"\n" \
"flush\n"}' ${WORKDATA})
EOF
}

gen_proxy_file_for_user() {
	cat >proxy.txt <<EOF
$(awk -F "/" '{print $3 ":" $4 ":" $1 ":" $2 }' ${WORKDATA})
EOF
}

gen_data() {
	seq $FIRST_PORT $LAST_PORT | while read port; do
		echo "$(gen64 $IP6)"
	done
}

gen_iptables() {
	cat <<EOF
$(awk -F "/" '{print "iptables -I INPUT -p tcp --dport " $4 "  -m state --state NEW -j ACCEPT"}' ${WORKDATA}) 
EOF
}

gen_ifconfig() {
	cat <<EOF
$(awk -F "/" '{print "ifconfig eth0 inet6 add " $5 "/64"}' ${WORKDATA})
EOF
}

echo "Đang cài đặt các ứng dụng cần thiết..."
yum -y install gcc net-tools bsdtar zip >/dev/null

install_3proxy

echo "Thư mục làm việc = /home/cloudfly"
WORKDIR="/home/cloudfly"
WORKDATA="${WORKDIR}/data.txt"
mkdir $WORKDIR && cd $_

IP4=$(curl -4 -s icanhazip.com)
IP6=$(curl -6 -s icanhazip.com | cut -f1-4 -d':')

echo "IP Nội bộ = ${IP4}. Subnet Ngoại vi cho IPv6 = ${IP6}"

while :; do
	read -p "Nhập PORT ĐẦU TIÊN giữa 10000 và 60000: " FIRST_PORT
	[[ $FIRST_PORT =~ ^[0-9]+$ ]] || { echo "Vui lòng nhập một số hợp lệ"; continue; }
	if ((FIRST_PORT >= 10000 && FIRST_PORT <= 60000)); then
		echo "OK! Số hợp lệ"
		break
	else
		echo "Số không nằm trong phạm vi, vui lòng thử lại"
	fi
done

LAST_PORT=$(($FIRST_PORT + 3333))
echo "LAST_PORT là $LAST_PORT. Tiếp tục..."

gen_data >$WORKDIR/ipv6.txt
gen_iptables >$WORKDIR/boot_iptables.sh
gen_ifconfig >$WORKDIR/boot_ifconfig.sh
chmod +x boot_*.sh /etc/rc.local

gen_3proxy >/usr/local/etc/3proxy/3proxy.cfg

cat >>/etc/rc.local <<EOF
bash ${WORKDIR}/boot_iptables.sh
bash ${WORKDIR}/boot_ifconfig.sh
ulimit -n 10048
/usr/local/etc/3proxy/bin/3proxy /usr/local/etc/3proxy/3proxy.cfg
EOF

bash /etc/rc.local

gen_proxy_file_for_user
rm -rf /root/3proxy-3proxy-0.8.6

echo "Khởi động Proxy"
