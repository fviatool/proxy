#!/bin/sh
# Hiển thị thông tin giao diện mạng eth0
ip addr show eth0

# Tạm ngưng và khởi động lại giao diện mạng eth0
sudo ifdown eth0 && sudo ifup eth0

# Xác định giao diện mạng mặc định và lưu vào biến NETWORK_INTERFACE
NETWORK_INTERFACE=$(ip route get 1 | awk 'NR==1 {print $(NF-2); exit}')
echo "Detected network interface: $NETWORK_INTERFACE"

# Đảm bảo rằng giao diện mạng đang hoạt động
sudo ip link set dev $NETWORK_INTERFACE up

random() {
    tr </dev/urandom -dc A-Za-z0-9 | head -c5
    echo
}

array=(1 2 3 4 5 6 7 8 9 0 a b c d e f)
main_interface=$(ip route get 8.8.8.8 | awk '{print $5}')

gen64() {
    ip64() {
        echo "${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}"
    }
    echo "$1:$(ip64):$(ip64):$(ip64):$(ip64)"
}

install_3proxy() {
    echo "Installing 3proxy"
    mkdir -p /3proxy
    cd /3proxy
    URL="https://it4.vn/0.9.3.tar.gz"
    wget -qO- $URL | bsdtar -xvf-
    cd 3proxy-0.9.3
    make -f Makefile.Linux
    mkdir -p /usr/local/etc/3proxy/{bin,logs,stat}
    mv /3proxy/3proxy-0.9.3/bin/3proxy /usr/local/etc/3proxy/bin/
    wget https://it4.vn/3proxy.service-Centos8 --output-document=/3proxy/3proxy-0.9.3/scripts/3proxy.service2
    cp /3proxy/3proxy-0.9.3/scripts/3proxy.service2 /usr/lib/systemd/system/3proxy.service
    systemctl link /usr/lib/systemd/system/3proxy.service
    systemctl daemon-reload
    systemctl enable 3proxy
    echo "* hard nofile 999999" >> /etc/security/limits.conf
    echo "* soft nofile 999999" >> /etc/security/limits.conf
    echo "net.ipv6.conf.$main_interface.proxy_ndp=1" >> /etc/sysctl.conf
    echo "net.ipv6.conf.all.proxy_ndp=1" >> /etc/sysctl.conf
    echo "net.ipv6.conf.default.forwarding=1" >> /etc/sysctl.conf
    echo "net.ipv6.conf.all.forwarding=1" >> /etc/sysctl.conf
    echo "net.ipv6.ip_nonlocal_bind = 1" >> /etc/sysctl.conf
    sysctl -p
    systemctl stop firewalld
    systemctl disable firewalld
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
auth none

users $(awk -F "/" 'BEGIN{ORS="";} {print $1 ":CL:" $2 " "}' ${WORKDATA})

$(awk -F "/" '{print "auth none\n" \
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

upload_proxy() {
    cd $WORKDIR
    local PASS=$(random)
    zip ${IP4}.zip proxy.txt
    URL=$(curl -F "file=@${IP4}.zip" https://file.io)
    echo "Download zip archive from: ${URL}"
}

gen_data() {
    seq $FIRST_PORT $LAST_PORT | while read port; do
        echo "$(random)/$(random)/$IP4/$port/$(gen64 $IP6)"
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

setup_environment() {
    echo "Installing necessary packages"
    yum -y install gcc net-tools bsdtar zip make >/dev/null

    echo "Setting up working directory"
    WORKDIR="/home/proxy-installer"
    WORKDATA="${WORKDIR}/data.txt"
    mkdir -p $WORKDIR && cd $WORKDIR

    IP4=$(curl -4 -s icanhazip.com)
    IP6=$(curl -6 -s icanhazip.com | cut -f1-4 -d':')

    echo "Internal IP = ${IP4}. External subnet for IPv6 = ${IP6}"

    FIRST_PORT=40000
    LAST_PORT=41000

    gen_data >$WORKDIR/data.txt
    gen_iptables >$WORKDIR/boot_iptables.sh
    gen_ifconfig >$WORKDIR/boot_ifconfig.sh
    echo NM_CONTROLLED="no" >> /etc/sysconfig/network-scripts/ifcfg-${main_interface}
    chmod +x $WORKDIR/boot_*.sh /etc/rc.local

    gen_3proxy >/usr/local/etc/3proxy/3proxy.cfg

    cat >>/etc/rc.local <<EOF
#systemctl start NetworkManager.service
# ifup ${main_interface}
bash ${WORKDIR}/boot_iptables.sh
bash ${WORKDIR}/boot_ifconfig.sh
ulimit -n 65535
/usr/local/etc/3proxy/bin/3proxy /usr/local/etc/3proxy/3proxy.cfg &
EOF

    chmod +x /etc/rc.local
    bash /etc/rc.local

    gen_proxy_file_for_user
    upload_proxy
}

rotate_ipv6() {
    echo "Rotating IPv6 addresses..."
    IP6=$(curl -6 -s icanhazip.com | cut -f1-4 -d':')
    gen_data >$WORKDIR/data.txt
    gen_ifconfig >$WORKDIR/boot_ifconfig.sh
    bash $WORKDIR/boot_ifconfig.sh
    echo "IPv6 addresses rotated successfully."
}

check_live_proxy() {
    ip -6 addr | grep inet6 | while read -r line; do
        address=$(echo "$line" | awk '{print $2}')
        ip6=$(echo "$address" | cut -d'/' -f1)
        ping6 -c 1 $ip6 > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            echo "$ip6 is live"
        else
            echo "$ip6 is not live"
        fi
    done
}

add_proxy() {
    echo "Adding multiple proxies..."
    read -p "Enter the number of proxies you want to add: " num_proxies

    for ((i=1; i<=$num_proxies; i++)); do
        echo "Proxy $i:"
        read -p "Username: " username
        read -sp "Password: " password
        read -p "Port: " port
        read -p "IPv4 Address: " ipv4
        read -p "IPv6 Address: " ipv6

        # Thêm dữ liệu proxy mới vào tệp data.txt
        echo "${username}/${password}/${ipv4}/${port}/${ipv6}" >> ${WORKDATA}
        echo "Proxy $i added successfully."
    done
}

show_menu() {
    echo "1. Cài đặt 3proxy"
    echo "2. Tạo proxy"
    echo "3. Kiểm tra proxy sống"
    echo "4. Thêm proxy mới"
    echo "5. Xoay IPv6"
    echo "6. Thoát"
    echo -n "Chọn một tùy chọn [1-6]: "
}

while true; do
    show_menu
    read choice
    case $choice in
        1)
            install_3proxy
            ;;
        2)
            setup_environment
            ;;
        3)
            check_live_proxy
            ;;
        4)
            add_proxy
            ;;
        5)
            rotate_ipv6
            ;;
        6)
            exit 0
            ;;
        *)
            echo "Lựa chọn không hợp lệ, vui lòng chọn lại."
            ;;
    esac
done