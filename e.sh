#!/bin/bash

WORKDIR="/home/cloudfly"  # Thay đổi đường dẫn thư mục làm việc tùy thích
FIRST_PORT=10000  # Cổng bắt đầu cho các proxy
MAXCOUNT=3000  # Số lượng proxy cần tạo

# Hàm tạo địa chỉ IPv6 ngẫu nhiên
gen_ipv6() {
    rm $WORKDIR/ipv6.txt
    count_ipv6=1
    while [ "$count_ipv6" -le $MAXCOUNT ]; do
        ipv6=$(printf "%04x:%04x:%04x:%04x:%04x:%04x:%04x:%04x" \
                $((RANDOM % 65535)) $((RANDOM % 65535)) $((RANDOM % 65535)) $((RANDOM % 65535)) \
                $((RANDOM % 65535)) $((RANDOM % 65535)) $((RANDOM % 65535)) $((RANDOM % 65535)))
        echo "$ipv6" >> $WORKDIR/ipv6.txt
        let "count_ipv6 += 1"
    done
}

# Hàm tạo cấu hình cho 3proxy
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

$(awk '{print "proxy -6 -n -a -p" $1 " -i" $2 " -e" $3}' $WORKDIR/ports_ipv6.txt)
EOF
}

# Hàm tạo danh sách cổng và địa chỉ IPv6 tương ứng
gen_ports_ipv6() {
    seq $FIRST_PORT $(($FIRST_PORT + $MAXCOUNT - 1)) | \
    paste -d' ' - $WORKDIR/ipv6.txt > $WORKDIR/ports_ipv6.txt
}

# Kiểm tra nếu script chạy với quyền root
if [ "$(id -u)" != '0' ]; then
    echo 'Error: This script must be run as root' >&2
    exit 1
fi

# Tạo thư mục làm việc
mkdir -p $WORKDIR && cd $WORKDIR || exit 1

# Cài đặt các gói cần thiết
echo "Installing required packages..."
yum -y install wget gcc net-tools bsdtar zip >/dev/null || { echo "Error: Failed to install required packages" >&2; exit 1; }
echo "Packages installed successfully"

# Tạo danh sách địa chỉ IPv6 ngẫu nhiên
echo "Generating random IPv6 addresses..."
gen_ipv6 || { echo "Error: Failed to generate random IPv6 addresses" >&2; exit 1; }
echo "IPv6 addresses generated successfully"

# Tạo danh sách cổng và địa chỉ IPv6 tương ứng
echo "Generating ports and IPv6 addresses..."
gen_ports_ipv6 || { echo "Error: Failed to generate ports and IPv6 addresses" >&2; exit 1; }
echo "Ports and IPv6 addresses generated successfully"

# Cài đặt 3proxy
echo "Installing 3proxy..."
URL="https://github.com/z3APA3A/3proxy/archive/3proxy-0.8.6.tar.gz"
wget -qO- $URL | bsdtar -xvf- || { echo "Error: Failed to download and extract 3proxy" >&2; exit 1; }
cd 3proxy-3proxy-0.8.6 || { echo "Error: 3proxy directory not found" >&2; exit 1; }
make -f Makefile.Linux || { echo "Error: Failed to make 3proxy" >&2; exit 1; }
mkdir -p /usr/local/etc/3proxy/{bin,logs,stat}
cp src/3proxy /usr/local/etc/3proxy/bin/ || { echo "Error: Failed to copy 3proxy binary" >&2; exit 1; }
cd $WORKDIR || { echo "Error: Failed to change directory to $WORKDIR" >&2; exit 1; }
echo "3proxy installed successfully"

# Tạo cấu hình cho 3proxy
echo "Generating 3proxy configuration..."
gen_3proxy_cfg > /usr/local/etc/3proxy/3proxy.cfg || { echo "Error: Failed to generate 3proxy configuration" >&2; exit 1; }
echo "3proxy configuration generated successfully"

# Khởi động 3proxy
echo "Starting 3proxy..."
/usr/local/etc/3proxy/bin/3proxy /usr/local/etc/3proxy/3proxy.cfg || { echo "Error: Failed to start 3proxy" >&2; exit 1; }
echo "3proxy started successfully"
