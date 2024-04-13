#!/bin/sh
random() {
	tr </dev/urandom -dc A-Za-z0-9 | head -c8
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
    URL="https://github.com/3proxy/3proxy/archive/refs/tags/0.9.4.tar.gz"
    wget -qO- $URL | bsdtar -xvf-
    cd 3proxy-0.9.4
    make -f Makefile.Linux
    mkdir -p /usr/local/etc/3proxy/{bin,stat}
    cp bin/3proxy /usr/local/etc/3proxy/bin/
    cp ../init.d/3proxy.sh /etc/init.d/3proxy
    chmod +x /etc/init.d/3proxy
    chkconfig 3proxy on
    cd $WORKDIR
}

gen_3proxy() {
    cat <<EOF
daemon
timeouts 1 5 30 60 180 1800 15 60
flush
log /dev/null

$(awk -F "/" '{print "auth none\n" \
"allow *.*.*.*\n" \
"socks -n -a -s0 -64 -olSO_REUSEADDR,SO_REUSEPORT -ocTCP_TIMESTAMPS,TCP_NODELAY -osTCP_NODELAY -p"$4" -i"$3" -e"$5"\n" \
"flush\n"}' ${WORKDATA})
EOF
}

gen_proxy_file_for_user() {
    cat >proxy.txt <<EOF
$(awk -F "/" '{print $3":"$4}' ${WORKDATA})
EOF
}

download_proxy() {
    cd /home/cloudfly || return
    curl -F "file=@proxy.txt" https://file.io
}

gen_data() {
    seq $FIRST_PORT $LAST_PORT | while read port; do
        echo "$(random)/$IP4/$port/$(gen64 $IP6)"
    done
}

gen_iptables() {
    cat <<EOF
    $(awk -F "/" '{print "iptables -I INPUT -p tcp --dport "$4"  -m state --state NEW -j ACCEPT"}' ${WORKDATA}) 
EOF
}

gen_ifconfig() {
    cat <<EOF
$(awk -F "/" '{print "ifconfig eth0 inet6 add "$5"/64"}' ${WORKDATA})
EOF
}

get_ipv4() {
    ipv4=$(curl -4 -s icanhazip.com)
    echo "$ipv4"
}

yum -y install gcc net-tools bsdtar zip >/dev/null

install_3proxy

WORKDIR="/home/cloudfly"
WORKDATA="${WORKDIR}/data.txt"
mkdir $WORKDIR && cd $_

echo "Your IPv4 address:"
IP4=$(get_ipv4)
echo "$IP4"

echo "Your IPv6 subnet:"
read IPv6

IP6=${IPv6}

echo "Internal ip = ${IP4}. Exteranl sub for ip6 = ${IP6}"

while :; do
  FIRST_PORT=$(($(od -An -N2 -i /dev/urandom) % 80001 + 10000))
  if [[ $FIRST_PORT =~ ^[0-9]+$ ]] && ((FIRST_PORT >= 10000 && FIRST_PORT <= 80000)); then
    echo "OK! Random Ngau Nhien Port"
    LAST_PORT=$((FIRST_PORT + 999))
    echo "LAST_PORT is $LAST_PORT. Tien Hanh Tiep Tuc..."
    break
  else
    echo "Tao Song Cau Hinh Dang Thiet Lap Proxy"
  fi
done

gen_data >$WORKDIR/data.txt
gen_iptables >$WORKDIR/boot_iptables.sh
gen_ifconfig >$WORKDIR/boot_ifconfig.sh
chmod +x ${WORKDIR}/boot_*.sh /etc/rc.local

gen_3proxy >/usr/local/etc/3proxy/3proxy.cfg

echo "net.ipv6.conf.eth0.proxy_ndp=1" >> /etc/sysctl.conf
echo "net.ipv6.conf.all.proxy_ndp=1" >> /etc/sysctl.conf
echo "net.ipv6.conf.default.forwarding=1" >> /etc/sysctl.conf
echo "net.ipv6.conf.all.forwarding=1" >> /etc/sysctl.conf
echo "net.ipv6.ip_nonlocal_bind=1" >> /etc/sysctl.conf
echo "vm.max_map_count=95120" >> /etc/sysctl.conf
echo "kernel.pid_max=95120" >> /etc/sysctl.conf
echo "net.ipv4.ip_local_port_range=1024 65000" >> /etc/sysctl.conf
sudo sysctl -p

chmod -R 777 /usr/local/etc/3proxy/

cat >>/etc/rc.local <<EOF
bash ${WORKDIR}/boot_iptables.sh
bash ${WORKDIR}/boot_ifconfig.sh

ulimit -n 999999

service 3proxy start
EOF

bash /etc/rc.local

gen_proxy_file_for_user
download_proxy
