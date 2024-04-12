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

# Hàm kiểm tra và chọn tên giao diện mạng tự động
auto_detect_interface() {
    INTERFACE=$(ip -o link show | awk -F': ' '$3 !~ /lo|vir|^[^0-9]/ {print $2; exit}')
}

install_3proxy() {
    echo "installing 3proxy"
    URL="https://github.com/z3APA3A/3proxy/archive/3proxy-0.8.6.tar.gz"
    wget -qO- $URL | tar -xzvf -
    cd 3proxy-3proxy-0.8.6
    make -f Makefile.Linux
    mkdir -p /usr/local/etc/3proxy/{bin,logs,stat}
    cp src/3proxy /usr/local/etc/3proxy/bin/
    cp ./scripts/rc.d/proxy.sh /etc/init.d/3proxy
    chmod +x /etc/init.d/3proxy
    chkconfig 3proxy on
    cd $WORKDIR || return
}

download_proxy() {
    cd /home/cloudfly || return
    curl -F "file=@proxy.txt" https://file.io
}

gen_3proxy() {
    cat <<EOF
daemon
maxconn 2000
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
        echo "//$IP4/$port/$(gen64 $IP6)"
    done
}

gen_iptables() {
    cat <<EOF
$(awk -F "/" '{print "iptables -I INPUT -p tcp --dport " $4 "  -m state --state NEW -j ACCEPT"}' ${WORKDATA}) 
EOF
}

# Hàm cập nhật thông tin giao diện mạng tự động
update_network_info() {
    auto_detect_interface
}

get_ipv4() {
    ipv4=$(curl -4 -s icanhazip.com)
    echo "$ipv4"
}

cat << EOF > /etc/rc.d/rc.local
#!/bin/bash
touch /var/lock/subsys/local
EOF

echo "Dang Tien Hanh Cai Dat Proxy"

install_3proxy

echo "working folder = /home/cloudfly"
WORKDIR="/home/cloudfly"
WORKDATA="${WORKDIR}/data.txt"
mkdir $WORKDIR || true
cd $WORKDIR || exit

update_network_info

IP4=$(get_ipv4)
IP6=$(curl -6 -s icanhazip.com | cut -f1-4 -d':')

echo "Internal ip = ${IP4}. External sub for ip6 = ${IP6}"

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
gen_data >”${WORKDIR}/data.txt”
gen_iptables >”${WORKDIR}/boot_iptables.sh”
gen_ifconfig >”${WORKDIR}/boot_ifconfig.sh”
rotate_proxy_script >”${WORKDIR}/rotate_3proxy.sh”

chmod +x “${WORKDIR}/boot_ifconfig.sh” “${WORKDIR}/boot_iptables.sh” /etc/rc.local
chmod +x “${WORKDIR}/rotate_3proxy.sh” /usr/local/etc/3proxy/rotate_3proxy.sh

gen_3proxy > /usr/local/etc/3proxy/3proxy.cfg

cat >> /etc/rc.local <<EOF
bash ${WORKDIR}/boot_iptables.sh
bash ${WORKDIR}/boot_ifconfig.sh
ulimit -n 10048
/usr/local/etc/3proxy/bin/3proxy /usr/local/etc/3proxy/3proxy.cfg
EOF

bash /etc/rc.local

gen_proxy_file_for_user
rm -rf /root/3proxy-3proxy-0.8.6

echo "Starting Proxy"
download_proxy
