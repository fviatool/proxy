#!/bin/bash

random_password() {
	tr </dev/urandom -dc 'A-Za-z0-9!@#$%^&*()_+' | head -c16
	echo
}

# Function to install 3proxy
install_3proxy() {
    URL="https://github.com/3proxy/3proxy/archive/refs/tags/0.9.4.tar.gz"
    wget -qO- "$URL" | bsdtar -xvf-
    cd 3proxy-0.9.4 || exit
    make -f Makefile.Linux
    mkdir -p /usr/local/etc/3proxy/{bin,stat}
    cp bin/3proxy /usr/local/etc/3proxy/bin/
    cp ../init.d/3proxy.sh /etc/init.d/3proxy
    chmod +x /etc/init.d/3proxy
    chkconfig 3proxy on
    cd "$WORKDIR" || exit
}

# Function to generate 3proxy configuration
gen_3proxy_config() {
    cat <<EOF
daemon
timeouts 1 5 30 60 180 1800 15 60
flush
log /dev/null

users $(awk -F "/" 'BEGIN{ORS="";} {print $1 ":CL:" $2 " "}' "${WORKDATA}")

$(awk -F "/" '{print "auth strong cache\n" \
"allow "$1"\n" \
"socks -n -a -s0 -64 -olSO_REUSEADDR,SO_REUSEPORT -ocTCP_TIMESTAMPS,TCP_NODELAY -osTCP_NODELAY -p"$4" -i"$3" -e"$5"\n" \
"flush\n"}' "${WORKDATA}")
EOF
}

# Function to generate proxy file for user
gen_proxy_file_for_user() {
    cat >proxy.txt <<EOF
$(awk -F "/" '{print $3":"$4":"$1":"$2}' "${WORKDATA}")
EOF
}

# Function to upload proxy file
upload_proxy() {
    URL=$(curl -s --upload-file proxy.txt https://transfer.sh/proxy.txt)
    echo "Proxy is ready! Format IP:PORT:LOGIN:PASS"
    echo "Download zip archive from: ${URL}"
}

# Function to setup IPv6
setup_ipv6() {
    echo "Your IPv6 subnet:"
    read -r IPv6
    IP6="${IPv6}"

    echo "IPv6 setup complete."
}

# Function to setup firewall
setup_firewall() {
    sudo iptables -A INPUT -p icmp --icmp-type echo-request -j REJECT
    sudo iptables -A INPUT -p tcp --dport 22 -j REJECT
    echo "Firewall setup complete."
}

# Function to setup system limits
setup_limits() {
    sudo printf "fs.file-max = 500000" >> /etc/sysctl.conf 
    sudo printf "hard nofile 500000\n* soft nofile 500000\nroot hard nofile 500000\nroot soft nofile 500000\n* soft nproc 4000\n* hard nproc 16000\nroot - memlock unlimited\nnet.ipv4.tcp_fin_timeout = 10\nnet.ipv4.tcp_max_syn_backlog = 4096\nnet.ipv4,tcp_synack_retries = 3\nnet.ipv4.tcp_syncookies = 1\nnet.ipv4.tcp_max_syn_backlog = 2048\nnet.ipv4.tcp_synack_retries = 3" >> /etc/security/limits.conf
    sudo printf "DefaultLimitDATA=infinity\nDefaultLimitSTACK=infinity\nDefaultLimitCORE=infinity\nDefaultLimitRSS=infinity\nDefaultLimitNOFILE=102400\nDefaultLimitAS=infinity\nDefaultLimitNPROC=10240\nDefaultLimitMEMLOCK=infinity" >> /etc/systemd/system.conf
    sudo printf "DefaultLimitDATA=infinity\nDefaultLimitSTACK=infinity\nDefaultLimitCORE=infinity\nDefaultLimitRSS=infinity\nDefaultLimitNOFILE=102400\nDefaultLimitAS=infinity\nDefaultLimitNPROC=10240\nDefaultLimitMEMLOCK=infinity" >> /etc/systemd/user.conf
    echo "System limits setup complete."
}

# Install necessary packages
sudo apt install gcc net-tools bsdtar zip -y >/dev/null

# Set up working directory and data file
WORKDIR="/home/proxy-installer"
WORKDATA="${WORKDIR}/data.txt"
mkdir -p "$WORKDIR" && cd "$_" || exit

# Prompt user for IPv4 and IPv6
echo "Your IPv4 address:"
read -r IPv4
echo "Your IPv6 subnet:"
read -r IPv6

# Internal IP = IPv4, External subnet for IPv6 = IPv6
IP4="${IPv4}"
IP6="${IPv6}"

# Additional setup for IPv6, firewall, and system limits
setup_ipv6
setup_firewall
setup_limits

# Start installation
install_3proxy

# Add startup commands to rc.local
cat >>/etc/rc.local <<EOF
bash ${WORKDIR}/boot_iptables.sh
service 3proxy start
EOF

# Start 3proxy and upload proxy list
sudo bash /etc/rc.local
gen_proxy_file_for_user
upload_proxy

# Log user credentials
IP=$(curl -s https://api.ipify.org)
DATE=$(date +"%d/%m/%Y - %I:%M %p")
LOG="IP: $IP | Time: $DATE\n"
echo -e "$LOG" >> /var/log/3proxy_users.log
