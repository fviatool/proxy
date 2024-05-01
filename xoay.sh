#!/bin/sh

# Hàm tạo chuỗi ngẫu nhiên
random() {
	tr </dev/urandom -dc A-Za-z0-9 | head -c5
	echo
}

# Mảng chứa các ký tự hex
array=(1 2 3 4 5 6 7 8 9 0 a b c d e f)

# Hàm tạo địa chỉ IPv6 64-bit ngẫu nhiên
gen64() {
	ip64() {
		echo "${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}"
	}
	echo "$1:$(ip64):$(ip64):$(ip64):$(ip64)"
}

# Hàm lấy tên card mạng
get_network_card() {
    network_card=$(ip -o link show | awk '$2 !~ "lo|vir|wl" {print $2}' | cut -d: -f2 | head -1)
}

# Hàm lấy địa chỉ IPv6
get_ipv6_address() {
    IP6=$(ip -6 addr show dev $network_card | awk '/inet6/ {print $2}' | grep -v -E "^fe80" | awk -F'/' '{print $1}')
}

# Hàm cài đặt 3proxy
install_3proxy() {
    echo "Đang cài đặt 3proxy"
    mkdir -p /3proxy
    cd /3proxy
    URL="https://github.com/z3APA3A/3proxy/archive/0.9.3.tar.gz"
    wget -qO- $URL | bsdtar -xvf-
    cd 3proxy-0.9.3
    make -f Makefile.Linux
    mkdir -p /usr/local/etc/3proxy/{bin,logs,stat}
    mv /3proxy/3proxy-0.9.3/bin/3proxy /usr/local/etc/3proxy/bin/
    cp /3proxy/3proxy-0.9.3/scripts/3proxy.service2 /usr/lib/systemd/system/3proxy.service
    systemctl link /usr/lib/systemd/system/3proxy.service
    systemctl daemon-reload
    echo "* hard nofile 999999" >>  /etc/security/limits.conf
    echo "* soft nofile 999999" >>  /etc/security/limits.conf
    echo "net.ipv6.conf.$network_card.proxy_ndp=1" >> /etc/sysctl.conf
    echo "net.ipv6.conf.all.proxy_ndp=1" >> /etc/sysctl.conf
    echo "net.ipv6.conf.default.forwarding=1" >> /etc/sysctl.conf
    echo "net.ipv6.conf.all.forwarding=1" >> /etc/sysctl.conf
    echo "net.ipv6.ip_nonlocal_bind = 1" >> /etc/sysctl.conf
    sysctl -p
    systemctl stop firewalld
    systemctl disable firewalld
    cd $WORKDIR
}

# Hàm tạo cấu hình cho 3proxy
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
auth strong
users $(awk -F "/" 'BEGIN{ORS="";} {print $1 ":CL:" $2 " "}' ${WORKDATA})
$(awk -F "/" '{print "auth strong\n" \
"allow " $1 "\n" \
"proxy -6 -n -a -p" $4 " -i" $3 " -e"$5"\n" \
"flush\n"}' ${WORKDATA})
EOF
}

# Hàm tạo tệp proxy.txt cho người dùng
gen_proxy_file_for_user() {
    cat >proxy.txt <<EOF
$(awk -F "/" '{print $3 ":" $4 ":" $1 ":" $2 }' ${WORKDATA})
EOF
}

# Hàm upload proxy
upload_proxy() {
    cd $WORKDIR
    local PASS=$(random)
    zip --password $PASS proxy.zip proxy.txt
    URL=$(curl -F "file=@proxy.zip" https://file.io)

    echo "Proxy đã sẵn sàng! Định dạng IP:PORT:LOGIN:PASS"
    echo "Tải xuống file zip tại: ${URL}"
    echo "Mật khẩu: ${PASS}"
}

# Hàm tạo dữ liệu cho proxy
gen_data() {
    seq $FIRST_PORT $LAST_PORT | while read port; do
        echo "vlt/vlt/$IP4/$port/$(gen64 $IP6)"
    done
}

# Hàm tạo iptables
gen_iptables() {
    cat <<EOF
    $(awk -F "/" '{print "iptables -I INPUT -p tcp --dport " $4 "  -m state --state NEW -j ACCEPT"}' ${WORKDATA})
 
EOF
}

# Hàm tạo các lệnh ifconfig
gen_ifconfig() {
    cat <<EOF
$(awk -F "/" '{print "ifconfig $network_card inet6 add " $5 "/64"}' ${WORKDATA})
EOF
}

echo "Đang cài đặt ứng dụng cần thiết"
yum -y install gcc net-tools bsdtar zip make >/dev/null

get_network_card
get_ipv6_address
install_3proxy

echo "Thư mục làm việc = /home/proxy"
WORKDIR="/home/proxy"
WORKDATA="${WORKDIR}/data.txt"
mkdir $WORKDIR && cd $_

IP4=$(curl -4 -s icanhazip.com)
IP6=$(echo "$IP6" | cut -f1-4 -d':')

echo "IP nội bộ = ${IP4}. Dải IP ngoại vi cho IPv6 = ${IPV6}"

# Generate random ports
while :; do
  FIRST_PORT=$(($(od -An -N2 -i /dev/urandom) % 80001 + 10000))
  if [[ $FIRST_PORT =~ ^[0-9]+$ ]] && ((FIRST_PORT >= 10000 && FIRST_PORT <= 80000)); then
    echo "Random ports generated successfully!"
    LAST_PORT=$((FIRST_PORT + 999))
    echo "LAST_PORT is $LAST_PORT. Continuing…”
break
else
echo “Failed to generate random ports. Retrying…”
fi
done

gen_data >$WORKDIR/data.txt
gen_iptables >$WORKDIR/boot_iptables.sh
gen_ifconfig >$WORKDIR/boot_ifconfig.sh
chmod +x $WORKDIR/boot_*.sh /etc/rc.local

gen_3proxy >/usr/local/etc/3proxy/3proxy.cfg

cat >>/etc/rc.local <<EOF
systemctl start NetworkManager.service
ifup $network_card
while true; do
bash ${WORKDIR}/boot_iptables.sh
bash ${WORKDIR}/boot_ifconfig.sh
ulimit -n 65535
/usr/local/etc/3proxy/bin/3proxy /usr/local/etc/3proxy/3proxy.cfg &
sleep 600  # Chờ 10 phút trước khi chạy lại để xoay IPv6
done
EOF

bash /etc/rc.local
