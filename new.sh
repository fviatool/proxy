#!/bin/bash

# Kiểm tra xem mô-đun IPv6 đã được tải vào kernel hay chưa
if ! lsmod | grep -q '^ipv6\s'; then
    echo "Loading IPv6 module..."
    modprobe ipv6
    echo "IPv6 module loaded"
else
    echo "IPv6 module is already loaded"
fi

# Thiết lập cấu hình mặc định cho IPv6
sysctl -w net.ipv6.conf.all.disable_ipv6=0
sysctl -w net.ipv6.conf.default.disable_ipv6=0

# Hàm tạo địa chỉ IPv6 ngẫu nhiên
random_ipv6() {
    tr </dev/urandom -dc A-Fa-f0-9 | head -c 4 | sed -e 's/\(..\)/:\1/g'
}

# Hàm cập nhật cấu hình 3proxy với IPv6 mới
update_3proxy_config() {
    local ipv6=$1
    awk -F "/" -v ipv6="$ipv6" '{
        print "\ndaemon\nmaxconn 2000\nnserver 1.1.1.1\nnserver 8.8.4.4\nnserver 2001:4860:4860::8888\nnserver 2001:4860:4860::8844\nnserver 2404:6800:4005:813::2003\nnscache 65536\ntimeouts 1 5 30 60 180 1800 15 60\nsetgid 65535\nsetuid 65535\nstacksize 6291456 \nflush\n"
        print "\n" $1 "\n"
        print "proxy -6 -n -a -p" $4 " -i" $3 " -e" ipv6 "\n"
        print "flush\n"
    }' ${WORKDATA} >/usr/local/etc/3proxy/3proxy.cfg
}

# Hàm khởi động lại 3proxy
restart_3proxy() {
    systemctl restart 3proxy
}

# Hàm thêm công việc quay số vào crontab
add_rotation_cronjob() {
    echo "*/10 * * * * $rotate_script" >> /etc/crontab
}

# Kiểm tra và cài đặt dependencies
install_dependencies() {
    echo "Installing dependencies..."
    yum -y install wget gcc net-tools bsdtar zip >/dev/null
}

# Thiết lập cấu hình mặc định
setup_default_config() {
    echo "Setting up default configuration..."
    cat << EOF > /etc/rc.d/rc.local
#!/bin/bash
touch /var/lock/subsys/local
EOF
    chmod +x /etc/rc.d/rc.local
}

# Cài đặt 3proxy
install_3proxy() {
    echo "Installing 3proxy..."
    local URL="https://github.com/z3APA3A/3proxy/archive/3proxy-0.8.6.tar.gz"
    wget -qO- $URL | bsdtar -xvf-
    cd 3proxy-3proxy-0.8.6
    make -f Makefile.Linux
    mkdir -p /usr/local/etc/3proxy/{bin,logs,stat}
    cp src/3proxy /usr/local/etc/3proxy/bin/
    cd $WORKDIR
}

# Hàm tạo dữ liệu proxy
gen_data() {
    seq $FIRST_PORT $LAST_PORT | while read port; do
        echo "//$IP4/$port/$(gen64 $IP6)"
    done
}

# Hàm tạo tệp cấu hình iptables
gen_iptables() {
    awk -F "/" '{print "iptables -I INPUT -p tcp --dport " $4 "  -m state --state NEW -j ACCEPT"}' ${WORKDATA}
}

# Hàm tạo tệp cấu hình 3proxy
gen_3proxy() {
    awk -F "/" '{
        print "\ndaemon\nmaxconn 2000\nnserver 1.1.1.1\nnserver 8.8.4.4\nnserver 2001:4860:4860::8888\nnserver 2001:4860:4860::8844\nnserver 2404:6800:4005:813::2003\nnscache 65536\ntimeouts 1 5 30 60 180 1800 15 60\nsetgid 65535\nsetuid 65535\nstacksize 6291456 \nflush\n"
        print "\n" $1 "\n"
        print "proxy -6 -n -a -p" $4 " -i“ $3 “ -e”$5”\n”
print “flush\n”
}’ ${WORKDATA}
}

