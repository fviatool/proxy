#!/bin/bash

# Function to generate IPv6 addresses
gen_ipv6_64() {
    rm "$WORKDIR/data.txt"  # Xóa tệp tin cũ nếu tồn tại
    for port in $(seq 10000 10999); do
        array=( 1 2 3 4 5 6 7 8 9 0 a b c d e f )
        ip64() {
            echo "${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}"
        }
        echo "$IP6:$(ip64):$(ip64):$(ip64):$(ip64):$(ip64)/$port" >> "$WORKDIR/data.txt"
    done
}

# Function to generate 3proxy configuration
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

# Function to rotate IPv6 addresses
rotate_ipv6() {
    gen_ipv6_64
    # Đặt lại cấu hình 3proxy với các địa chỉ IPv6 mới
    gen_3proxy > /usr/local/etc/3proxy/3proxy.cfg
}

# Set up variables
WORKDIR="/home/cloudfly"
IP6=$(curl -6 -s icanhazip.com | cut -f1-4 -d':')

# Generate initial IPv6 addresses and 3proxy configuration
gen_ipv6_64
gen_3proxy > /usr/local/etc/3proxy/3proxy.cfg

# Thiết lập xoay địa chỉ IPv6 tự động
rotate_auto_ipv6() {
    while true; do
        rotate_ipv6
        sleep 600  # Đợi 10 phút
    done
}

# Khởi động xoay IPv6 tự động
rotate_auto_ipv6 &
