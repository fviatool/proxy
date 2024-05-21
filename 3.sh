#!/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

# Thư mục làm việc
WORKDIR="/home/cloudfly"
WORKDATA="${WORKDIR}/data.txt"
mkdir -p $WORKDIR && cd $WORKDIR

# IP và giao diện mạng
IP4=$(curl -4 -s icanhazip.com)
IP6=$(curl -6 -s icanhazip.com | cut -f1-4 -d':')
main_interface=$(ip route get 8.8.8.8 | awk -- '{printf $5}')

# Cấu hình dải cổng
FIRST_PORT=20000
LAST_PORT=21500

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

# Hàm cài đặt 3proxy
install_3proxy() {
    echo "Installing 3proxy..."
    URL="https://github.com/z3APA3A/3proxy/archive/3proxy-0.8.6.tar.gz"
    wget -qO- $URL | tar -xz
    cd 3proxy-3proxy-0.8.6
    make -f Makefile.Linux
    mkdir -p /usr/local/etc/3proxy/{bin,logs,stat}
    cp src/3proxy /usr/local/etc/3proxy/bin/
    cd $WORKDIR
}

# Hàm tạo dữ liệu
gen_data() {
    seq $FIRST_PORT $LAST_PORT | while read port; do
        echo "$(random)/$(random)/$IP4/$port/$(gen64 $IP6)"
    done > $WORKDATA
}

# Hàm tạo quy tắc iptables
gen_iptables() {
    awk -F "/" '{print "iptables -I INPUT -p tcp --dport " $4 " -j ACCEPT"}' ${WORKDATA}
}

# Hàm tạo cấu hình ifconfig cho IPv6
gen_ifconfig() {
    awk -F "/" '{print "ifconfig '$main_interface' inet6 add " $5 "/64"}' ${WORKDATA}
}

# Hàm tạo cấu hình 3proxy
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

$(awk -F "/" '{print "auth none\n" \
"allow " $1 "\n" \
"proxy -6 -n -a -p" $4 " -i" $3 " -e"$5"\n" \
"flush\n"}' ${WORKDATA})
EOF
}

# Hàm tạo file proxy cho người dùng
gen_proxy_file_for_user() {
    awk -F "/" '{print $3 ":" $4 ":" $1 ":" $2 }' ${WORKDATA} > proxy.txt
}

# Hàm xoay IPv6
rotate_ipv6() {
    echo "Rotating IPv6 addresses..."
    IP6=$(curl -6 -s icanhazip.com | cut -f1-4 -d':')
    gen_data
    gen_ifconfig > $WORKDIR/boot_ifconfig.sh
    bash $WORKDIR/boot_ifconfig.sh
    gen_3proxy > /usr/local/etc/3proxy/3proxy.cfg
    killall 3proxy
    /usr/local/etc/3proxy/bin/3proxy /usr/local/etc/3proxy/3proxy.cfg
    rotate_count=$((rotate_count + 1))
    echo "IPv6 addresses rotated successfully. Rotation count: $rotate_count"
}

# Hàm cài đặt môi trường
setup_environment() {
    echo "Installing necessary packages"
    yum -y install gcc net-tools bsdtar zip make >/dev/null
}

# Cài đặt 3proxy và cấu hình ban đầu
setup_environment
install_3proxy
gen_data
gen_ifconfig > $WORKDIR/boot_ifconfig.sh
chmod +x $WORKDIR/boot_ifconfig.sh
bash $WORKDIR/boot_ifconfig.sh
gen_iptables > $WORKDIR/boot_iptables.sh
chmod +x $WORKDIR/boot_iptables.sh
bash $WORKDIR/boot_iptables.sh
gen_3proxy > /usr/local/etc/3proxy/3proxy.cfg

cat >>/etc/rc.local <<EOF
bash ${WORKDIR}/boot_iptables.sh
bash ${WORKDIR}/boot_ifconfig.sh
ulimit -n 10048
/usr/local/etc/3proxy/bin/3proxy /usr/local/etc/3proxy/3proxy.cfg
EOF

chmod +x /etc/rc.local
bash /etc/rc.local

gen_proxy_file_for_user

# Vòng lặp để xoay IP sau mỗi 5 phút
auto_rotate_ipv6() {
    while true; do
        rotate_ipv6
        sleep 300
    done
}

# Menu chính
menu() {
    while true; do
        clear
        echo "============================"
        echo " IPv6 Rotation Menu "
        echo "============================"
        echo "1. Rotate IPv6 Now"
        echo "2. Start Auto Rotation (every 5 minutes)"
        echo "3. Exit"
        echo "============================"
        read -p "Please enter your choice: " choice

        case $choice in
            1)
                rotate_ipv6
                read -p "Press Enter to continue..."
                ;;
            2)
                auto_rotate_ipv6
                ;;
            3)
                exit 0
                ;;
            *)
                echo "Invalid choice, please try again."
                read -p "Press Enter to continue..."
                ;;
        esac
    done
}

# Chạy menu
menu
