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
    $(awk -F "/" '{print "iptables -w 5 -I INPUT -p tcp --dport " $4 "  -m state --state NEW -j ACCEPT"}' ${WORKDATA}) 
EOF
}

gen_ifconfig() {
    cat <<EOF
$(awk -F "/" '{print "ifconfig eth0 inet6 add " $5 "/64"}' ${WORKDATA})
EOF
}

download_proxy() {
    cd /home/cloudfly || return
    curl -F "file=@proxy.txt" https://file.io
}

cat << EOF > /etc/rc.d/rc.local
#!/bin/bash
touch /var/lock/subsys/local
EOF

echo "installing apps"
yum -y install wget gcc net-tools bsdtar zip >/dev/null

# Kiểm tra sự tồn tại của thư mục đích và tạo nếu cần
if [ ! -d "/usr/local/etc/3proxy/bin/" ]; then
    mkdir -p /usr/local/etc/3proxy/bin/
fi

# Sao chép tệp 3proxy vào thư mục đích
cp src/3proxy /usr/local/etc/3proxy/bin/

install_3proxy

echo "working folder = /home/cloudfly"
WORKDIR="/home/cloudfly"
WORKDATA="${WORKDIR}/data.txt"
mkdir $WORKDIR && cd $_

IP4=$(curl -4 -s icanhazip.com)
IP6=$(curl -6 -s icanhazip.com | cut -f1-4 -d':')

echo "Internal ip = ${IP4}. External sub for ip6 = ${IP6}/64"

PORT_COUNT=1000  # Số lượng cổng muốn tạo tự động
MAX_PORT=65535

if [[ $PORT_COUNT =~ ^[0-9]+$ ]] && ((PORT_COUNT > 0)); then
    echo "OK! Valid quantity entered: $PORT_COUNT"
    FIRST_PORT=$((RANDOM % MAX_PORT))
    if [[ $FIRST_PORT =~ ^[0-9]+$ ]] && ((FIRST_PORT >= 0 && FIRST_PORT <= MAX_PORT)); then
        echo "Random port generated: $FIRST_PORT."
        LAST_PORT=$((FIRST_PORT + PORT_COUNT - 1))
        echo "The random port range is from $FIRST_PORT to $LAST_PORT."
    else
        echo "The randomly generated port is out of range, please try again."
    fi
else
    echo "Invalid quantity entered: $PORT_COUNT. Please enter a positive integer."
fi

gen_data >$WORKDIR/data.txt
gen_iptables >$WORKDIR/boot_iptables.sh
gen_ifconfig >$WORKDIR/boot_ifconfig.sh
chmod +x $WORKDIR/boot_*.sh /etc/rc.local

# Tạo tệp cấu hình cho 3proxy
gen_3proxy >/usr/local/etc/3proxy/3proxy.cfg

# Thêm lệnh vào rc.local để khởi động các thiết lập khi hệ thống khởi động
cat >>/etc/rc.local <<EOF
bash ${WORKDIR}/boot_iptables.sh
bash ${WORKDIR}/boot_ifconfig.sh
ulimit -n 10048
/usr/local/etc/3proxy/bin/3proxy /usr/local/etc/3proxy/3proxy.cfg
EOF

# Thực hiện rc.local
bash /etc/rc.local

# Tạo tệp proxy cho người dùng
gen_proxy_file_for_user

# Xóa thư mục tạm
rm -rf /root/3proxy-3proxy-0.8.6

echo "Starting Proxy"

check_ipv6_live() {
    local ipv6_address=$1
    ping6 -c 3 $ipv6_address
}

# Sử dụng hàm để kiểm tra tính sống của một địa chỉ IPv6 cụ thể
check_all_ipv6_live() {
    ip -6 addr | grep inet6 | while read -r line; do
        address=$(echo "$line" | awk '{print $2}')
        ip6=$(echo "$address" | cut -d'/' -f1)
        ping6 -c 1 $ip6 > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            echo "IPv4: $IP4:$port -> $ip6 Live"
        else
            echo "$ip6 is not live"
        fi
    done
}

check_all_ipv6_live
check_ipv6_live $some_ipv6_address  # Thay some_ipv6_address bằng địa chỉ IPv6 cụ thể
check_all_ips

check_all_ips() {
    while IFS= read -r line; do
        ipv6=$(echo "$line" | cut -d '/' -f 5)
        echo "Checking IPv6: $ipv6"
        ping6 -c 3 $ipv6
        echo "-----------------------------------"
    done < /home/cloudfly/data.txt
    
echo "Số lượng địa chỉ IPv6 hiện tại:"
ip -6 addr | grep inet6 | wc -l
# Tải xuống tệp proxy
download_proxy
