#!/bin/bash

WORKDIR="/home/cloudfly"
MAXCOUNT=2222
IFCFG="eth0"
START_PORT=10000

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

# Function to generate ip commands
gen_ip_commands() {
    while read -r line; do
        echo "ip -6 addr add $line/64 dev $IFCFG"
    done < "$WORKDIR/data.txt" > "$WORKDIR/boot_ip.sh"
}

# Rotate IPv6
rotate_ipv6() {
    echo "Đang xoay IPv6..."
    gen_ipv6_64
    gen_ip_commands
    bash "$WORKDIR/boot_ip.sh"
    service network restart
    echo "IPv6 đã được xoay và cập nhật."
}

# Function to get current IPv6 address
get_ipv6() {
    ipv6=$(curl -s https://ipv6test.google.com/api/myip.php)
    echo "$ipv6"
}

# Function to get current IPv4 address
get_ipv4() {
    ipv4=$(hostname -I | cut -d' ' -f1)
    echo "$ipv4"
}

# Main
echo "Kiểm tra kết nối IPv6 ..."
if ip -6 route get 2407:d140:1:100:1111 &> /dev/null; then
    IP4=$(get_ipv4)
    IP6=$(get_ipv6)
    main_interface="eth0"
    echo "[OKE]: Thành công"
    echo "IPV4: $IP4"
    echo "IPV6: $IP6"
    echo "Mạng chính: eth0"
else
    echo "[ERROR]: thất bại!"
    exit 1
fi

# Rotate IPv6 addresses every 10 minutes
while true; do
    rotate_ipv6
    sleep 600
done

# Proxy Start (Add your proxy configuration here)

echo "Xoay Proxy Done"
