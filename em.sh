#!/bin/bash

WORKDIR="/home/cloudfly"
IFCFG="eth0"
MAXCOUNT=2222
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

# Khởi tạo biến rotate_count để lưu trữ số lần xoay IPv6
rotate_count=0

# Thư mục làm việc
WORKDIR="/home/vlt"
WORKDATA="${WORKDIR}/data.txt"

# Hàm tạo địa chỉ IPv6 ngẫu nhiên
random() {
    tr </dev/urandom -dc A-Za-z0-9 | head -c5
    echo
}

# Mảng chứa các ký tự để tạo địa chỉ IPv6
array=(1 2 3 4 5 6 7 8 9 0 a b c d e f)

# Lấy giao diện mạng chính
main_interface=$(ip route get 8.8.8.8 | awk -- '{printf $5}')

# Hàm tạo địa chỉ IPv6 đầy đủ
gen64() {
    ip64() {
        echo "${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}"
    }
    echo "$1:$(ip64):$(ip64):$(ip64):$(ip64)"
}

# Hàm tạo dữ liệu
gen_data() {
    seq $FIRST_PORT $LAST_PORT | while read port; do
        echo "$(random)/$(random)/$IP4/$port/$(gen64 $IP6)"
    done
}

# Hàm tạo quy tắc iptables
gen_iptables() {
    cat <<EOF >${WORKDIR}/boot_iptables.sh
$(awk -F "/" '{print "iptables -A INPUT -p tcp --dport " $4 " -s " ALLOWED_IP_ADDRESS " -j ACCEPT"}' ${WORKDATA})
EOF
    chmod +x ${WORKDIR}/boot_iptables.sh
}

# Hàm tạo cấu hình ifconfig cho IPv6
gen_ifconfig() {
    cat <<EOF >${WORKDIR}/boot_ifconfig.sh
$(awk -F "/" '{print "ifconfig '$main_interface' inet6 add " $5 "/64"}' ${WORKDATA})
EOF
    chmod +x ${WORKDIR}/boot_ifconfig.sh
}

# Định nghĩa hàm rotate_ipv6 để xoay IPv6 và cập nhật số lần xoay
rotate_ipv6() {
    # Hiển thị thông báo xoay IPv6
    echo "Rotating IPv6 addresses..."
    
    # Lấy IPv6 mới từ icanhazip.com và cập nhật dữ liệu
    IP6=$(curl -6 -s icanhazip.com | cut -f1-4 -d':')
    gen_data >$WORKDIR/data.txt
    gen_ifconfig
    bash $WORKDIR/boot_ifconfig.sh
    
    # Hiển thị thông báo thành công và cập nhật số lần xoay
    echo "IPv6 addresses rotated successfully."
    rotate_count=$((rotate_count + 1))
    
    # Hiển thị số lần xoay mới nhất
    echo "Rotation count: $rotate_count"
}

# Vòng lặp để xoay IP sau mỗi 10 phút
while true; do
    rotate_ipv6
    sleep 600
done
