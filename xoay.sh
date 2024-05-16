#!/bin/bash

# Get IPv6 address
ipv6_address=$(ip addr show eth0 | awk '/inet6/{print $2}' | grep -v '^fe80' | head -n1)

# Check if IPv6 address is obtained
if [ -n "$ipv6_address" ]; then
    echo "IPv6 address obtained: $ipv6_address"

    # Declare associative arrays to store IPv6 addresses and gateways
    declare -A ipv6_addresses=(
        [4]="2001:ee0:4f9b::$IPD:0000/64"
        [5]="2001:ee0:4f9b::$IPD:0000/64"
        [244]="2001:ee0:4f9b::$IPD:0000/64"
        ["default"]="2001:ee0:4f9b::$IPC::$IPD:0000/64"
    )

    declare -A gateways=(
        [4]="fe80::1%13:$IPC::1"
        [5]="fe80::1%13:$IPC::1"
        [244]="fe80::1%13:$IPC::1"
        ["default"]="fe80::1%13:$IPC::1"
    )

    # Get IPv4 third and fourth octets
    IPC=$(echo "$ipv6_address" | cut -d":" -f5)
    IPD=$(echo "$ipv6_address" | cut -d":" -f6)

    # Set IPv6 address and gateway based on IPv4 third octet
    IPV6_ADDRESS="${ipv6_addresses[$IPC]}"
    GATEWAY="${gateways[$IPC]}"

    # Check if interface is available
    INTERFACE=$(ip -o link show | awk -F': ' '{print $2}' | grep -v lo | head -n1)

    if [ -n "$INTERFACE" ]; then
        echo "Configuring interface: $INTERFACE"

        # Configure IPv6 settings
        echo "IPV6_ADDR_GEN_MODE=stable-privacy" >> /etc/network/interfaces
        echo "IPV6ADDR=$ipv6_address/64" >> /etc/network/interfaces
        echo "IPV6_DEFAULTGW=$GATEWAY" >> /etc/network/interfaces

        # Restart networking service
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

# Variables
WORKDIR="/home/cloudfly"
WORKDATA="${WORKDIR}/data.txt"
MAXCOUNT=2222
IFCFG="eth0"
FIRST_PORT=10000
LAST_PORT=10500

# Function to rotate IPv6 addresses
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

# Function to install 3proxy
install_3proxy() {
    cd $WORKDIR
    wget https://github.com/z3APA3A/3proxy/archive/refs/tags/0.8.6.tar.gz
    tar -xzf 0.8.6.tar.gz
    cd 3proxy-0.8.6
    make -f Makefile.Linux
    mkdir -p /usr/local/etc/3proxy/bin
    cp src/3proxy /usr/local/etc/3proxy/bin/
    cp ./scripts/rc.d/init.d/3proxy /etc/init.d/
    chkconfig --add 3proxy
}

# Function to generate IPv6 addresses
gen_ipv6_64() {
    rm "$WORKDIR/data.txt"
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

# Function to generate ifconfig commands
gen_ifconfig() {
    while read -r line; do
        echo "ifconfig $IFCFG inet6 add $line/64"
    done < "$WORKDATA" > "$WORKDIR/boot_ifconfig.sh"
    chmod +x "$WORKDIR/boot_ifconfig.sh"
}

# Function to generate 3proxy configuration
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

# Function to generate iptables rules
gen_iptables() {
    awk -F "/" '{print "iptables -I INPUT -p tcp --dport " $4 "  -m state --state NEW -j ACCEPT"}' "${WORKDATA}"
}

# Function to download proxy.txt file
download_proxy() {
    cd /home/cloudfly || return
    curl -F "file=@proxy.txt" https://file.io
}

# Installation steps
echo "Installing necessary packages..."
yum -y install wget gcc net-tools bsdtar zip >/dev/null

rm -rf /root/3proxy-3proxy-0.8.6

echo "Working folder: $WORKDIR"
mkdir -p "$WORKDIR" && cd "$WORKDIR" || exit

# Run rotate_ipv6 function to set up IPv6 rotation
rotate_ipv6

# Install 3proxy
install_3proxy

# Generate 3proxy configuration
gen_3proxy > "/usr/local/etc/3proxy/3proxy.cfg"

# Generate data for IPv6 addresses
gen_ipv6_64

# Generate ifconfig commands
gen_ifconfig

# Generate iptables rules and execute them
gen_iptables | bash

# Start 3proxy service
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
rotate_auto_ipv6() {
    while true; do
        rotate_ipv6
        sleep 600  # Đợi 10 phút
    done
}

# Khởi động xoay IPv6 tự động

rotate_auto_ipv6 &
download_proxy
