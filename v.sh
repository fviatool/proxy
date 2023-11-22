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
    echo "Installing 3proxy..."
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
$(awk -F "/" '{print "iptables -I INPUT -p tcp --dport " $4 "  -m state --state NEW -j ACCEPT"}' ${WORKDATA}) 
EOF
}

gen_ifconfig() {
    cat <<EOF
$(awk -F "/" '{print "ifconfig eth0 inet6 add " $5 "/64"}' ${WORKDATA})
EOF
}

cat >> /etc/rc.local <<EOF
bash ${WORKDIR}/boot_iptables.sh
bash ${WORKDIR}/boot_ifconfig.sh
ulimit -n 10048
/usr/local/etc/3proxy/bin/3proxy /usr/local/etc/3proxy/3proxy.cfg
EOF

echo "Installing apps..."
yum -y install wget gcc net-tools bsdtar zip >/dev/null
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

echo "Working folder = /home/cloudfly"
WORKDIR="/home/cloudfly"
WORKDATA="${WORKDIR}/data.txt"
mkdir $WORKDIR && cd $_

IP4=$(curl -4 -s icanhazip.com)
IP6=$(curl -6 -s icanhazip.com | cut -f1-4 -d':')

echo "Internal IP = ${IP4}. External IPv6 subnet = ${IP6}"

while :; do
  read -p "Enter FIRST_PORT (between 10000 and 60000): " FIRST_PORT
  [[ $FIRST_PORT =~ ^[0-9]+$ ]] || { echo "Enter a valid number"; continue; }
  if ((FIRST_PORT >= 10000 && FIRST_PORT <= 60000)); then
    echo "OK! Valid number"
    break
  else
    echo "Number out of range, try again"
  fi
done
LAST_PORT=$(($FIRST_PORT + 3000))
echo "LAST_PORT is $LAST_PORT. Continuing..."

gen_data > $WORKDIR/data.txt
gen_iptables > $WORKDIR/boot_iptables.sh
gen_ifconfig > $WORKDIR/boot_ifconfig.sh
chmod +x ${WORKDIR}/boot_*.sh /etc/rc.local

gen_3proxy > /usr/local/etc/3proxy/3proxy.cfg

bash /etc/rc.local

gen_proxy_file_for_user
rm -rf /root/3proxy-3proxy-0.8.6
echo "Starting Proxy"

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
$(awk -F "/" '{print "iptables -I INPUT -p tcp --dport " $4 "  -m state --state NEW -j ACCEPT"}' ${WORKDATA}) 
EOF
}

gen_ifconfig() {
    cat <<EOF
$(awk -F "/" '{print "ifconfig eth0 inet6 add " $5 "/64"}' ${WORKDATA})
EOF
}

# Thêm vào rc.local để tự động chạy khi khởi động hệ thống
add_to_rc_local() {
    cat <<EOF >> /etc/rc.local
bash ${WORKDIR}/boot_iptables.sh
bash ${WORKDIR}/boot_ifconfig.sh
ulimit -n 10048
/usr/local/etc/3proxy/bin/3proxy /usr/local/etc/3proxy/3proxy.cfg
EOF
}

# Thêm vào crontab để kiểm tra xoay tự động mỗi 10 phút
add_rotation_cronjob() {
    echo "*/10 * * * * bash ${WORKDIR}/rotate_proxies.sh" >> /etc/crontab
}

echo "Installing dependencies..."
yum -y install wget gcc net-tools bsdtar zip >/dev/null

install_3proxy

# Update these paths if needed
WORKDIR="/home/cloudfly"
IPTABLES_SCRIPT="${WORKDIR}/boot_iptables.sh"
IFCONFIG_SCRIPT="${WORKDIR}/boot_ifconfig.sh"

# Add the correct paths in rc.local
cat >> /etc/rc.local <<EOF
bash ${IPTABLES_SCRIPT}
bash ${IFCONFIG_SCRIPT}
ulimit -n 10048
/usr/local/etc/3proxy/bin/3proxy /usr/local/etc/3proxy/3proxy.cfg
EOF

IP4=$(curl -4 -s icanhazip.com)
IP6=$(curl -6 -s icanhazip.com | cut -f1-4 -d':')

echo "Internal IP = ${IP4}. External IPv6 subnet = ${IP6}"

while :; do
  read -p "Enter FIRST_PORT (between 10000 and 60000): " FIRST_PORT
  [[ $FIRST_PORT =~ ^[0-9]+$ ]] || { echo "Enter a valid number"; continue; }
  if ((FIRST_PORT >= 10000 && FIRST_PORT <= 60000)); then
    echo "OK! Valid number"
    break
  else
    echo "Number out of range, try again"
  fi
