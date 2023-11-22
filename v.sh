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

gen_data() {
    seq $FIRST_PORT $LAST_PORT | while read port; do
        echo "//$IP4/$port/$(gen64 $IP6)"
    done
}

gen_iptables() {
    awk -F "/" '{print "iptables -I INPUT -p tcp --dport " $4 "  -m state --state NEW -j ACCEPT"}' ${WORKDATA}
}

gen_3proxy() {
    awk -F "/" '{print "\ndaemon\nmaxconn 2000\nnserver 1.1.1.1\nnserver 8.8.4.4\nnserver 2001:4860:4860::8888\nnserver 2001:4860:4860::8844\nnscache 65536\ntimeouts 1 5 30 60 180 1800 15 60\nsetgid 65535\nsetuid 65535\nstacksize 6291456 \nflush\n\n" \
    "" $1 "\n" \
    "proxy -6 -n -a -p" $4 " -i" $3 " -e"$5"\n" \
    "flush\n"}' ${WORKDATA}
}

gen_proxy_file_for_user() {
    awk -F "/" '{print $3 ":" $4 ":" $1 ":" $2 }' ${WORKDATA} > proxy.txt
}

rotate_script="${WORKDIR}/rotate_proxies.sh"
echo '#!/bin/bash' > "$rotate_script"
echo 'new_ipv6=$(get_new_ipv6)' >> "$rotate_script"
echo 'update_3proxy_config "$new_ipv6"' >> "$rotate_script"
echo 'restart_3proxy' >> "$rotate_script"
chmod +x "$rotate_script"

# Add to crontab for automatic rotation
add_rotation_cronjob() {
    echo "*/10 * * * * $rotate_script" >> /etc/crontab
}

echo "Installing dependencies..."
yum -y install wget gcc net-tools bsdtar zip >/dev/null

echo "Configuring the application..."
cat << EOF > /etc/rc.d/rc.local
#!/bin/bash
touch /var/lock/subsys/local
EOF

install_3proxy

echo "Setting up working directory..."
WORKDIR="/home/cloudfly"
WORKDATA="${WORKDIR}/data.txt"
mkdir -p $WORKDIR && cd $WORKDIR

IP4=$(curl -4 -s icanhazip.com)
IP6=$(curl -6 -s icanhazip.com | cut -f1-4 -d':')

echo "Internal IP = ${IP4}. External IPv6 Subnet = ${IP6}"

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

gen_data >${WORKDIR}/data.txt
gen_iptables >${WORKDIR}/boot_iptables.sh

gen_3proxy >/usr/local/etc/3proxy/3proxy.cfg

cat >>/etc/rc.local <<EOF
bash ${WORKDIR}/boot_iptables.sh
ulimit -n 10048
/usr/local/etc/3proxy/bin/3proxy /usr/local/etc/3proxy/3proxy.cfg
EOF

chmod 0755 /etc/rc.local
bash /etc/rc.local

# Adjusted menu
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
            /usr/local/etc/3proxy/bin/3proxy /usr/local/etc/3proxy/3proxy.cfg -sstop/usr/local/etc/3proxy/bin/3proxy /usr/local/etc/3proxy/3proxy.cfg -h$IP4 -e$IPV6 -p$i
        done
        /usr/local/etc/3proxy/bin/3proxy /usr/local/etc/3proxy/3proxy.cfg
        sleep 900  # Sleep for 15 minutes (900 seconds)
    done
}

# Adjusted menu
show_menu() {
    clear
    echo "Menu:"
    echo "1. Generate and Update proxies"
    echo "2. Rotate proxies automatically"
    echo "3. Show proxy list"
    echo "4. Download proxy list"
    echo "5. Exit"
}

while true; do
    show_menu
    read -p "Choose an option (1-5): " choice

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
