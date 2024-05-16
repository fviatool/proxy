#!/bin/bash

# Variables
WORKDIR="/home/cloudfly"
WORKDATA="${WORKDIR}/data.txt"
MAXCOUNT=2222
IFCFG="eth0"
FIRST_PORT=10000
LAST_PORT=10500

# Function to rotate IPv6 addresses
rotate_ipv6() {
    echo "Checking IPv6 connectivity ..."
    if ip -6 route get 2403:6a40:0:91:1111 &> /dev/null; then
        IP4=$(curl -4 -s icanhazip.com)
        IP6=$(curl -6 -s icanhazip.com | cut -f1-4 -d':')
        echo "[OK]: Connectivity verified"
        echo "IPv4: $IP4"
        echo "IPv6: $IP6"
        echo "Main interface: $IFCFG"
    else
        echo "[ERROR]: IPv6 connectivity check failed!"
        exit 1
    fi

    gen_ipv6_64
    gen_ifconfig
    service network restart
    echo "IPv6 rotated and updated."
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
        echo "$IP6:$(ip64):$(ip64):$(ip64):$(ip64):$(ip64)" >> "$WORKDIR/data.txt"
        let "count_ipv6 += 1"
    done
}

# Function to generate ifconfig commands
gen_ifconfig() {
    while read -r line; do
        echo "ifconfig $IFCFG inet6 add $line/64"
    done < "$WORKDIR/data.txt" > "$WORKDIR/boot_ifconfig.sh"
}

# Function to generate proxy file for user
gen_proxy_file_for_user() {
    cat >proxy.txt <<EOF
$(awk -F "/" '{print $3 ":" $4 ":" $1 ":" $2 }' ${WORKDATA})
EOF
}

# Function to generate data
gen_data() {
    seq $FIRST_PORT $LAST_PORT | while read port; do
        echo "//$IP4/$port/$(gen64 $IP6)"
    done
}

# Function to generate iptables rules
gen_iptables() {
    cat <<EOF
$(awk -F "/" '{print "iptables -I INPUT -p tcp --dport " $4 "  -m state --state NEW -j ACCEPT"}' ${WORKDATA}) 
EOF
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
"flush\n"}' ${WORKDATA})
EOF
}

# Function to download proxy file
download_proxy() {
    cd /home/cloudfly || return
    curl -F "file=@proxy.txt" https://file.io
}

# Installation steps
echo "Installing necessary packages..."
yum -y install wget gcc net-tools bsdtar zip >/dev/null

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

# Creating working directory
mkdir -p $WORKDIR && cd $WORKDIR

# Get external IPs
IP4=$(curl -4 -s icanhazip.com)
IP6=$(curl -6 -s icanhazip.com | cut -f1-4 -d':')

echo "Internal IP = ${IP4}, External sub for IPv6 = ${IP6}"

# Generate data
gen_data > $WORKDIR/data.txt

# Generate and apply iptables rules
gen_iptables > $WORKDIR/boot_iptables.sh
chmod +x $WORKDIR/boot_iptables.sh

# Generate and apply ifconfig commands
gen_ifconfig > $WORKDIR/boot_ifconfig.sh
chmod +x $WORKDIR/boot_ifconfig.sh

# Generate 3proxy configuration
gen_3proxy > /usr/local/etc/3proxy/3proxy.cfg

# Update /etc/rc.local to start on boot
cat <<EOF >> /etc/rc.local
bash ${WORKDIR}/boot_iptables.sh
bash ${WORKDIR}/boot_ifconfig.sh
ulimit -n 10048
/usr/local/etc/3proxy/bin/3proxy /usr/local/etc/3proxy/3proxy.cfg
EOF
chmod +x /etc/rc.local

# Start 3proxy
bash /etc/rc.local

# Generate proxy file for user
gen_proxy_file_for_user

# Download proxy file
download_proxy

# Clean up
rm -rf /root/3proxy-3proxy-0.8.6

echo "Starting Proxy"

# Function to rotate IPv6 addresses automatically every 10 minutes
rotate_auto_ipv6() {
    while true; do
        rotate_ipv6
        sleep 600  # Wait for 10 minutes
    done
}
echo "Xoay Proxy 10p"

echo "Starting Proxy"
echo "Number of current IPv6 addresses:"
ip -6 addr | grep inet6 | wc -l

rotate_auto_ipv6
download_proxy
# Rotate IPv6
rotate_ipv6
