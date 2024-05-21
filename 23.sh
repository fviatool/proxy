#!/bin/sh

# Khởi tạo biến rotate_count để lưu trữ số lần xoay IPv6
rotate_count=0

# Thư mục làm việc
WORKDIR="/home/cloudfly"
mkdir -p $WORKDIR

# Địa chỉ IP và giao diện mạng
IP4="103.121.91.158"
main_interface="eth0"

# Mảng ký tự để tạo địa chỉ IPv6
array=(1 2 3 4 5 6 7 8 9 0 a b c d e f)

# Hàm tạo địa chỉ IPv6 đầy đủ
gen_ipv6_64() {
    echo "${array[$RANDOM % 16]}${array[$RANDOM % 16]}:${array[$RANDOM % 16]}${array[$RANDOM % 16]}:${array[$RANDOM % 16]}${array[$RANDOM % 16]}:${array[$RANDOM % 16]}${array[$RANDOM % 16]}"
}

# Hàm tạo dữ liệu
gen_data() {
    seq $START_PORT $((START_PORT + MAXCOUNT - 1)) | while read port; do
        echo "$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c5)/$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c5)/$IP4/$port/$(gen_ipv6_64)"
    done > $WORKDIR/data.txt
}

# Hàm tạo cấu hình ifconfig cho IPv6
gen_ifconfig() {
    awk -F "/" '{print "ifconfig '$main_interface' inet6 add " $5 "/64"}' ${WORKDIR}/data.txt
}

# Hàm tạo cấu hình 3proxy
gen_3proxy_cfg() {
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
auth none

users $(awk -F "/" 'BEGIN{ORS="";} {print $1 ":CL:" $2 " "}' ${WORKDIR}/data.txt)

$(awk -F "/" '{print "auth none\n" \
"allow " $1 "\n" \
"proxy -6 -n -a -p" $4 " -i" $3 " -e"$5"\n" \
"flush\n"}' ${WORKDIR}/data.txt)
EOF
}

# Hàm xoay IPv6
rotate_ipv6() {
    echo "Rotating IPv6 addresses..."
    IP6=$(curl -6 -s icanhazip.com | cut -f1-4 -d':')
    gen_data
    gen_ifconfig > $WORKDIR/boot_ifconfig.sh
    bash $WORKDIR/boot_ifconfig.sh
    gen_3proxy_cfg > /etc/3proxy/3proxy.cfg
    killall 3proxy
    service 3proxy start
    rotate_count=$((rotate_count + 1))
    echo "IPv6 addresses rotated successfully. Rotation count: $rotate_count"
}

# Khởi tạo dữ liệu ban đầu
START_PORT=50000
MAXCOUNT=55555

# Tạo dữ liệu và cấu hình ban đầu
echo "Initializing proxy setup..."
gen_data
gen_ifconfig > $WORKDIR/boot_ifconfig.sh
chmod +x $WORKDIR/boot_ifconfig.sh
bash $WORKDIR/boot_ifconfig.sh
gen_3proxy_cfg > /etc/3proxy/3proxy.cfg
killall 3proxy
service 3proxy start

# Vòng lặp để xoay IP sau mỗi 5 phút
while true; do
    rotate_ipv6
    sleep 300
done