Hàm tạo tệp proxy cho người dùng

gen_proxy_file_for_user() {
awk -F “/” ‘{print $3 “:” $4 “:” $1 “:” $2 }’ ${WORKDATA} > proxy.txt
}

Hàm tạo script quay số

create_rotate_script() {
local rotate_script=”${WORKDIR}/rotate_proxies.sh”
echo ‘#!/bin/bash’ > “$rotate_script”
echo ‘new_ipv6=$(get_new_ipv6)’ >> “$rotate_script”
echo ‘update_3proxy_config “$new_ipv6”’ >> “$rotate_script”
echo ‘restart_3proxy’ >> “$rotate_script”
chmod +x “$rotate_script”
}

Hàm hiển thị danh sách proxy

show_proxy_list() {
echo “Proxy List:”
cat proxy.txt
}

Hàm tải proxy

download_proxy() {
echo “Downloading proxies…”
curl -F “$PROXY_CONFIG_FILE” https://transfer.sh > proxy.txt
echo “Proxies downloaded successfully.”
}

Hàm quay số và khởi động lại proxy

rotate_and_restart() {
while true; do
for ((i = $FIRST_PORT; i < $LAST_PORT; i++)); do
IPV6=$(head -n $i $WORKDIR/ipv6.txt | tail -n 1)
/usr/local/etc/3proxy/bin/3proxy /usr/local/etc/3proxy/3proxy.cfg -sstop/usr/local/etc/3proxy/bin/3proxy /usr/local/etc/3proxy/3proxy.cfg -h$IP4 -e$IPV6 -p$i
done
/usr/local/etc/3proxy/bin/3proxy /usr/local/etc/3proxy/3proxy.cfg
sleep 900  # Sleep for 15 minutes (900 seconds)
done
}

Hàm hiển thị menu

show_menu() {
clear
echo “Menu:”
echo “1. Generate and Update proxies”
echo “2. Rotate proxies automatically”
echo “3. Show proxy list”
echo “4. Download proxy list”
echo “5. Exit”
}

Hàm chạy menu

run_menu() {
while true; do
show_menu
read -p “Choose an option (1-5): “ choice

    case $choice in
        1)
            gen_data >${WORKDIR}/data.txt
            gen_3proxy >/usr/local/etc/3proxy/3proxy.cfg
            echo "Proxies generated and updated in the list."
            ;;
        2)
            rotate_proxies &
            echo "Automatic proxy rotation started."
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
            echo "Invalid option. Please choose between 1 and 5."
            ;;
    esac

    sleep 2
done

}

Main function

main() {
install_dependencies
setup_default_config
install_3proxy
WORKDIR=”/home/cloudfly”
WORKDATA=”${WORKDIR}/data.txt”
mkdir -p $WORKDIR && cd $WORKDIR
IP4=$(curl -4 -s icanhazip.com)
IP6=$(curl -6 -s icanhazip.com | cut -f1-4 -d’:’)
echo “Internal IP = ${IP4}. External IPv6 Subnet = ${IP6}”

while :; do
    read -p "Enter FIRST_PORT (between 10000 and 60000): " FIRST_PORT
    [[ $FIRST_PORT =~ ^[0-9]+$ ]] || { echo "Enter a valid number"; continue; }
    if ((FIRST_PORT >= 10000 && FIRST_PORT <= 60000)); then
        echo "OK! Valid number"
        break
    else
        echo "Number is out of range, please try again"
    fi
done

LAST_PORT=$(($FIRST_PORT + 5000))
echo "LAST_PORT is $LAST_PORT. Continuing..."

create_rotate_script
add_rotation_cronjob
run_menu

}

main
	
