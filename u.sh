#!/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

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

# Hàm cài đặt 3proxy
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

# Function to generate 3proxy configuration
gen_3proxy() {
    cat <<EOF
daemon
timeouts 1 5 30 60 180 1800 15 60
flush
log /dev/null

$(awk -F "/" '{print "auth none\n" \
"allow *.*.*.*\n" \
"socks -n -a -s0 -64 -olSO_REUSEADDR,SO_REUSEPORT -ocTCP_TIMESTAMPS,TCP_NODELAY -osTCP_NODELAY -p"$4" -i"$3" -e"$5"\n" \
"flush\n"}' ${WORKDATA})
EOF
}

# Function to generate proxy file for users
gen_proxy_file_for_user() {
    cat >proxy.txt <<EOF
$(awk -F "/" '{print $3":"$4}' ${WORKDATA})
EOF
}

# Function to download proxy file
download_proxy() {
    cd /home/cloudfly || return
    curl -F "file=@proxy.txt" https://file.io
}

# Function to generate data for ports
gen_data() {
    seq $FIRST_PORT $LAST_PORT $ADDITIONAL_PORT | while read port; do
        echo "$(random)/$IP4/$port/$(gen64 $IP6)"
    done
}

# Function to generate iptables rules
gen_iptables() {
    cat <<EOF
$(awk -F "/" '{print "iptables -I INPUT -p tcp --dport "$4"  -m state --state NEW -j ACCEPT"}' ${WORKDATA}) 
EOF
}

# Function to generate ifconfig commands
gen_ifconfig() {
    cat <<EOF
$(awk -F "/" '{print "ifconfig eth0 inet6 add "$5"/64"}' ${WORKDATA})
EOF
}

# Function to get public IPv4 address
get_ipv4() {
    ipv4=$(curl -4 -s icanhazip.com)
    echo "$ipv4"
}

# Install necessary packages
yum -y install gcc net-tools bsdtar zip >/dev/null

# Install 3proxy
install_3proxy

# Set working directory
WORKDIR="/home/cloudfly"
WORKDATA="${WORKDIR}/data.txt"
mkdir $WORKDIR && cd $_

# Get IPv4 address
echo "Your IPv4 address:"
IP4=$(get_ipv4)
echo "$IP4"

# Get IPv6 subnet from user input
echo "Your IPv6 subnet:"
read IPv6
IP6=${IPv6}
echo "Internal ip = ${IP4}. External sub for IPv6 = ${IP6}"

# Generate random ports
while :; do
  FIRST_PORT=$(($(od -An -N2 -i /dev/urandom) % 80001 + 10000))
  if [[ $FIRST_PORT =~ ^[0-9]+$ ]] && ((FIRST_PORT >= 10000 && FIRST_PORT <= 80000)); then
    echo "OK! Random Port Generated"
    LAST_PORT=$((FIRST_PORT + 999))
    echo "LAST_PORT is $LAST_PORT. Continuing..."
    break
  else
    echo "Creating Proxy Configuration"
  fi
done

# Generate data for ports
gen_data >$WORKDIR/data.txt
gen_iptables >$WORKDIR/boot_iptables.sh
gen_ifconfig >$WORKDIR/boot_ifconfig.sh
chmod +x ${WORKDIR}/boot_*.sh /etc/rc.local

# Generate 3proxy configuration
gen_3proxy >/usr/local/etc/3proxy/3proxy.cfg

# Update IPv6 configuration
echo "net.ipv6.conf.eth0.proxy_ndp=1" | sudo tee -a /etc/sysctl.conf
echo "net.ipv6.conf.all.proxy_ndp=1" | sudo tee -a /etc/sysctl.conf
echo "net.ipv6.conf.default.forwarding=1" | sudo tee -a /etc/sysctl.conf
echo "net.ipv6.conf.all.forwarding=1" | sudo tee -a /etc/sysctl.conf
echo "net.ipv6.ip_nonlocal_bind=1" | sudo tee -a /etc/sysctl.conf
echo "vm.max_map_count=95120" | sudo tee -a /etc/sysctl.conf
echo "kernel.pid_max=95120" | sudo tee -a /etc/sysctl.conf
echo "net.ipv4.ip_local_port_range=1024 65000" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# Set permissions for 3proxy
chmod -R 777 /usr/local/etc/3proxy/

# Configure startup scripts
cat >>/etc/rc.local <<EOF
bash ${WORKDIR}/boot_iptables.sh
bash ${WORKDIR}/boot_ifconfig.sh
ulimit -n 999999
service 3proxy start
EOF

# Start services
bash /etc/rc.local

# Generate proxy file for users
gen_proxy_file_for_user

# Download proxy file
download_proxy
