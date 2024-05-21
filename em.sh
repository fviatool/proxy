#!/bin/sh

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
