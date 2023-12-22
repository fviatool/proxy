#!/bin/bash

PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

# Function to generate a random string
random() {
    tr </dev/urandom -dc A-Za-z0-9 | head -c5
    echo
}

# Array for IPv6 generation
array=(1 2 3 4 5 6 7 8 9 0 a b c d e f)

# Function to generate IPv6 address
gen64() {
    ip64() {
        echo "${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}"
    }
    echo "$1:$(ip64):$(ip64):$(ip64):$(ip64)"
}

# Function to install 3proxy
install_3proxy() {
    echo "Installing 3proxy..."
    URL="https://github.com/z3APA3A/3proxy/archive/0.8.6.tar.gz"
    wget -qO- $URL | tar -xz
    cd 3proxy-0.8.6 || exit
    make -f Makefile.Linux
    mkdir -p /usr/local/etc/3proxy/{bin,logs,stat}
    cp src/3proxy /usr/local/etc/3proxy/bin/
    cd ..
    rm -rf 3proxy-0.8.6
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

# Function to generate IPv6 data
gen_data() {
    seq "$FIRST_PORT" "$LAST_PORT" | while read -r port; do
        echo "$(gen64 $IP6)"
    done
}

# Function to generate iptables rules
gen_iptables() {
    awk -F "/" '{print "iptables -I INPUT -p tcp --dport " $4 "  -m state --state NEW -j ACCEPT"}' "${WORKDATA}"
}

# Function to generate ifconfig commands
gen_ifconfig() {
    awk -F "/" '{print "ifconfig eth0 inet6 add " $5 "/64"}' "${WORKDATA}"
}

# Set working directory
WORKDIR="/root/proxy"
WORKDATA="${WORKDIR}/ipv6.txt"

echo "Installing required packages..."
yum -y install wget gcc net-tools bsdtar zip >/dev/null

install_3proxy

IP4=$(curl -4 -s icanhazip.com)
IP6=$(curl -6 -s icanhazip.com | cut -f1-4 -d':')

echo "Internal IP: ${IP4}. External sub for IPv6: ${IP6}"

# Prompt for FIRST_PORT
while :; do
    read -p "Enter FIRST_PORT between 10000 and 60000: " FIRST_PORT
    [[ $FIRST_PORT =~ ^[0-9]+$ ]] || { echo "Enter a valid number"; continue; }
    if ((FIRST_PORT >= 10000 && FIRST_PORT <= 60000)); then
        echo "OK! Valid number"
        break
    else
        echo "Number out of range, try again"
    fi
done

LAST_PORT=$((FIRST_PORT + 5555))
echo "LAST_PORT is $LAST_PORT. Continuing..."

gen_data >"${WORKDIR}/ipv6.txt"

cat << EOF > /etc/rc.d/rc.local
#!/bin/bash
touch /var/lock/subsys/local
bash ${WORKDIR}/boot_iptables.sh
bash ${WORKDIR}/boot_ifconfig.sh
ulimit -n 10048
/usr/local/etc/3proxy/bin/3proxy /usr/local/etc/3proxy/3proxy.cfg
EOF

chmod +x /etc/rc.d/rc.local

gen_3proxy >/usr/local/etc/3proxy/3proxy.cfg
gen_iptables >"${WORKDIR}/boot_iptables.sh"
gen_ifconfig >"${WORKDIR}/boot_ifconfig.sh"

echo "Starting Proxy..."
