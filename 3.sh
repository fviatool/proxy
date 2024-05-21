#!/bin/sh

# Thư mục làm việc và file dữ liệu
WORKDIR="/home/cloudfly"
WORKDATA="${WORKDIR}/data.txt"
mkdir -p $WORKDIR

# Biến để lưu số lần xoay IPv6
rotate_count=0

# Hàm tạo chuỗi ngẫu nhiên
random() {
    tr </dev/urandom -dc A-Za-z0-9 | head -c5
    echo
}

# Mảng ký tự để tạo địa chỉ IPv6
array=(1 2 3 4 5 6 7 8 9 0 a b c d e f)

# Hàm tạo địa chỉ IPv6 đầy đủ
gen64() {
    ip64() {
        echo "${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}"
    }
    echo "$1:$(ip64):$(ip64):$(ip64):$(ip64)"
}

# Hàm tạo dữ liệu proxy
gen_data() {
    seq $FIRST_PORT $LAST_PORT | while read port; do
        echo "$(random)/$(random)/$IP4/$port/$(gen64 $IP6)"
    done > $WORKDATA
}

# Hàm tạo cấu hình ifconfig cho IPv6
gen_ifconfig() {
    awk -F "/" '{print "ifconfig '$main_interface' inet6 add " $5 "/64"}' ${WORKDATA}
}

# Hàm xoay IPv6
rotate_ipv6() {
    echo "Rotating IPv6 addresses..."
    IP6=$(curl -6 -s icanhazip.com | cut -f1-4 -d':')
    gen_data
    gen_ifconfig > $WORKDIR/boot_ifconfig.sh
    bash $WORKDIR/boot_ifconfig.sh
    rotate_count=$((rotate_count + 1))
    echo "IPv6 addresses rotated successfully. Rotation count: $rotate_count"
}

# Cài đặt cấu hình ban đầu
initial_setup() {
    # IP và giao diện mạng
    IP4=$(curl -4 -s icanhazip.com)
    IP6=$(curl -6 -s icanhazip.com | cut -f1-4 -d':')
    main_interface=$(ip route get 8.8.8.8 | awk -- '{printf $5}')

    # Cấu hình dải cổng
    FIRST_PORT=20000
    LAST_PORT=21500

    echo "Internal IP: $IP4, External IPv6 sub: $IP6, Main interface: $main_interface"
    
    # Tạo dữ liệu và cấu hình ban đầu
    echo "Initializing proxy setup..."
    gen_data
    gen_ifconfig > $WORKDIR/boot_ifconfig.sh
    chmod +x $WORKDIR/boot_ifconfig.sh
    bash $WORKDIR/boot_ifconfig.sh
}

# Cài đặt cấu hình ban đầu
initial_setup

# Vòng lặp để xoay IP sau mỗi 5 phút
while true; do
    rotate_ipv6
    sleep 300
done
