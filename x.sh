#!/bin/bash

# Function to rotate IPv6 addresses
rotate_ipv6() {
    IP4=$(get_ipv4)
    IP6=$(get_ipv6)
    echo "IPv4: $IP4"
    echo "IPv6: $IP6"
    echo "Updating IPv6 addresses..."
    gen_ipv6_64
    gen_ifconfig
    service network restart
    echo "IPv6 addresses rotated and updated."
}

# Function to get IPv4 address
get_ipv4() {
    curl -4 -s icanhazip.com
}

# Function to get IPv6 address
get_ipv6() {
    curl -6 -s icanhazip.com | cut -f1-4 -d':'
}

# Function to generate IPv6 addresses
gen_ipv6_64() {
    rm "$WORKDIR/data.txt" >/dev/null 2>&1
    for port in $(seq 10000 10999); do
        ipv6_address=$(generate_ipv6_address)
        echo "$ipv6_address/$port" >> "$WORKDIR/data.txt"
    done
}

# Function to generate a random IPv6 address
generate_ipv6_address() {
    array=( 1 2 3 4 5 6 7 8 9 0 a b c d e f )
    ipv6=""
    for _ in {1..8}; do
        ipv6="${ipv6}${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}"
        ipv6="${ipv6}:"
    done
    echo "${ipv6::-1}"
}

# Function to generate ifconfig commands
gen_ifconfig() {
    while read -r line; do
        echo "ifconfig eth0 inet6 add $line"
    done < "$WORKDIR/data.txt" > "$WORKDIR/boot_ifconfig.sh"
}

# Set up variables
WORKDIR="/home/cloudfly"

# Rotate IPv6 addresses
rotate_ipv6
