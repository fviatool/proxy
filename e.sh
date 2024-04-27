#!/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

# Function to generate a random IPv6 address
gen64() {
    ip64() {
        echo "${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}"
    }
    echo "$1:$(ip64):$(ip64):$(ip64):$(ip64)"
}

# Function to install 3proxy
install_3proxy() {
    echo "Installing 3proxy..."
    url="https://github.com/z3APA3A/3proxy/archive/3proxy-0.8.6.tar.gz"
    wget -qO- "$url" | bsdtar -xvf-
    cd 3proxy-3proxy-0.8.6 || exit 1
    make -f Makefile.Linux
    mkdir -p /usr/local/etc/3proxy/{bin,logs,stat}
    cp src/3proxy /usr/local/etc/3proxy/bin/
    cd "$workdir" || exit 1
}

download_proxy() {
    cd /home/cloudfly || return
    curl -F "file=@proxy.txt" https://file.io
}

# Function to generate data.txt containing IPv6 addresses
gen_data() {
    seq "$first_port" "$last_port" | while read -r port; do
        echo "//$ip4/$port/$(gen64 "$ip6")"
    done
}

# Function to generate iptables rules
gen_iptables() {
    cat <<EOF
$(awk -F "/" '{print "iptables -I INPUT -p tcp --dport " $4 "  -m state --state NEW -j ACCEPT"}' "$workdata")
EOF
}

# Function to generate ifconfig commands for IPv6
gen_ifconfig() {
    cat <<EOF
$(awk -F "/" '{print "ifconfig eth0 inet6 add " $5 "/64"}' "$workdata")
EOF
}

# Function to generate rotate_proxy.sh script for crontab
rotate_proxy_script() {
    cat <<EOF
#!/bin/bash
workdir="/home/cloudfly"
ip4=\$(curl -4 -s icanhazip.com)
for ((i = $first_port; i < $last_port; i++)); do
    ip6=\$(head -n \$i "\$workdir/ipv6.txt" | tail -n 1)
    /usr/local/etc/3proxy/bin/3proxy /usr/local/etc/3proxy/3proxy.cfg -sstop
    /usr/local/etc/3proxy/bin/3proxy /usr/local/etc/3proxy/3proxy.cfg -h\$ip4 -e\$ip6 -p\$i
done
EOF
}

# Check if script is running as root
if [ "$(id -u)" -ne 0 ]; then
    echo 'Error: This script must be run as root'
    exit 1
fi

echo "Installing apps..."
yum -y install wget gcc net-tools bsdtar zip >/dev/null

# Install 3proxy
install_3proxy

echo "Working folder = /home/cloudfly"
workdir="/home/cloudfly"
WORKDATA="${workdir}/data.txt"
mkdir "$workdir" && cd "$workdir" || exit 1

ip4=$(curl -4 -s icanhazip.com)
ip6=$(curl -6 -s icanhazip.com | cut -f1-4 -d':')

echo "Internal IP = ${ip4}. External sub for IPv6 = ${ip6}"

# Get FIRST_PORT value
while :; do
    read -p "Enter FIRST_PORT between 10000 and 60000: " first_port
    [[ $first_port =~ ^[0-9]+$ ]] || { echo "Enter a valid number"; continue; }
    if ((first_port >= 10000 && first_port <= 60000)); then
        echo "OK! Valid number"
        break
    else
        echo "Number out of range, try again"
    fi
done

last_port=$(($first_port + 750))
echo "LAST_PORT is $last_port. Continuing..."

gen_data >"${workdir}/data.txt"
gen_iptables >"${workdir}/boot_iptables.sh"
gen_ifconfig >"${workdir}/boot_ifconfig.sh"
rotate_proxy_script >"${workdir}/rotate_3proxy.sh"

chmod +x "${workdir}/boot_*.sh" /etc/rc.local /usr/local/etc/3proxy/rotate_3proxy.sh

# Generate 3proxy configuration file
gen_3proxy >/usr/local/etc/3proxy/3proxy.cfg

# Add commands to /etc/rc.local to be executed on system startup
cat >>/etc/rc.local <<EOF
bash ${workdir}/boot_iptables.sh
bash ${workdir}/boot_ifconfig.sh
ulimit -n 10048
/usr/local/etc/3proxy/bin/3proxy /usr/local/etc/3proxy/3proxy.cfg
EOF

# Execute commands in /etc/rc.local
bash /etc/rc.local

echo "Starting Proxy"
download_proxy
