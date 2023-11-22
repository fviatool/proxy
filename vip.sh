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
    echo "Installing 3proxy..."
    URL="https://github.com/z3APA3A/3proxy/archive/3proxy-0.8.6.tar.gz"
    wget -qO- $URL | bsdtar -xvf-
    cd 3proxy-3proxy-0.8.6
    make -f Makefile.Linux
    mkdir -p /usr/local/etc/3proxy/{bin,logs,stat}
    cp src/3proxy /usr/local/etc/3proxy/bin/
    cd "$WORKDIR"
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
"flush\n"}' "${WORKDATA}")
EOF
}

gen_proxy_file_for_user() {
    awk -F "/" '{print $3 ":" $4 ":" $1 ":" $2 }' "${WORKDATA}" > "${WORKDIR}/proxy.txt"
}

rotate_script="${WORKDIR}/rotate_proxies.sh"
echo '#!/bin/bash' > "$rotate_script"
echo 'new_ipv6=$(get_new_ipv6)' >> "$rotate_script"
echo 'update_3proxy_config "$new_ipv6"' >> "$rotate_script"
echo 'restart_3proxy' >> "$rotate_script"
chmod +x "$rotate_script"

# Add rotation to crontab for automatic rotation
add_rotation_cronjob() {
    echo "*/10 * * * * $rotate_script" >> /etc/crontab
}

echo "Installing necessary packages..."
yum -y install wget gcc net-tools bsdtar zip >/dev/null

cat << EOF > /etc/rc.d/rc.local
#!/bin/bash
touch /var/lock/subsys/local
EOF

install_3proxy

echo "Thư mục làm việc = /home/cloudfly"
WORKDIR="/home/cloudfly"
WORKDATA="${WORKDIR}/data.txt"
mkdir "$WORKDIR" && cd "$_"

IP4=$(curl -4 -s icanhazip.com)
IP6=$(curl -6 -s icanhazip.com | cut -f1-4 -d':')

echo "IP nội bộ = ${IP4}. Subnet IPv6 ngoại trời = ${IP6}"

while :; do
    read -p "Nhập FIRST_PORT từ 10000 đến 60000: " FIRST_PORT
    [[ $FIRST_PORT =~ ^[0-9]+$ ]] || { echo "Nhập một số hợp lệ"; continue; }
    if ((FIRST_PORT >= 10000 && FIRST_PORT <= 60000)); then
        echo "OK! Số hợp lệ"
        break
    else
        echo "Số nằm ngoài phạm vi, hãy thử lại"
    fi
done

LAST_PORT=$(($FIRST_PORT + 3000))
echo "LAST_PORT là $LAST_PORT. Tiếp tục..."

gen_data > "${WORKDIR}/data.txt"
gen_iptables > "${WORKDIR}/boot_iptables.sh"

gen_3proxy > "/usr/local/etc/3proxy/3proxy.cfg"

cat >> /etc/rc.local <<EOF
bash ${WORKDIR}/boot_iptables.sh
ulimit -n 10048
/usr/local/etc/3proxy/bin/3proxy /usr/local/etc/3proxy/3proxy.cfg
EOF

chmod 0755 /etc/rc.local
bash /etc/rc.local

gen_proxy_file_for_user
rm -rf /root/3proxy-3proxy-0.8.6
echo "Starting Proxy"

# Adjusted menu
show_menu() {
    clear
    echo "Menu:"
    echo "1. Tạo proxy và cập nhật"
    echo "2. Xoay proxy tự động"
    echo "3. Hiển thị danh sách proxy"
    echo "4. Tải về danh sách proxy"
    echo "5. Thoát"
}

while true; do
    show_menu
    read -p "Chọn một tùy chọn (1-5): " choice

    case $choice in
        1)
            gen_data >${WORKDIR}/data.txt
            gen_3proxy >/usr/local/etc/3proxy/3proxy.cfg
            echo "Proxy được tạo và cập nhật vào danh sách."
            ;;
        2)
            rotate_proxies &
            echo "Đã bắt đầu xoay proxy tự động."
            ;;
        3)
            cat proxy.txt
            ;;
        4)
            download_proxy
            ;;
        5)
            echo "Thoát..."
            exit 0
            ;;
        *)
            echo "Tùy chọn không hợp lệ. Vui lòng chọn từ 1 đến 5."
            ;;    esac

    sleep 2
done
enable_auto_rotate() {
  echo "Enabling Auto Rotation..."

  auto_rotate=true

  while [ "$auto_rotate" = true ]; do
    rotate_proxies
    sleep 600  # Sleep for 10 minutes
  done

  echo "Disabling Auto Rotation."
}

create_and_download_proxies() {
  echo "Creating and Downloading Proxies..."

  gen_data > "$PROXY_CONFIG_FILE"
  download_proxy
  echo "Proxies created and downloaded successfully."
  sleep 2
}

download_proxy() {
  echo "Downloading proxies..."
  curl -F "$PROXY_CONFIG_FILE" https://transfer.sh > proxy.txt
  echo "Proxies downloaded successfully."
}

show_proxy_list() {
  echo "Proxy List:"
  cat proxy.txt
}

download_proxy_list() {
  echo "Downloading proxy list..."
  curl -F "$PROXY_CONFIG_FILE" https://transfer.sh > proxy.txt
  echo "Proxy list downloaded."
}

rotate_proxies() {
  echo "Rotating proxies..."
  new_ipv6=$(get_new_ipv6)
  update_3proxy_config "$new_ipv6"
  restart_3proxy
  echo "Proxies rotated successfully."
}

get_new_ipv6() {
  random_ipv6=$(openssl rand -hex 8 | sed 's/\(..\)/:\1/g; s/://1')
  echo "$random_ipv6"
}

update_3proxy_config() {
  new_ipv6=$1
  sed -i "s/old_ipv6_address/$new_ipv6/" "$PROXY_CONFIG_FILE"
}

restart_3proxy() {
  while true; do
    for ((i = $FIRST_PORT; i < $LAST_PORT; i++)); do
      IPV6=$(head -n $i $WORKDIR/ipv6.txt | tail -n 1)
      /usr/local/etc/3proxy/bin/3proxy /usr/local/etc/3proxy/3proxy.cfg -sstop
      /usr/local/etc/3proxy/bin/3proxy /usr/local/etc/3proxy/3proxy.cfg -h$IP4 -e$IPV6 -p$i
    done
    sleep 900  # Sleep for 15 minutes (900 seconds)
  done
}
