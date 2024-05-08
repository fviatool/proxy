#!/bin/bash

random() {
    tr </dev/urandom -dc A-Za-z0-9 | head -c5
    echo
}

array=(1 2 3 4 5 6 7 8 9 0 a b c d e f)

gen64() {
    ip64() {
        echo "${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}"
    }
    echo "$1:$(ip64):$(ip64):$(ip64):$(ip64)"
}

# Hàm kiểm tra và chọn tên giao diện mạng tự động
auto_detect_interface() {
    INTERFACE=$(ip -o link show | awk -F': ' '$3 !~ /lo|vir|^[^0-9]/ {print $2; exit}')
}

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

# Clean yum cache
yum clean all

# Install necessary packages
yum -y install wget gcc net-tools bsdtar zip >/dev/null

# Install 3proxy
install_3proxy

# Set up working directory
echo "working folder = /home/cloudfly"
WORKDIR="/home/cloudfly"
WORKDATA="${WORKDIR}/data.txt"
mkdir $WORKDIR && cd $_

# Get internal and external IPs
IP4=$(curl -4 -s icanhazip.com)
IP6=$(curl -6 -s icanhazip.com | cut -f1-4 -d':')

echo "Internal ip = ${IP4}. External sub for ip6 = ${IP6}"

# Function to generate random port within range
generate_random_port() {
    local FIRST_PORT
    local LAST_PORT
    while :; do
        FIRST_PORT=$(($(od -An -N2 -i /dev/urandom) % 10000 + 20000))
        if [[ $FIRST_PORT =~ ^[0-9]+$ ]] && ((FIRST_PORT >= 10000 && FIRST_PORT <= 20000)); then
            LAST_PORT=$((FIRST_PORT + 9999))
            echo "Random port is $LAST_PORT."
            break
        fi
    done
    echo "$LAST_PORT"
}

# Generate random port range
LAST_PORT=$(generate_random_port)
echo "Port range: $FIRST_PORT - $LAST_PORT"

# Generate data, iptables, and ifconfig configurations
gen_data >$WORKDIR/data.txt
gen_iptables >$WORKDIR/boot_iptables.sh
gen_ifconfig >$WORKDIR/boot_ifconfig.sh
chmod +x boot_*.sh /etc/rc.local

# Append configurations to /etc/rc.local for startup
cat >>/etc/rc.local <<EOF
bash ${WORKDIR}/boot_iptables.sh
bash ${WORKDIR}/boot_ifconfig.sh
ulimit -n 10048
/usr/local/etc/3proxy/bin/3proxy /usr/local/etc/3proxy/3proxy.cfg
EOF

bash /etc/rc.local

# Generate proxy file for user
gen_proxy_file_for_user

# Remove temporary files
rm -rf /root/3proxy-3proxy-0.8.6

# Check IPv6 live
echo "Checking IPv6 live:"
check_ipv6_live() {
    local ipv6_address=$1
    ping6 -c 3 $ipv6_address
}

check_all_ipv6_live() {
    ip -6 addr | grep inet6 | while read -r line; do
        address=$(echo "$line" | awk '{print $2}')
        ip6=$(echo "$address" | cut -d'/' -f1)
        ping6 -c 1 $ip6 > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            ipv4_port="$IP4:$port -> "
            echo "$ipv4_port IPv6: $ip6 Live"
        else
            echo "$ip6 không phản hồi"
        fi
    done
}
check_all_ipv6_live

# Download proxy file
echo "Downloading proxy file:"
download_proxy
