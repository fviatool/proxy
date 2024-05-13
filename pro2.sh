#!/bin/bash

WORKDIR="/home/cloudfly"
MAXCOUNT=2222
IFCFG="eth0"
START_PORT=2000

# Function to generate IPv6 addresses
gen_ipv6_64() {
    rm "$WORKDIR/data.txt"
    count_ipv6=1
    while [ "$count_ipv6" -le "$MAXCOUNT" ]; do
        array=( 1 2 3 4 5 6 7 8 9 0 a b c d e f )
        ip64() {
            echo "${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}"
        }
        echo "$IP6:$(ip64):$(ip64):$(ip64):$(ip64):$(ip64)" >> "$WORKDIR/data.txt"
        let "count_ipv6 += 1"
    done
}

# Function to generate ifconfig commands
gen_ifconfig() {
    while read -r line; do
        echo "ifconfig $IFCFG inet6 add $line/64"
    done < "$WORKDIR/data.txt" > "$WORKDIR/boot_ifconfig.sh"
}

# Rotate IPv6
rotate_ipv6() {
    echo "Đang xoay IPv6..."
    gen_ipv6_64
    gen_ifconfig
    bash "$WORKDIR/boot_ifconfig.sh"
    service network restart
    echo "IPv6 đã được xoay và cập nhật."
}

# Main
echo "Kiểm tra kết nối IPv6 ..."
if ip -6 route get 2403:6a40:0:16::1111 &> /dev/null; then
    IP4="103.161.16.141"
    IP6="2403:6a40:0:16"
    main_interface="eth0"
    echo "[OKE]: Thành công"
    echo "IPV4: 103.161.16.141"
    echo "IPV6: 2403:6a40:0:16"
    echo "Mạng chính: eth0"
else
    echo "[ERROR]: thất bại!"
    exit 1
fi

# Rotate IPv6 addresses
rotate_ipv6

# Proxy Start (Add your proxy configuration here)

echo "Xoay Proxy Done"

