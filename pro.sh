#!/bin/bash

WORKDIR="/home/cloudfly"
MAXCOUNT=2222
IFCFG="eth0"
START_PORT=10000
END_PORT=15000

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

# Function to generate proxy.txt file for users
gen_proxy_file_for_user() {
    cat >proxy.txt <<EOF
$(awk -F "/" '{print $3 ":" $4 ":" $1 ":" $2 }' ${WORKDATA})
EOF
}

# Function to generate data.txt containing IPv6 addresses
gen_data() {
    seq $FIRST_PORT $LAST_PORT | while read port; do
        echo "//$IP4/$port/$(gen64 $IP6)"
    done
}

# Function to generate iptables commands
gen_iptables() {
    cat <<EOF
$(awk -F "/" '{print "iptables -I INPUT -p tcp --dport " $4 "  -m state --state NEW -j ACCEPT"}' ${WORKDATA}) 
EOF
}

# Main script starts here
cat << EOF > /etc/rc.d/rc.local
#!/bin/bash
touch /var/lock/subsys/local
EOF

echo "installing apps"
yum -y install wget gcc net-tools bsdtar zip >/dev/null

echo "working folder = /home/cloudfly"
WORKDIR="/home/cloudfly"
WORKDATA="${WORKDIR}/data.txt"
mkdir $WORKDIR && cd $_

IP4=$(curl -4 -s icanhazip.com)
IP6=$(curl -6 -s icanhazip.com | cut -f1-4 -d':')

echo "Internal ip = ${IP4}. Exteranl sub for ip6 = ${IP6}"

# Initialize the first and last port
FIRST_PORT=10000
LAST_PORT=15000

# Loop through each port and set up
while [[ $FIRST_PORT -le $LAST_PORT ]]; do
    echo "Current Port: $FIRST_PORT"
    # Perform configuration operations with the current port here
    # Example: iptables -I INPUT -p tcp --dport $FIRST_PORT -m state --state NEW -j ACCEPT

    # Increase the port value for the next iteration
    ((FIRST_PORT++))
done

echo "Port setup complete."

# Rotate IPv6 addresses
gen_ipv6_64
gen_ifconfig
bash "$WORKDIR/boot_ifconfig.sh"
service network restart

# Generate data for 3proxy configuration
gen_data >$WORKDIR/data.txt

# Generate iptables rules and ifconfig commands
gen_iptables >$WORKDIR/boot_iptables.sh
gen_ifconfig >$WORKDIR/boot_ifconfig.sh

# Change permissions and execute scripts
chmod +x ${WORKDIR}/boot_*.sh /etc/rc.local

# Generate 3proxy configuration file
gen_3proxy >/usr/local/etc/3proxy/3proxy.cfg

# Add commands to rc.local for boot time execution
cat >>/etc/rc.local <<EOF
bash ${WORKDIR}/boot_iptables.sh
bash ${WORKDIR}/boot_ifconfig.sh
ulimit -n 10048
/usr/local/etc/3proxy/bin/3proxy /usr/local/etc/3proxy/3proxy.cfg
EOF

bash /etc/rc.local

# Generate proxy file for users and remove unnecessary files
gen_proxy_file_for_user
rm -rf /root/3proxy-3proxy-0.8.6

echo "Starting Proxy"
echo "Current number of IPv6 addresses:"
ip -6 addr | grep inet6 | wc -l

# Download proxy.txt file
download_proxy
