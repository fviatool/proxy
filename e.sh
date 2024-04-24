#!/bin/bash

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

auth_ip() {
    echo "auth none"
    port=$START_PORT
    while read ip; do
        echo "proxy -6 -n -a -p$port -i$IP4 -e$ip"
        ((port+=1))
    done < $WORKDIR/ipv6.txt
}

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

download_proxy() {
    cd /home/cloudfly || return
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
"flush\n"}' ${WORKDATA})
EOF
}

gen_proxy_file_for_user() {
    cat >proxy.txt <<EOF
$(awk -F "/" '{print $3 ":" $4 ":" $1 ":" $2 }' ${WORKDATA})
EOF
}

gen_data() {
    seq $FIRST_PORT $LAST_PORT | while read port; do
        echo "//$IP4/$port/$(gen64 $IP6)"
    done
}

gen_iptables() {
    cat <<EOF
$(awk -F "/" '{print "iptables -I INPUT -p tcp --dport " $4 "  -m state --state NEW -j ACCEPT"}' ${WORKDATA}) 
EOF
}

gen_ifconfig() {
    cat <<EOF
$(awk -F "/" '{print "ifconfig eth0 inet6 add " $5 "/64"}' ${WORKDATA})
EOF
}

rotate_proxy_script() {
    cat <<EOF
#!/bin/bash
WORKDIR="/home/cloudfly"  # Update with your actual working directory
IP4=\$(curl -4 -s icanhazip.com)
while :; do
    for ((i = $FIRST_PORT; i < $LAST_PORT; i++)); do
        IPV6=\$(head -n \$i \$WORKDIR/ipv6.txt | tail -n 1)
        /usr/local/etc/3proxy/bin/3proxy /usr/local/etc/3proxy/3proxy.cfg -sstop
        /usr/local/etc/3proxy/bin/3proxy /usr/local/etc/3proxy/3proxy.cfg -h\$IP4 -e\$IPV6 -p\$i
    done
    sleep 300  # Sleep for 5 minutes before rotating again

    # Update IPv6 every 5 minutes
    sleep 300
    echo "Fetching new IPv6 addresses..."
    IP6=\$(curl -6 -s icanhazip.com | cut -f1-4 -d':')
    echo "New IPv6: \$IP6"
    gen_data > ${WORKDIR}/data.txt
    gen_ifconfig > ${WORKDIR}/boot_ifconfig.sh
    /usr/local/etc/3proxy/bin/3proxy /usr/local/etc/3proxy/3proxy.cfg -sstop
    /usr/local/etc/3proxy/bin/3proxy /usr/local/etc/3proxy/3proxy.cfg
done
EOF
}

echo "Installing necessary packages..."
sudo apt update
sudo apt install -y wget gcc net-tools bsdtar zip

echo "Installing 3proxy..."
install_3proxy

echo "Creating working directory..."
WORKDIR="/home/cloudfly"
WORKDATA="${WORKDIR}/data.txt"
mkdir -p $WORKDIR && cd $WORKDIR || exit 1

echo "Fetching IP addresses..."
IP4=$(curl -4 -s icanhazip.com)
IP6=$(curl -6 -s icanhazip.com | cut -f1-4 -d':')

echo "Internal IP = ${IP4}. External IP for IPv6 = ${IP6}"

echo "Generating proxy data..."
while :; do
  FIRST_PORT=$(($(od -An -N2 -i /dev/urandom) % 80001 + 10000))
  if [[ $FIRST_PORT =~ ^[0-9]+$ ]] && ((FIRST_PORT >= 10000 && FIRST_PORT <= 80000)); then
    echo "OK! Random port generated."
    LAST_PORT=$((FIRST_PORT + 999))
    echo "Random port range is $LAST_PORT. Continuing..."
    break
  else
    echo "Setting up proxy..."
  fi
done

gen_data > ${WORKDIR}/data.txt
gen_iptables > ${WORKDIR}/boot_iptables.sh
gen_ifconfig > ${WORKDIR}/boot_ifconfig.sh
rotate_proxy_script > ${WORKDIR}/rotate_3proxy.sh
chmod +x ${WORKDIR}/boot_*.sh /etc/rc.local /usr/local/etc/3proxy/rotate_3proxy.sh
gen_3proxy > /usr/local/etc/3proxy/3proxy.cfg

echo "Configuring proxy settings..."
sudo bash -c 'cat >>/etc/rc.local <<EOF
bash ${WORKDIR}/boot_iptables.sh
bash ${WORKDIR}/boot_ifconfig.sh
ulimit -n 10048
/usr/local/etc/3proxy/bin/3proxy /usr/local/etc/3proxy/3proxy.cfg
EOF'


sudo bash /etc/rc.local

echo "Generating proxy file for users..."
gen_proxy_file_for_user

echo "Starting 3proxy service..."
sudo systemctl start 3proxy

echo “Downloading proxy…”
download_proxy
