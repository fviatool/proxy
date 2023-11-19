#!/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

random() {
    tr </dev/urandom -dc A-Za-z0-9 | head -c5
    echo
}

array=("1" "2" "3" "4" "5" "6" "7" "8" "9" "0" "a" "b" "c" "d" "e" "f")

gen64() {
    ip64() {
        echo "${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}"
    }
    echo "$1:$(ip64):$(ip64):$(ip64):$(ip64)"
}

auth_ip() {
    echo "auth none"
    port=$START_PORT
    while read ip; do
        echo "proxy -6 -n -a -p$port -i$IP4 -e$ip"
        ((port+=1))
    done < "$WORKDIR/ipv6.txt"
}

install_3proxy() {
    echo "Installing 3proxy"
    URL="https://github.com/z3APA3A/3proxy/archive/3proxy-0.8.6.tar.gz"
    wget -qO- "$URL" | bsdtar -xvf-
    cd 3proxy-3proxy-0.8.6 || exit 1
    make -f Makefile.Linux
    mkdir -p /usr/local/etc/3proxy/{bin,logs,stat}
    cp src/3proxy /usr/local/etc/3proxy/bin/
    cd "$WORKDIR" || exit 1
}

download_proxy() {
    cd /home/cloudfly || exit 1
    curl -F "file=@proxy.txt" https://transfer.sh
}

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
"$(auth_ip)\n" \
"flush\n"}' "${WORKDATA}")
EOF
}

gen_proxy_file_for_user() {
    cat >proxy.txt <<EOF
$(awk -F "/" '{print $3 ":" $4 ":" $1 ":" $2 }' "${WORKDATA}")
EOF
}

gen_data() {
    seq "$FIRST_PORT" "$LAST_PORT" | while read -r port; do
        echo "//$IP4/$port/$(gen64 $IP6)"
    done
}

gen_iptables() {
    awk -F "/" '{print "iptables -I INPUT -p tcp --dport " $4 "  -m state --state NEW -j ACCEPT"}' "${WORKDATA}"
}

gen_ifconfig() {
    awk -F "/" '{print "ifconfig eth0 inet6 add " $5 "/64"}' "${WORKDATA}"
}

rotate_proxy_script() {
    cat <<EOF
#!/bin/bash
WORKDIR="/home/cloudfly"  # Update with your actual working directory
IP4=\$(curl -4 -s icanhazip.com)
for ((i = $FIRST_PORT; i < $LAST_PORT; i++)); do
    IPV6=\$(head -n \$i \$WORKDIR/ipv6.txt | tail -n 1)
    /usr/local/etc/3proxy/bin/3proxy /usr/local/etc/3proxy/3proxy.cfg -sstop
    /usr/local/etc/3proxy/bin/3proxy /usr/local/etc/3proxy/3proxy.cfg -h\$IP4 -e\$IPV6 -p\$i
done
EOF
}

# Automatically rotate proxy every 10 minutes
(crontab -l ; echo "*/10 * * * * ${WORKDIR}/rotate_3proxy.sh") | crontab -

echo "Installing apps"
yum -y install wget gcc net-tools bsdtar zip >/dev/null

install_3proxy

ALLOWED_IPS=("113.176.102.183" "115.75.249.144")

echo "allow ${ALLOWED_IPS[@]}" >> /usr/local/etc/3proxy/3proxy.cfg

echo "Working folder = /home/cloudfly"
WORKDIR="/home/cloudfly"
WORKDATA="${WORKDIR}/data.txt"
mkdir -p "$WORKDIR" && cd "$_" || exit 1

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

LAST_PORT=$(($FIRST_PORT + 750))
echo "LAST_PORT is $LAST_PORT. Continue..."

gen_data >"${WORKDIR}/data.txt"
gen_iptables >"${WORKDIR}/boot_iptables.sh"
gen_ifconfig >"${WORKDIR}/boot_ifconfig.sh"
rotate_proxy_script >"${WORKDIR}/rotate_3proxy.sh"

chmod +x "${WORKDIR}/boot_*.sh" /etc/rc.local /usr/local/etc/3proxy/rotate_3proxy.sh

gen_3proxy > /usr/local/etc/3proxy/3proxy.cfg

cat >> /etc/rc.local <<EOF
bash ${WORKDIR}/boot_iptables.sh
bash ${WORKDIR}/boot_ifconfig.sh
ulimit -n 10048
/usr/local/etc/3proxy/bin/3proxy /usr/local/etc/3proxy/3proxy.cfg
EOF

bash /etc/rc.local

gen_proxy_file_for_user
rm -rf /root/3proxy-3proxy-0.8.6

echo "Starting Proxy"
