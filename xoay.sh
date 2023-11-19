#!/bin/bash

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

install_3proxy() {
    echo "Installing 3proxy"
    URL="https://github.com/z3APA3A/3proxy/archive/3proxy-0.8.6.tar.gz"
    wget -qO- $URL | bsdtar -xvf-
    cd 3proxy-3proxy-0.8.6 || exit 1
    make -f Makefile.Linux
    mkdir -p /usr/local/etc/3proxy/{bin,logs,stat}
    cp src/3proxy /usr/local/etc/3proxy/bin/
    cd $WORKDIR || exit 1
}

download_proxy() {
    cd /home/cloudfly
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
auth strong

users $(awk -F "/" 'BEGIN{ORS="";} {print $1 ":CL:" $2 " "}' ${WORKDATA})

$(awk -F "/" '{print "auth strong\n" \
"allow " $1 "\n" \
"proxy -6 -n -a -p" $4 " -i" $3 " -e"$5"\n" \
"flush\n"}' ${WORKDATA})
EOF
}

gen_proxy_file_for_user() {
    awk -F "/" '{print $3 ":" $4 ":" $1 ":" $2 }' ${WORKDATA} > proxy.txt
}

gen_data() {
    userproxy=$(random)
    passproxy=$(random)
    seq $FIRST_PORT $LAST_PORT | while read port; do
        echo "$userproxy/$passproxy/$IP4/$port/$(gen64 $IP6)"
    done
}

gen_iptables() {
    awk -F "/" '{print "iptables -I INPUT -p tcp --dport " $4 "  -m state --state NEW -j ACCEPT"}' ${WORKDATA}
}

gen_ifconfig() {
    awk -F "/" '{print "ifconfig eth0 inet6 add " $5 "/64"}' ${WORKDATA}
}

rotate_proxies() {
    while true; do
        sleep 600  # Sleep for 10 minutes
        echo "Rotating proxies..."
        gen_data >$WORKDIR/data.txt
        gen_3proxy >/usr/local/etc/3proxy/3proxy.cfg
        echo "Proxies rotated."
    done
}

rotate_and_restart() {
    while true; do
        for ((i = $FIRST_PORT; i < $LAST_PORT; i++)); do
            IPV6=$(head -n $i $WORKDIR/ipv6.txt | tail -n 1)
            /usr/local/etc/3proxy/bin/3proxy /usr/local/etc/3proxy/3proxy.cfg -sstop
            /usr/local/etc/3proxy/bin/3proxy /usr/local/etc/3proxy/3proxy.cfg -h$IP4 -e$IPV6 -p$i
        done
        sleep 900  # Sleep for 15 minutes (900 seconds)
    done
}

show_proxy_list() {
    echo "Proxy List:"
    cat proxy.txt
}

menu() {
    clear
    echo "Menu:"
    echo "1. Create proxy and download"
    echo "2. Rotate proxies"
    echo "3. Show proxy list"
    echo "4. Download proxy list"
    echo "5. Exit"
}

while true; do
    menu
    read -p "Choose an option (1-5): " choice

    case $choice in
        1)
            gen_data >$WORKDIR/data.txt
            gen_3proxy >/usr/local/etc/3proxy/3proxy.cfg
            echo "Proxy created."
            download_proxy
            ;;
        2)
            rotate_proxies
            ;;
        3)
            show_proxy_list
            ;;
        4)
            download_proxy
            ;;
        5)
            echo "Exiting..."
            exit 0
            ;;
        *)
            echo "Invalid option. Please choose from 1 to 5."
            ;;
    esac

    read -p "Press Enter to continue..."
done
