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

install_3proxy() {
  echo "installing 3proxy"
  URL="https://github.com/z3APA3A/3proxy/archive/3proxy-0.8.6.tar.gz"
  wget -qO- $URL | bsdtar -xvf-
  cd 3proxy-3proxy-0.8.6
  make -f Makefile.Linux
  mkdir -p /usr/local/etc/3proxy/{bin,logs,stat}
  cp src/3proxy /usr/local/etc/3proxy/bin/
  cd $WORKDIR
}

download_proxy() {
    cd /home/cloudfly
    curl -F "file=@proxy.txt" https://transfer.sh
}

gen_3proxy() {
  cat <<EOF
daemon
maxconn 20000
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
auth strong

users $(awk -F "/" 'BEGIN{ORS="";} {print $1 ":CL:" $2 " "}' ${WORKDATA})

$(awk -F "/" '{print "auth strong\n" \
"allow " $1 "\n" \
"proxy -6 -n -a -p" $4 " -i" $3 " -e"$5"\n" \
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
    echo "user$port/$(random)/$IP4/$port/$(gen64 $IP6)"
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

rotate_ipv6() {
  echo "Rotating IPv6 addresses..."

  # Add your logic to obtain a new IPv6 address
  new_ipv6=$(get_new_ipv6)

  # Update 3proxy configuration with the new IPv6 address
  update_3proxy_config "$new_ipv6"

  # Your logic to restart the 3proxy service
  restart_3proxy

  echo "IPv6 rotation completed."
}

get_new_ipv6() {
  # Your logic to obtain a new IPv6 address
  # For example, generate a random IPv6 address
  random_ipv6=$(openssl rand -hex 8 | sed 's/\(..\)/:\1/g; s/://1')
  echo "$random_ipv6"
}

restart_3proxy() {
  # Your logic to restart the 3proxy service
  service 3proxy restart
}

echo "installing apps"
yum -y install gcc net-tools bsdtar zip >/dev/null

install_3proxy

echo "working folder = /home/cloudfly/"
WORKDIR="/home/cloudfly/"
WORKDATA="${WORKDIR}/data.txt"
mkdir $WORKDIR && cd $_

IP4=$(curl -4 -s icanhazip.com)
IP6=$(curl -6 -s icanhazip.com | cut -f1-4 -d':')

echo "Internal IP = ${IP4}. External subnet for IPv6 = ${IP6}"

FIRST_PORT=5001
LAST_PORT=25000

gen_data >$WORKDIR/data.txt
gen_iptables >$WORKDIR/boot_iptables.sh
gen_ifconfig >$WORKDIR/boot_ifconfig.sh
chmod +x boot_*.sh /etc/rc.local

gen_3proxy >/usr/local/etc/3proxy/3proxy.cfg

# Add rotation to rc.local
cat >>/etc/rc.local <<EOF
bash ${WORKDIR}/boot_iptables.sh
bash ${WORKDIR}/boot_ifconfig.sh
ulimit -n 10048
/usr/local/etc/3proxy/bin/3proxy /usr/local/etc/3proxy/3proxy.cfg
EOF

# Loop to rotate every 10 minutes
while true; do
  rotate_ipv6
  sleep 600  # Sleep for 10 minutes
done

# Uncomment the line below if you want to start the rotation immediately
# rotate_ipv6

gen_proxy_file_for_user
rm -rf /root/setup.sh
rm -rf /root/3proxy-3proxy-0.8.6

echo "Starting Proxy"
