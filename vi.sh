#!/bin/bash
YUM=$(which yum)

# Function to generate a random string
random() {
    tr </dev/urandom -dc A-Za-z0-9 | head -c5
    echo
}

# Array for generating IPv6
array=(1 2 3 4 5 6 7 8 9 0 a b c d e f)

# Function to generate an IPv6 address
gen64() {
    ip64() {
        echo "${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}"
    }
    echo "$1:$(ip64):$(ip64):$(ip64):$(ip64)"
}

# Function to install 3proxy
install_3proxy() {
    echo "Installing 3proxy"
    URL="https://github.com/z3APA3A/3proxy/archive/3proxy-0.8.6.tar.gz"
    wget -qO- $URL | bsdtar -xvf-
    cd 3proxy-3proxy-0.8.6
    make -f Makefile.Linux
    mkdir -p /usr/local/etc/3proxy/{bin,logs,stat}
    cp src/3proxy /usr/local/etc/3proxy/bin/
    cd $WORKDIR
}

# Function to generate data for 3proxy
gen_data() {
    seq $FIRST_PORT $LAST_PORT | while read port; do
        echo "//$IP4/$port/$(gen64 $IP6)"
    done
}

# Function to generate iptables rules
gen_iptables() {
    cat <<EOF
$(awk -F "/" '{print "iptables -I INPUT -p tcp --dport " $4 "  -m state --state NEW -j ACCEPT"}' ${WORKDATA}) 
EOF
}

# Function to generate 3proxy configuration
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

# Function to generate a proxy file for the user
gen_proxy_file_for_user() {
    cat >proxy.txt <<EOF
$(awk -F "/" '{print $3 ":" $4 ":" $1 ":" $2 }' ${WORKDATA})
EOF
}

# Function to rotate IPv6 and change proxy
xoay_ipv6() {
    echo "Rotating IPv6 and changing proxy..."
    new_ipv6=$(get_new_ipv6)
    update_3proxy_config "$new_ipv6"
    restart_3proxy
    echo "Proxy rotated successfully."
}

# Function to get a new IPv6 address
get_new_ipv6() {
    random_ipv6=$(openssl rand -hex 8 | sed 's/\(..\)/:\1/g; s/://1')
    echo "$random_ipv6"
}

# Function to update 3proxy configuration with a new IPv6
update_3proxy_config() {
    new_ipv6=$1
    sed -i "s/old_ipv6_address/$new_ipv6/" /usr/local/etc/3proxy/3proxy.cfg
}

# Function to restart 3proxy service
restart_3proxy() {
    systemctl restart 3proxy
}

# Function to enable auto rotation of proxies
enable_auto_rotate() {
    echo "Enabling auto rotation..."

    auto_rotate=true

    while [ "$auto_rotate" = true ]; do
        xoay_ipv6
        sleep 600  # Sleep for 10 minutes
    done

    echo "Disabling auto rotation."
}

# Function to show the menu
show_menu() {
    clear
    echo "Menu:"
    echo "1. Create and update proxies"
    echo "2. Rotate proxies automatically"
    echo "3. Show proxy list"
    echo "4. Download proxy list"
    echo "5. Exit"
}

# Main script
echo "Installing dependencies"
$YUM -y install wget gcc net-tools bsdtar zip >/dev/null

echo "Setting up working directory"
WORKDIR="/home/cloudfly"
WORKDATA="${WORKDIR}/data.txt"
mkdir $WORKDIR && cd $_

IP4=$(curl -4 -s icanhazip.com)
IP6=$(curl -6 -s icanhazip.com | cut -f1-4 -d':')

echo "Internal IP = ${IP4}. External IPv6 subnet = ${IP6}"

while :; do
    read -p "Enter FIRST_PORT (between 10000 and 60000): " FIRST_PORT
    [[ $FIRST_PORT =~ ^[0-9]+$ ]] || { echo "Enter a valid number"; continue; }
    if ((FIRST_PORT >= 10000 && LAST_PORT <= 60000)); then
        echo "OK! Valid number"
        break
    else
        echo "Number is outside the range, please try again"
    fi
done

LAST_PORT=$(($FIRST_PORT + 5000))
echo "LAST_PORT is $LAST_PORT. Continuing..."

gen_data >${WORKDIR}/data.txt
gen_iptables >${WORKDIR}/boot_iptables.sh

gen_3proxy >/usr/local/etc/3proxy/3proxy.cfg

cat >>/etc/rc.local <<EOF
bash ${WORKDIR}/boot_iptables.sh
ulimit -n 10048
/usr/local/etc/3proxy/bin/3proxy/usr/local/etc/3proxy/3proxy.cfg
EOF

chmod 0755 /etc/rc.local
bash /etc/rc.local

enable_auto_rotate

show_proxy_list() {
    echo "Proxy List:"
    cat proxy.txt
}

download_proxy() {
    echo "Downloading proxies..."
    curl -F "$PROXY_CONFIG_FILE" https://transfer.sh > proxy.txt
    echo "Proxies downloaded successfully."
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

# Function to rotate and restart proxies
rotate_and_restart() {
    while true; do
        for ((i = $FIRST_PORT; i < $LAST_PORT; i++)); do
            IPV6=$(head -n $i $WORKDIR/ipv6.txt | tail -n 1)
            /usr/local/etc/3proxy/bin/3proxy /usr /local/etc/3proxy/3proxy.cfg -sstop/usr/local/etc/3proxy/bin/3proxy /usr/local/etc/3proxy/3proxy.cfg -h$IP4 -e$IPV6 -p$i
        done
        /usr/local/etc/3proxy/bin/3proxy /usr/local/etc/3proxy/3proxy.cfg
        sleep 900  # Sleep for 15 minutes (900 seconds)
    done
}

# Adjusted menu
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
            show_proxy_list
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
            ;;
    esac

    sleep 2
done
