#!/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

# Function to generate a random IPv6 address
gen_ipv6() {
    hex_str=$(openssl rand -hex 16)
    ipv6=$(echo $hex_str | sed 's/\(..\)/\1:/g; s/:$//')
    echo "$ipv6"
}

# Function to generate data.txt containing IPv4 and corresponding random IPv6 addresses
gen_data() {
    for ((i = $start_port; i < $end_port; i++)); do
        ipv4="$base_ipv4.$i"
        ipv6=$(gen_ipv6)
        echo "$ipv4|$ipv6"
    done > $workdir/data.txt
}

# Function to generate 3proxy configuration
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

$(awk -F "|" '{print "auth none\n" \
"proxy -6 -n -a -p" $2 " -i" $1 " -e" $3 "\n" \
"flush\n"}' ${workdir}/data.txt)
EOF
}

# Function to install 3proxy
install_3proxy() {
    echo "Installing 3proxy..."
    wget -qO- https://github.com/z3APA3A/3proxy/archive/0.9.4.tar.gz | tar -xzvf -
    cd 3proxy-0.9.4 || exit 1
    make -f Makefile.Linux
    mkdir -p /usr/local/etc/3proxy/{bin,logs,stat}
    cp src/3proxy /usr/local/etc/3proxy/bin/
    cd "$workdir" || exit 1
}

# Check if script is running as root
if [ "$(id -u)" -ne 0 ]; then
    echo 'Error: This script must be run as root'
    exit 1
fi

echo "Installing apps..."
yum -y install wget gcc net-tools bsdtar zip >/dev/null

echo "Working folder = /home/cloudfly"
workdir="/home/cloudfly"
mkdir -p "$workdir" && cd "$workdir" || exit 1

base_ipv4="192.168.1.151"
start_port=10000
end_port=10100

echo "Installing 3proxy..."
install_3proxy

echo "Generating data..."
gen_data

echo "Data generated successfully!"

echo "Generating 3proxy configuration..."
gen_3proxy_cfg > /usr/local/etc/3proxy/3proxy.cfg

echo "Starting 3proxy..."
/usr/local/etc/3proxy/bin/3proxy /usr/local/etc/3proxy/3proxy.cfg

echo "3proxy started successfully!"
