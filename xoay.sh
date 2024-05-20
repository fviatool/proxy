#!/bin/bash

# Hàm random tạo chuỗi ngẫu nhiên
random() {
    tr </dev/urandom -dc A-Za-z0-9 | head -c5
    echo
}

# Đưa hàm ip64 ra ngoài hàm gen64
ip64() {
    echo "${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}"
}

gen64() {
    echo "$1:$(ip64):$(ip64):$(ip64):$(ip64)"
}

# Hàm auto_detect_interface kiểm tra và chọn tên giao diện mạng tự động
auto_detect_interface() {
    INTERFACE=$(ip -o link show | awk -F': ' '$3 !~ /lo|vir|^[^0-9]/ {print $2; exit}')
}

# Hàm rotate_ipv6 xoay địa chỉ IPv6
rotate_ipv6() {
    IP4=$(curl -4 -s icanhazip.com)
    IP6=$(curl -6 -s icanhazip.com | cut -f1-4 -d':')
    main_interface="eth0"
    echo "IPv4: $IP4"
    echo "IPv6: $IP6"
    echo "Main interface: $main_interface"

    # Rotate IPv6 addresses
    gen_ipv6_64
    gen_ifconfig
    service network restart
    echo "IPv6 rotated and updated."
}

gen_ipv6_64() {
    if [ -f "$WORKDATA" ]; then
        rm "$WORKDATA"
    fi
    local ipv6_prefix="$1"
    local count_ipv6=1
    while [ "$count_ipv6" -le "$MAXCOUNT" ]; do
        local ipv6_address="$ipv6_prefix:$(ip64):$(ip64):$(ip64):$(ip64)"
        echo "$ipv6_address" >> "$WORKDATA"
        let "count_ipv6 += 1"
    done
}

# Hàm gen_ifconfig tạo lệnh ifconfig
gen_ifconfig() {
    while read -r line; do
        echo "ifconfig $IFCFG inet6 add $line/64"
    done < "$WORKDATA" > "$WORKDIR/boot_ifconfig.sh"
    chmod +x "$WORKDIR/boot_ifconfig.sh"
}

# Hàm gen_3proxy tạo cấu hình 3proxy
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
"flush\n"}' "${WORKDATA}")
EOF
}

# Hàm gen_iptables tạo luật iptables
gen_iptables() {
    awk -F "/" '{print "iptables -I INPUT -p tcp --dport " $4 "  -h state --state NEW -j ACCEPT"}' ${WORKDATA}
}

# Hàm download_proxy tải tệp proxy.txt
download_proxy() {
cd $WORKDIR/proxy.txt || return
    curl -F "file=@proxy.txt" https://file.io
}

# Hàm cài đặt 3proxy
install_3proxy() {
    URL="https://github.com/3proxy/3proxy/archive/refs/tags/0.9.4.tar.gz"
    wget -qO- $URL | bsdtar -xvf-
    cd 3proxy-0.9.4
    make -f Makefile.Linux
    mkdir -p /usr/local/etc/3proxy/{bin,stat}
    cp bin/3proxy /usr/local/etc/3proxy/bin/
    cp ../init.d/3proxy.sh /etc/init.d/3proxy
    chmod +x /etc/init.d/3proxy
    chkconfig 3proxy on
    cd $WORKDIR
}

# Thiết lập biến môi trường
WORKDIR="/home/cloudfly"
WORKDATA="${WORKDIR}/data.txt"
MAXCOUNT=2222
IFCFG="eth0"

# Bước cài đặt
echo "Installing necessary packages..."
yum -y install wget gcc net-tools bsdtar zip >/dev/null

rm -rf /root/3proxy-0.9.4

echo "Working folder: $WORKDIR"
mkdir -p "$WORKDIR" && cd "$WORKDIR" || exit

# Cài đặt 3proxy
install_3proxy

# Tạo cấu hình 3proxy
gen_3proxy > "/usr/local/etc/3proxy/3proxy.cfg"

# Tạo dữ liệu cho các địa chỉ IPv6
gen_ipv6_64

# Tạo lệnh ifconfig
gen_ifconfig

# Tạo luật iptables và thực hiện chúng
gen_iptables | bash
ulimit -n 10048
/usr/local/etc/3proxy/bin/3proxy /usr/local/etc/3proxy/3proxy.cfg
EOF

# Khởi động dịch vụ 3proxy
if [[ -x "/usr/local/etc/3proxy/bin/3proxy" ]]; then
    "/usr/local/etc/3proxy/bin/3proxy" "/usr/local/etc/3proxy/3proxy.cfg" &
else
    echo "[ERROR]: 3proxy binary not found!"
    exit 1
fi

echo "Starting Proxy"
echo "Number of current IPv6 addresses:"
ip -6 addr | grep inet6 | wc -l
download_proxy

echo "3proxy đang xoay tự động..."

# Khởi động xoay IPv6 tự động
rotate_ipv6 &

# Function to rotate IPv6 addresses
rotate_ipv6() {
    while true; do
        IP4=$(curl -4 -s icanhazip.com)
        IP6=$(curl -6 -s icanhazip.com | cut -f1-4 -d':')
        main_interface="eth0"
        echo "IPv4: $IP4"
        echo "IPv6: $IP6"
        echo "Main interface: $main_interface"

        # Rotate IPv6 addresses
        gen_ipv6_64
        gen_ifconfig
        service network restart
        echo "IPv6 rotated and updated."

        # Delay before next rotation
        sleep 300  # Chờ 5 phút trước khi cập nhật lại
    done
}
