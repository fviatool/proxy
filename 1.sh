#!/bin/#!/bin/bash

# Hàm tạo ngẫu nhiên IP và port IPv4
random_ip_port_ipv4() {
    local port=$((10000 + RANDOM % (60001 - 10000)))  # Tính toán cổng ngẫu nhiên
    local ipv4=$(curl -4 -s icanhazip.com)  # Lấy địa chỉ IPv4 hiện tại
    echo "$ipv4:$port ipv4.txt"  # Xuất ra địa chỉ IPv4 và cổng vào tập tin ipv4.txt
}

# Hàm tạo địa chỉ IPv6 ngẫu nhiên
gen_random_ipv6() {
    local array=(1 2 3 4 5 6 7 8 9 0 a b c d e f)  # Các ký tự hexa
    local ipv6=""
    for ((i = 0; i < 8; i++)); do
        ipv6+=${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}":"  # Tạo một cụm 4 ký tự hexa
    done
    ipv6=${ipv6%?}  # Loại bỏ dấu hai chấm cuối cùng
    echo "$ipv6"  # Xuất địa chỉ IPv6
}

# Hàm tạo dữ liệu proxy với số lượng proxy được nhập từ người dùng
gen_data() {
    for ((i = 0; i < $1; i++)); do
        random_ip_port_ipv4
        gen_random_ipv6
    done
}

# Hàm reset IPv6
reset_ipv6() {
    ip -6 addr flush dev eth0
    systemctl restart networking.service
    sleep 5
}

# Hàm xoay IPv6
rotate_ipv6() {
    ip -6 addr flush dev eth0
    ip -6 addr add $(gen_random_ipv6)/64 dev eth0
    systemctl restart networking.service
    sleep 5
}

# Hàm cài đặt 3proxy
install_3proxy() {
    version=0.8.9
    apt-get update && apt-get -y upgrade
    apt-get install gcc make git -y
    wget --no-check-certificate -O 3proxy-${version}.tar.gz https://raw.githubusercontent.com/Thanhan0901/install-proxy-v6/main/3proxy-${version}.tar.gz
    tar xzf 3proxy-${version}.tar.gz
    cd 3proxy-${version}
    make -f Makefile.Linux
    cd src
    mkdir /etc/3proxy/
    mv 3proxy /etc/3proxy/
    cd /etc/3proxy/
    wget --no-check-certificate https://github.com/SnoyIatk/3proxy/raw/master/3proxy.cfg
    chmod 600 /etc/3proxy/3proxy.cfg
    mkdir /var/log/3proxy/
    cd /etc/init.d/
    wget --no-check-certificate  https://raw.github.com/SnoyIatk/3proxy/master/3proxy
    chmod  +x /etc/init.d/3proxy
    update-rc.d 3proxy defaults
    cd $WORKDIR
}

# Hàm tạo cấu hình cho 3proxy
gen_3proxy() {
    cat <<EOF
daemon
maxconn 1000
nscache 65536
timeouts 1 5 30 60 180 1800 15 60
setgid 65535
setuid 65535
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

# Hàm tải lên proxy đã tạo lên một dịch vụ chia sẻ file
upload_proxy() {
    local PASS=$(random)
    zip --password $PASS proxy.zip proxy.txt
        URL=$(curl -s --upload-file proxy.zip https://transfer.sh/proxy.zip)
    
    echo "Proxy is ready! Format IP:PORT:LOGIN:PASS"
    echo "Download zip archive from: ${URL}"
    echo "Password: ${PASS}"
    
}

echo "installing apps"

install_3proxy

echo "working folder = /home/proxy"
WORKDIR="/home/proxy"
WORKDATA="${WORKDIR}/data.txt"
mkdir $WORKDIR && cd $_

IP4=$(curl -4 -s icanhazip.com)
IP6=$(curl -6 -s icanhazip.com | cut -f1-4 -d':')

echo "Internal ip = ${IP4}. External sub for ip6 = ${IP6}"

echo "How many proxies do you want to create? Example 500"
read COUNT

# Tạo dữ liệu proxy
gen_data $COUNT >$WORKDIR/data.txt
gen_3proxy >/etc/3proxy/3proxy.cfg
ulimit -S -n 4096
/etc/init.d/3proxy start

# Tạo tệp proxy.txt và tải lên
gen_proxy_file_for_user
upload_proxy

# Đặt lại IPv6
reset_ipv6
