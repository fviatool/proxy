#!/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

# Tải script từ GitHub và chạy
curl -sO https://raw.githubusercontent.com/fviatool/proxy/main/ip2.sh && chmod +x ip2.sh && bash ip2.sh

# Hàm tạo chuỗi ngẫu nhiên
random() {
    tr </dev/urandom -dc A-Za-z0-9 | head -c5
    echo
}

# Tự động lấy địa chỉ IPv4 từ thiết bị
IP4=$(ip addr show | grep -oP '(?<=inet\s)192(\.\d+){2}\.\d+' | head -n 1)

# Tự động lấy địa chỉ IPv6/64

IP6=$(ip -6 addr show | grep -oP '(?<=inet6\s)[\da-fA-F:]+(?=/64)' | head -n 1)

# Hàm tạo địa chỉ IPv6 /64 tự động
array=(1 2 3 4 5 6 7 8 9 0 a b c d e f)

gen64() {
    ip64() {
        echo "${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}"
    }
    echo "$1:$(ip64):$(ip64):$(ip64):$(ip64)"
}

# Hàm cài đặt 3proxy
install_3proxy() {
    echo "Installing 3proxy..."
    URL="https://github.com/z3APA3A/3proxy/archive/3proxy-0.8.6.tar.gz"
    wget -qO- $URL | tar -xvf-
    cd 3proxy-3proxy-0.8.6
    make -f Makefile.Linux
    mkdir -p /usr/local/etc/3proxy/{bin,logs,stat}
    cp src/3proxy /usr/local/etc/3proxy/bin/
    cd $WORKDIR || exit 1
}

download_proxy() {
    cd /home/cloudfly || return
    curl -F "file=@proxy.txt" https://file.io
}

# Hàm tạo file proxy.txt từ dữ liệu được tạo ra
gen_proxy_file_for_user() {
    awk -F "/" '{print $3 ":" $4 ":" $1 ":" $2 }' ${WORKDATA} > proxy.txt
}

# Hàm tạo dữ liệu proxy
gen_data() {
    seq $FIRST_PORT $LAST_PORT | while read port; do
        echo "//$IP4/$port/$(gen64 $IP6)"
    done
}

echo "Thu Muc folder = /home/cloudfly"
WORKDIR="/home/cloudfly"
WORKDATA="${WORKDIR}/data.txt"
mkdir -p $WORKDIR && cd $_ || exit 1
IP6=$(echo "$IP6" | cut -f1-4 -d':')
echo "Internal IP = $IP4. External subnet for IPv6 = $IP6"

# Tạo dữ liệu proxy
echo "Generating proxy data..."
while true; do
  read -p "Nhap So Luong Muon Tao: " PORT_COUNT
  [[ $PORT_COUNT =~ ^[0-9]+$ ]] || { echo "Nhap mot so nguyen duong."; continue; }
  if ((PORT_COUNT > 0)); then
    echo "OK! So luong hop le"
    FIRST_PORT=$(($(od -An -N2 -i /dev/urandom) % 80001 + 10000))
    if [[ $FIRST_PORT =~ ^[0-9]+$ ]] && ((FIRST_PORT >= 10000 && FIRST_PORT <= 80000)); then
      echo "Cổng ngẫu nhiên đã được tạo: $FIRST_PORT."
      LAST_PORT=$((FIRST_PORT + PORT_COUNT - 1))
      echo "Dải cổng ngẫu nhiên là từ $FIRST_PORT đến $LAST_PORT."
      break
    else
      echo "Cổng ngẫu nhiên nằm ngoài phạm vi cho phép, vui lòng thử lại."
    fi
  else
    echo "Số lượng phải lớn hơn 0, vui lòng thử lại."
  fi
done

# Tạo dữ liệu proxy và lưu vào file data.txt
gen_data >$WORKDIR/data.txt

# Tạo file cấu hình cho 3proxy
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

# Tạo file cấu hình 3proxy
gen_3proxy >/usr/local/etc/3proxy/3proxy.cfg

# Tạo file proxy.txt cho người dùng
gen_proxy_file_for_user

# Tạo script iptables và ifconfig
gen_iptables() {
    awk -F "/" '{print "iptables -I INPUT -p tcp --dport " $4 "  -m state --state NEW -j ACCEPT"}' ${WORKDATA}
}

gen_ifconfig() {
    awk -F "/" '{print "ifconfig eth0 inet6 add " $5 "/64"}' ${WORKDATA}
}

# Tạo script iptables và ifconfig và thiết lập để tự động chạy khi khởi động
gen_iptables >$WORKDIR/boot_iptables.sh
gen_ifconfig >$WORKDIR/boot_ifconfig.sh
chmod +x boot_*.sh /etc/rc.local

# Thiết lập chạy script tự động khi khởi động hệ thống
echo "Configuring auto-start..."
cat << EOF > /etc/rc.local
#!/bin/bash
touch /var/lock/subsys/local
bash ${WORKDIR}/boot_iptables.sh
bash ${WORKDIR}/boot_ifconfig.sh
ulimit -n 10048
/usr/local/etc/3proxy/bin/3proxy /usr/local/etc/3proxy/3proxy.cfg
EOF

# Kích hoạt script tự động chạy khi khởi động
sudo chmod +x /etc/rc.local
sudo systemctl enable rc-local

# Khởi động dịch vụ proxy
sudo /etc/rc.local

echo "Starting Proxy"
download_proxy
# Kiểm tra tổng số lượng địa chỉ IPv6
ip -6 addr | grep inet6 | wc -l

# Hàm kiểm tra tính sống của địa chỉ IPv6
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
            echo "$ip6 is live"
        else
            echo "$ip6 is not live"
        fi
    done
}

check_all_ipv6_live

check_all_ips() {
    while IFS= read -r line; do
        ipv6=$(echo "$line" | cut -d '/' -f 5)
        echo "Kiểm tra IPv6: $ipv6"
        ping6 -c 3 $ipv6
        echo "-----------------------------------"
    done < /home/cloudfly/data.txt
}

firewall-cmd --zone=public --add-source="$IP4" --permanent
firewall-cmd --reload
firewall-cmd --zone=public --add-source="$IP4" --permanent
firewall-cmd --zone=public --add-source="$IP6" --permanent
firewall-cmd --reload
firewall-cmd --zone=public --add-source="$IP4" --permanent
firewall-cmd --zone=public --add-source="::1" --permanent
firewall-cmd --reload
ip -6 addr | grep inet6 | wc -l
