#!/bin/bash

# Function to rotate IPv6 addresses
rotate_ipv6() {
    IP4=$(get_ipv4)
    IP6=$(get_ipv6)
    main_interface="eth0"
    echo "IPv4: $IP4"
    echo "IPv6: $IP6"
    echo "Giao diện chính: eth0"
    gen_ipv6_64
    gen_ifconfig
    service network restart
    echo "Địa chỉ IPv6 đã được xoay và cập nhật."
}

    # Xoay địa chỉ IPv6
    gen_ipv6_64
    gen_ifconfig
    service network restart
    echo "Địa chỉ IPv6 đã được xoay và cập nhật."
}

# Function to get IPv4 address
get_ipv4() {
    IP4=$(curl -4 -s icanhazip.com)
    echo "$IP4"
}

# Function to get IPv6 address
get_ipv6() {
    IP6=$(curl -6 -s icanhazip.com | cut -f1-4 -d':')
    echo "$IP6"
}

# Function to generate IPv6 addresses
gen_ipv6_64() {
    rm "$WORKDIR/data.txt"
    for port in $(seq 10000 10999); do
        array=( 1 2 3 4 5 6 7 8 9 0 a b c d e f )
        ip64() {
            echo "${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}"
        }
        echo "$IP6:$(ip64):$(ip64):$(ip64):$(ip64):$(ip64)/$port" >> "$WORKDIR/data.txt"
    done
}

# Function to generate ifconfig commands
gen_ifconfig() {
    while read -r line; do
        echo "ifconfig $IFCFG inet6 add $line"
    done < "$WORKDIR/data.txt" > "$WORKDIR/boot_ifconfig.sh"
}

# Set up variables
WORKDIR="/home/cloudfly"
IFCFG="eth0"

# Rotate IPv6 addresses
rotate_ipv6
