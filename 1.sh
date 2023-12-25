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
    echo "installing 3proxy"
    URL="https://github.com/z3APA3A/3proxy/archive/3proxy-0.8.6.tar.gz"
    wget -qO- $URL | bsdtar -xvf-
    cd 3proxy-3proxy-0.8.6
    make -f Makefile.Linux
    mkdir -p /usr/local/etc/3proxy/{bin,logs,stat}
    cp src/3proxy /usr/local/etc/3proxy/bin/
    #cp ./scripts/rc.d/proxy.sh /etc/init.d/3proxy
    #chmod +x /etc/init.d/3proxy
    #chkconfig 3proxy on
    cd /root
}

gen_3proxy() {
    cat <<EOF
    echo daemon
    echo maxconn 3000
    echo nserver 1.1.1.1
    echo nserver [2606:4700:4700::1111]
    echo nserver [2606:4700:4700::1001]
    echo nserver [2001:4860:4860::8888]
    echo nscache 65536
    echo timeouts 1 5 30 60 180 1800 15 60
    echo setgid 65535
    echo setuid 65535
    echo stacksize 6291456 
    echo flush
    echo auth none

$(awk -F "/" '{print "\n" \
"" $1 "\n" \
"proxy -6 -n -a -p" $4 " -i" $3 " -e"$5"\n" \
"flush\n"}' /root/data.txt)
EOF
}

gen_proxy_file_for_user() {
    cat >/root/proxy.txt <<EOF
$(awk -F "/" '{print $3 ":" $4 ":" $1 ":" $2 }' /root/data.txt)
EOF
}

gen_data() {
    seq $FIRST_PORT $LAST_PORT | while read port; do
        echo "//$IP4/$port/$(gen64 $IP6)"
    done
}

gen_iptables() {
    cat <<EOF
    $(awk -F "/" '{print "iptables -I INPUT -p tcp --dport " $4 "  -m state --state NEW -j ACCEPT"}' /root/ipv6.txt) 
EOF
}

gen_ifconfig() {
    cat <<EOF
$(awk -F "/" '{print "ifconfig eth0 inet6 add " $5 "/64"}' /root/ipv6.txt)
EOF
}

echo "installing apps"
yum -y install wget gcc net-tools bsdtar zip >/dev/null

install_3proxy

echo "working folder = /root"

IP4=$(curl -4 -s icanhazip.com)
IP6=$(curl -6 -s icanhazip.com | cut -f1-4 -d':')

echo "Internal ip = ${IP4}. Exteranl sub for ip6 = ${IP6}"

while :; do
  read -p "Enter FIRST_PORT between 10000 and 60000: " FIRST_PORT
  [[ $FIRST_PORT =~ ^[0-9]+$ ]] || { echo "Enter a valid number"; continue; }
  if ((FIRST_PORT >= 10000 && FIRST_PORT <= 60000)); then
    echo "OK! Valid number"
    break
  else
    echo "Number out of range, try again"
  fi
done
LAST_PORT=$(($FIRST_PORT + 5555))
echo "LAST_PORT is $LAST_PORT. Continue..."

gen_data >/root/data.txt
gen_iptables >/root/boot_iptables.sh
gen_ifconfig >/root/boot_ifconfig.sh
chmod +x /root/boot_*.sh /etc/rc.local

gen_3proxy >/usr/local/etc/3proxy/3proxy.cfg

cat >>/etc/rc.local <<EOF
bash /root/boot_iptables.sh
bash /root/boot_ifconfig.sh
ulimit -n 10048
/usr/local/etc/3proxy/bin/3proxy /usr/local/etc/3proxy/3proxy.cfg
EOF

bash /etc/rc.local

gen_proxy_file_for_user
rm -rf /root/3proxy-3proxy-0.8.6

echo "Starting Proxy"
