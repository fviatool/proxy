#!/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

# Hàm tạo chuỗi ngẫu nhiên
random() {
	tr </dev/urandom -dc A-Za-z0-9 | head -c5
	echo
}

# Hàm tạo IPv6
array=(1 2 3 4 5 6 7 8 9 0 a b c d e f)
gen64() {
	ip64() {
		echo "${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}"
	}
	echo "$1:$(ip64):$(ip64):$(ip64):$(ip64)"
}

# Cài đặt 3proxy
install_3proxy() {
    echo "Đang cài đặt 3proxy"
    URL="https://github.com/z3APA3A/3proxy/archive/3proxy-0.8.6.tar.gz"
    wget -qO- $URL | bsdtar -xvf-
    cd 3proxy-3proxy-0.8.6
    make -f Makefile.Linux
    mkdir -p /usr/local/etc/3proxy/{bin,logs,stat}
    cp src/3proxy /usr/local/etc/3proxy/bin/
    cd $WORKDIR
}

# Tải proxy từ file.io
download_proxy() {
    cd /home/cloudfly || return
    curl -F "file=@proxy.txt" https://file.io
}

# Tạo cấu hình 3proxy
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

# Tạo danh sách IPv6
gen_ipv6_64() {
    rm "$WORKDIR/data.txt"
    count_ipv6=1
    while [ "$count_ipv6" -le "$MAXCOUNT" ]; do
        array=( 1 2 3 4 5 6 7 8 9 0 a b c d e f )
        ip64() {
            echo "${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}"
        }
        echo "$IP6:$(ip64):$(ip64):$(ip64):$(ip64)" >> "$WORKDIR/data.txt"
        let "count_ipv6 += 1"
    done
}

# Tạo file proxy.txt cho người dùng
gen_proxy_file_for_user() {
    cat >proxy.txt <<EOF
$(awk -F "/" '{print $3 ":" $4 ":" $1 ":" $2 }' ${WORKDATA})
EOF
}

# Tạo dữ liệu cho proxy
gen_data() {
    seq $FIRST_PORT $LAST_PORT | while read port; do
        echo "//$IP4/$port/$(gen64 $IP6)"
    done
}

# Tạo rules iptables
gen_iptables() {
    cat <<EOF
$(awk -F "/" '{print "iptables -I INPUT -p tcp --dport " $4 "  -m state --state NEW -j ACCEPT"}' ${WORKDATA}) 
EOF
}

# Tạo lệnh ifconfig
gen_ifconfig() {
    cat <<EOF
$(awk -F "/" '{print "ifconfig eth0 inet6 add " $5 "/64"}' ${WORKDATA})
EOF
}

# Tạo file rc.local
cat << EOF > /etc/rc.d/rc.local
#!/bin/bash
touch /var/lock/subsys/local
EOF

# Cài đặt các ứng dụng cần thiết
echo "Đang cài đặt ứng dụng"
yum -y install wget gcc net-tools bsdtar zip >/dev/null

# Cài đặt 3proxy
install_3proxy

# Thư mục làm việc
echo "Thư mục làm việc = /home/cloudfly"
WORKDIR="/home/cloudfly"
WORKDATA="${WORKDIR}/data.txt"
mkdir $WORKDIR && cd $_

# Lấy địa chỉ IPv4 và IPv6
IP4=$(curl -4 -s icanhazip.com)
IP6=$(curl -6 -s icanhazip.com | cut -f1-4 -d':')

echo "Địa chỉ IP nội bộ = ${IP4}. Subnet ngoại vi cho IPv6 = ${IP6}"

# Thiết lập cổng đầu tiên và cổng cuối cùng
FIRST_PORT=10000
LAST_PORT=500

# Lặp qua từng cổng và cài đặt
while [[ $FIRST_PORT -le $LAST_PORT ]]; do
  echo "Cổng hiện tại: $FIRST_PORT"
  iptables -I INPUT -p tcp --dport $FIRST_PORT -m state --state NEW -j ACCEPT

  # Tăng giá trị cổng cho lần lặp tiếp theo
  ((FIRST_PORT++))
done

echo "Cài đặt cổng hoàn tất."
    break
  else
    echo "Đang thiết lập Proxy"
  fi
done

# Tạo dữ liệu cho proxy
gen_data >$WORKDIR/data.txt
gen_iptables >$WORKDIR/boot_iptables.sh
gen_ifconfig >$WORKDIR/boot_ifconfig.sh
chmod +x ${WORKDIR}/boot_*.sh /etc/rc.local

# Tạo cấu hình 3proxy
gen_3proxy >/usr/local/etc/3proxy/3proxy.cfg

# Thêm lệnh khởi động vào rc.local
cat >>/etc/rc.local <<EOF
bash ${WORKDIR}/boot_iptables.sh
bash ${WORKDIR}/boot_ifconfig.sh
ulimit -n 10048
/usr/local/etc/3proxy/bin/3proxy /usr/local/etc/3proxy/3proxy.cfg
EOF

bash /etc/rc.local

# Tạo file proxy cho người dùng
gen_proxy_file_for_user

# Dọn dẹp
rm -rf /root/3proxy-3proxy-0.8.6

# Khởi động proxy
echo "Bắt đầu Proxy"
echo "Số lượng địa chỉ IPv6 hiện tại:"
ip -6 addr | grep inet6 | wc -l
download_proxy
