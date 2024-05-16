#!/bin/bash

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

# Function to generate ifconfig commands and save to file
gen_ifconfig() {
    while read -r line; do
        echo "ifconfig $IFCFG inet6 add $line/64"
    done < "$WORKDATA" > "$WORKDIR/boot_ifconfig.sh"
    chmod +x "$WORKDIR/boot_ifconfig.sh"
}

# Function to generate proxy data and save to file
gen_data() {
    FIRST_PORT=10000  # Starting port
    PORT_COUNT=10  # Number of ports to create

    if ((PORT_COUNT > 0)); then
        LAST_PORT=$((FIRST_PORT + PORT_COUNT - 1))
        seq $FIRST_PORT $LAST_PORT | while read port; do
            echo "//$IP4/$port/$(gen64 $IP6)"
        done > "$WORKDIR/data.txt"
        echo "Port range created from $FIRST_PORT to $LAST_PORT."
    else
        echo "Number of ports must be greater than 0."
        exit 1
    fi
}

# Function to generate iptables rules and save to file
gen_iptables() {
    awk -F "/" '{print "iptables -I INPUT -p tcp --dport " $4 "  -m state --state NEW -j ACCEPT"}' ${WORKDATA}
}

# Function to generate proxy configuration for 3proxy and save to file
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
    awk -F "/" '{print $3 ":" $4 ":" $1 ":" $2 }' ${WORKDATA} > "$WORKDIR/proxy.txt"
}

# Function to download proxy file
download_proxy() {
    cd "$WORKDIR" || return
    curl -F "file=@proxy.txt" https://file.io
}

# Function to install 3proxy
install_3proxy() {
    URL="https://github.com/3proxy/3proxy/archive/refs/tags/0.9.4.tar.gz"
    wget -qO- $URL | bsdtar -xvf-
    cd 3proxy-0.9.4 || exit
    make -f Makefile.Linux
    mkdir -p /usr/local/etc/3proxy/{bin,stat}
    cp bin/3proxy /usr/local/etc/3proxy/bin/
    cp ../init.d/3proxy.sh /etc/init.d/3proxy
    chmod +x /etc/init.d/3proxy
    chkconfig 3proxy on
    cd "$WORKDIR" || exit
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

gen_data >"$WORKDIR/data.txt"
gen_iptables >"$WORKDIR/boot_iptables.sh"
gen_ifconfig >"$WORKDIR/boot_ifconfig.sh"
chmod +x "$WORKDIR"/boot_*.sh /etc/rc.local

gen_3proxy >"/usr/local/etc/3proxy/3proxy.cfg"

cat >>/etc/rc.local <<EOF
bash "${WORKDIR}/boot_iptables.sh"
bash "${WORKDIR}/boot_ifconfig.sh"
ulimit -n 1000048
/usr/local/etc/3proxy/bin/3proxy /usr/local/etc/3proxy/3proxy.cfg
EOF
chmod 0755 /etc/rc.local
bash /etc/rc.local

/usr/local/etc/3proxy/bin/3proxy /usr/local/etc/3proxy/3proxy.cfg &

# Generate proxy file for users
gen_proxy_file_for_user

echo "Starting Proxy, Check Proxy Live"

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
    done < /home/cloudfly/proxy.txt
}
echo "So Luong IPv6 Hien Tai:"
ip -6 addr | grep inet6 | wc -l
download_proxy
rotate_ipv6 &

# Rotate IPv6 addresses
rotate_ipv6 &