done
LAST_PORT=$(($FIRST_PORT + 3000))
echo "LAST_PORT is $LAST_PORT. Continuing..."

gen_data > $WORKDIR/data.txt
gen_iptables > $WORKDIR/boot_iptables.sh
gen_ifconfig > $WORKDIR/boot_ifconfig.sh
chmod +x ${WORKDIR}/boot_*.sh

gen_3proxy > /usr/local/etc/3proxy/3proxy.cfg

add_to_rc_local

# Tạo script rotate_proxies.sh
echo '#!/bin/bash' > ${WORKDIR}/rotate_proxies.sh
echo 'new_ipv6=$(get_new_ipv6)' >> ${WORKDIR}/rotate_proxies.sh
echo 'update_3proxy_config "$new_ipv6"' >> ${WORKDIR}/rotate_proxies.sh
echo 'restart_3proxy' >> ${WORKDIR}/rotate_proxies.sh
chmod +x ${WORKDIR}/rotate_proxies.sh

# Thêm vào crontab để xoay tự động
add_rotation_cronjob

gen_proxy_file_for_user
rm -rf /root/3proxy-3proxy-0.8.6
echo "Starting Proxy"

#!/bin/bash

CONFIG_FILE="/usr/local/etc/app_config.conf"
PROXY_CONFIG_FILE="/usr/local/etc/3proxy/3proxy.cfg"
LOG_FILE="/var/log/3proxy.log"

display_menu() {
  clear
  echo "========== 3Proxy Management Menu =========="
  echo "[1] Enable IP Authentication"
  echo "[2] Disable IP Authentication"
  echo "[3] Generate New Ports"
  echo "[4] Enable Auto Rotation"
  echo "[5] Create and Download Proxies"
  echo "[6] Show Proxy List"
  echo "[7] Download Proxy List"
  echo "[8] Exit"
  echo "============================================"
}

menu_option() {
  read -p "Enter your choice [1-8]: " choice
  case $choice in
    1) enable_ip_authentication ;;
    2) disable_ip_authentication ;;
    3) generate_new_ports ;;
    4) enable_auto_rotate ;;
    5) create_and_download_proxies ;;
    6) show_proxy_list ;;
    7) download_proxy_list ;;
    8) exit ;;
    *) echo "Invalid choice. Please choose again." ;;
  esac
}

apply_configuration_changes() {
  # This is a placeholder function.
  # In a real deployment, you might reload or apply your specific configuration here.
  echo "Applying configuration changes..."
  # Example: systemctl restart your_service
  sleep 2
}

enable_ip_authentication() {
  echo "Đang Bật Xác Thực IP..."

  read -p "Nhập ít nhất một địa chỉ IP để xác thực (sử dụng dấu phẩy để phân tách nếu có nhiều IPs): " ip_addresses

  if [ -f "$CONFIG_FILE" ]; then
    # Kiểm tra xem người dùng đã nhập ít nhất một địa chỉ IP hay không
    if [ -n "$ip_addresses" ]; then
      # Thay thế dòng cấu hình IP_AUTHENTICATION=false bằng IP_AUTHENTICATION=true và thêm danh sách IP cần xác thực
      sed -i "s/IP_AUTHENTICATION=false/IP_AUTHENTICATION=true\nALLOWED_IPS=\"$ip_addresses\"/" "$CONFIG_FILE"
      apply_configuration_changes
      echo "Đã Bật Xác Thực IP thành công cho các địa chỉ: $ip_addresses."
    else
      echo "Lỗi: Ít nhất một địa chỉ IP là bắt buộc để Bật Xác Thực IP."
    fi
  else
    echo "Lỗi: Không tìm thấy tệp cấu hình."
  fi

  sleep 2
}

disable_ip_authentication() {
  echo "Disabling IP Authentication..."

  if [ -f "$CONFIG_FILE" ]; then
    sed -i 's/IP_AUTHENTICATION=true/IP_AUTHENTICATION=false/' "$CONFIG_FILE"
    apply_configuration_changes
  else
    echo "Error: Configuration file not found."
  fi

  echo "IP Authentication disabled successfully."
  sleep 2
}

generate_new_ports() {
  echo "Generating New Ports..."

  starting_port=10000
  number_of_ports=5000

  for ((i = 0; i < number_of_ports; i++)); do
    new_port=$((starting_port + i))
    echo "New Port: $new_port"
    # Your logic to use the new port as needed
  done

  echo "New ports generated successfully."
  sleep 2
}

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
  systemctl restart 3proxy.service
}

# Gọi menu quản lý 3Proxy
while true; do
  display_menu
  menu_option
done
