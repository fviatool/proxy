#!/bin/bash

# Hàm random tạo chuỗi ngẫu nhiên
random() {
    tr </dev/urandom -dc A-Za-z0-9 | head -c5
    echo
}

# Hàm gen64 tạo địa chỉ IPv6 ngẫu nhiên
array=(1 2 3 4 5 6 7 8 9 0 a b c d e f)
gen64() {
    ip64() {
        echo "${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}"
    }
    echo "$1:$(ip64):$(ip64):$(ip64):$(ip64)"
}

# Hàm auto_detect_interface kiểm tra và chọn tên giao diện mạng tự động
auto_detect_interface() {
    INTERFACE=$(ip -o link show | awk -F': ' '$3 !~ /lo|vir|^[^0-9]/ {print $2; exit}')
}

# Get IPv6 address
ipv6_address=$(ip addr show eth0 | awk '/inet6/{print $2}' | grep -v '^fe80' | head -n1)

# Kiểm tra xem có nhận được địa chỉ IPv6 không
if [ -n "$ipv6_address" ]; then
    echo "IPv6 address obtained: $ipv6_address"

    # Khai báo mảng kết hợp để lưu trữ địa chỉ IPv6 và cổng cổng mặc định
    declare -A ipv6_addresses=(
        [4]="2001:ee0:4f9b::$IPD:0000/64"
        [5]="2001:ee0:4f9b::$IPD:0000/64"
        [244]="2001:ee0:4f9b::$IPD:0000/64"
        ["default"]="2001:ee0:4f9b::$IPC::$IPD:0000/64"
    )

    declare -A gateways=(
        [4]="2001:ee0:4f9b:$IPC::1"
        [5]="2001:ee0:4f9b:$IPC::1"
        [244]="2001:ee0:4f9b:$IPC::1"
        ["default"]="2001:ee0:4f9b:$IPC::1"
    )

    # Lấy ra các octet thứ ba và thứ tư của IPv4
    IPC=$(echo "$ipv6_address" | cut -d":" -f5)
    IPD=$(echo "$ipv6_address" | cut -d":" -f6)

    # Đặt địa chỉ IPv6 và cổng mặc định dựa trên octet thứ ba của IPv4
    IPV6_ADDRESS="${ipv6_addresses[$IPC]}"
    GATEWAY="${gateways[$IPC]}"

    # Kiểm tra xem giao diện có sẵn không
    INTERFACE=$(ip -o link show | awk -F': ' '{print $2}' | grep -v lo | head -n1)

    if [ -n "$INTERFACE" ]; then
        echo "Configuring interface: $INTERFACE"

        # Cấu hình IPv6
        echo "IPV6_ADDR_GEN_MODE=stable-privacy" >> /etc/network/interfaces
        echo "IPV6ADDR=$ipv6_address/64" >> /etc/network/interfaces
        echo "IPV6_DEFAULTGW=$GATEWAY" >> /etc/network/interfaces

        # Khởi động lại dịch vụ mạng
        service networking restart
        systemctl restart NetworkManager.service
        ifconfig "$INTERFACE"
        echo "Done!"
    else
        echo "No network interface available."
    fi
else
    echo "No IPv6 address obtained."
fi

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

WORKDIR="/home/cloudfly"
WORKDATA="${WORKDIR}/data.txt"
MAXCOUNT=2222
IFCFG="eth0"
FIRST_PORT=10000
LAST_PORT=10500

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

# Hàm gen_ipv6_64 tạo địa chỉ IPv6
gen_ipv6_64() {
    rm "$WORKDIR/data.txt" 2>/dev/null
    count_ipv6=1
    while [ "$count_ipv6" -le "$MAXCOUNT" ]; do
        array=( 1 2 3 4 5 6 7 8 9 0 a b c d e f )
        ip64() {
            echo "${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}"
        }
        echo "$IP6:$(ip64):$(ip64):$(ip64):$(ip64):$(ip64)" >> "$WORKDATA"
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
    cat <<EOF
    $(awk -F "/" '{print "iptables -I INPUT -p tcp --dport "$4"  -m state --state NEW -j ACCEPT"}' ${WORKDATA}) 
EOF
}

# Hàm download_proxy tải tệp proxy.txt
download_proxy() {
    cd /home/cloudfly || return
    curl -F "file=@proxy.txt" https://file.io
}

# Bước cài đặt
echo "Installing necessary packages..."
yum -y install wget gcc net-tools bsdtar zip >/dev/null

rm -rf /root/3proxy-0.9.4

echo "Working folder: $WORKDIR"
mkdir -p "$WORKDIR" && cd "$WORKDIR" || exit

# Install 3proxy
install_3proxy

gen_3proxy > "/usr/local/etc/3proxy/3proxy.cfg"

# Tạo dữ liệu cho các địa chỉ IPv6
gen_ipv6_64

# Tạo lệnh ifconfig
gen_ifconfig

# Tạo luật iptables và thực hiện chúng
gen_iptables | bash

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

echo "3proxy setup completed."
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

# Khởi động xoay IPv6 tự động
rotate_auto_ipv6 &
# Chạy hàm rotate_ipv6 để cài đặt xoay IPv6
rotate_ipv6
echo "Number of current IPv6 addresses:"
ip -6 addr | grep inet6 | wc -l
download_proxy

