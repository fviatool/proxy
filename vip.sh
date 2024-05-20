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

install_3proxy() {
    echo "Installing 3proxy"
    URL="https://github.com/z3APA3A/3proxy/archive/refs/tags/0.8.13.tar.gz"
    wget -qO- $URL | tar -xzvf-
    cd 3proxy-0.8.13
    make -f Makefile.Linux
    mkdir -p /usr/local/etc/3proxy/{bin,logs,stat}
    cp src/3proxy /usr/local/etc/3proxy/bin/
    cd $WORKDIR
}

download_proxy() {
    cd /home/cloudfly || return
    curl -F "file=@proxy.txt" https://file.io
}

gen_3proxy() {
    cat <<EOF
daemon
maxconn 4000
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
$(awk -F "/" '{print "iptables -I INPUT -p tcp --dport " $4 " -m state --state NEW -j ACCEPT"}' ${WORKDATA})
EOF
}

true

rotate_ipv6() {
    while true; do
        echo "Rotating IPv6 addresses..."
        ip -6 addr flush dev eth0
        gen_ifconfig >$WORKDIR/boot_ifconfig.sh
        bash $WORKDIR/boot_ifconfig.sh
        sleep 3600
    done
}

display_menu() {
    echo "Menu:"
    echo "1. Rotate IPv6 addresses"
    echo "2. Check all IPv6 are live"
    echo "3. Download proxy"
    echo "4. Exit"
}

echo "Installing dependencies"
yum -y install wget gcc net-tools bsdtar zip curl >/dev/null

install_3proxy

echo "Setting up working directory"
WORKDIR="/home/cloudfly"
WORKDATA="${WORKDIR}/data.txt"
mkdir -p $WORKDIR && cd $WORKDIR

IP4=$(curl -4 -s icanhazip.com)
IP6=$(curl -6 -s icanhazip.com | cut -f1-4 -d':')

echo "Internal IP = ${IP4}, External sub for IPv6 = ${IP6}"

while :; do
  read -p "Enter FIRST_PORT in the range from 10000 to 20000: " FIRST_PORT
  [[ $FIRST_PORT =~ ^[0-9]+$ ]] || { echo "Please enter a valid number"; continue; }
  if ((FIRST_PORT >= 10000 && FIRST_PORT <= 20000)); then
    echo "Confirmed! Valid number"
    break
  else
    echo "Number is not in the allowed range, please try again"
  fi
done

LAST_PORT=$(($FIRST_PORT + 222))
echo "LAST_PORT is $LAST_PORT. Continuing..."

gen_data >$WORKDIR/data.txt
gen_iptables >$WORKDIR/boot_iptables.sh
gen_ifconfig >$WORKDIR/boot_ifconfig.sh
chmod +x $WORKDIR/boot_*.sh /etc/rc.local

gen_3proxy >/usr/local/etc/3proxy/3proxy.cfg

cat >>/etc/rc.local <<EOF
bash ${WORKDIR}/boot_iptables.sh
bash ${WORKDIR}/boot_ifconfig.sh
ulimit -n 10048
/usr/local/etc/3proxy/bin/3proxy /usr/local/etc/3proxy/3proxy.cfg
EOF

bash /etc/rc.local

while true; do
    display_menu
    read -p "Choose an option (1-4): " choice

    case "$choice" in
        1)
            rotate_ipv6
            ;;
        2)
            check_all_ipv6_live
            ;;
        3)
            download_proxy
            ;;
        4)
            echo "Exiting the program."
            exit 0
            ;;
        *)
            echo "Invalid choice. Please choose again."
            ;;
    esac
done
