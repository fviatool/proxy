#!/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

# Function to generate a random string
random() {
    tr </dev/urandom -dc A-Za-z0-9 | head -c5
    echo
}

# Function to generate a random IPv6 address segment
ip64() {
    echo "${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}"
}

# Function to generate a full IPv6 address
gen64() {
    echo "$1:$(ip64):$(ip64):$(ip64):$(ip64)"
}

# Function to auto-detect the network interface
auto_detect_interface() {
    INTERFACE=$(ip -o link show | awk -F': ' '$3 !~ /lo|vir|^[^0-9]/ {print $2; exit}')
}

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
        sleep 300  # Wait for 5 minutes before updating again
    done
}

# Function to generate IPv6 addresses and save to file
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

# Function to generate ifconfig commands and save to file
gen_ifconfig() {
    while read -r line; do
        echo "ifconfig $IFCFG inet6 add $line/64"
    done < "$WORKDATA" > "$WORKDIR/boot_ifconfig.sh"
    chmod +x "$WORKDIR/boot_ifconfig.sh"
}

# Function to generate 3proxy configuration and save to file
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
"flush\n"}' ${WORKDATA})
EOF
}

# Function to generate proxy file for users
gen_proxy_file_for_user() {
    awk -F "/" '{print $3 ":" $4 ":" $1 ":" $2 }' ${WORKDATA} > proxy.txt
}

# Function to download proxy file
download_proxy() {
    cd /home/cloudfly || return
    curl -F "file=@proxy.txt" https://file.io
}

# Function to install 3proxy
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

# Setting environment variables
WORKDIR="/home/cloudfly"
WORKDATA="${WORKDIR}/data.txt"
MAXCOUNT=2222
IFCFG="eth0"

# Install necessary packages
echo "Installing necessary packages..."
yum -y install wget gcc net-tools bsdtar zip >/dev/null

# Remove existing 3proxy installation
rm -rf /root/3proxy-0.9.4

echo "Working folder: $WORKDIR"
mkdir -p "$WORKDIR" && cd "$WORKDIR" || exit

# Install 3proxy
install_3proxy

# Generate 3proxy configuration
gen_3proxy > "/usr/local/etc/3proxy/3proxy.cfg"
ulimit -n 10048

# Start 3proxy
/usr/local/etc/3proxy/bin/3proxy /usr/local/etc/3proxy/3proxy.cfg &

# Generate IPv6 data
gen_ipv6_64

# Generate ifconfig commands
gen_ifconfig

# Generate iptables rules and apply them
gen_iptables | bash

echo "Starting Proxy"
echo "Number of current IPv6 addresses:"
ip -6 addr | grep inet6 | wc -l
download_proxy

echo "3proxy auto rotation enabled..."

# Start automatic IPv6 rotation
rotate_ipv6 &

check_ipv6_live() {
    local ipv6_address=$1
    ping6 -c 3 $ipv6_address
}

# Sử dụng hàm để kiểm tra tính sống của một địa chỉ IPv6 cụ thể
check_all_ipv6_live() {
    ip -6 addr | grep inet6 | while read -r line; do
        address=$(echo "$line" | awk '{print $2}')
        ip6=$(echo "$address" | cut -d'/' -f1)
        ping6 -c 1 $ip6 > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            echo "$ip6 is live"
        else
            echo "$ip6 is not live"
        fi
    done
}
check_all_ips
check_all_ipv6_live

check_all_ips() {
    while IFS= read -r line; do
        ipv6=$(echo "$line" | cut -d '/' -f 5)
        echo "Kiểm tra IPv6: $ipv6"
        ping6 -c 3 $ipv6
        echo "-----------------------------------"
    done < /home/cloudfly/data.txt
}
