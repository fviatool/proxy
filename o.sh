#!/bin/bash

# Function to generate a random IPv6 address segment
ip64() {
    echo "${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}"
}

# Function to generate a full IPv6 address
gen64() {
    echo "$1:$(ip64):$(ip64):$(ip64):$(ip64)"
}

# Function to generate ifconfig commands for IPv4 and save to file
gen_ifconfig_ipv4() {
    local port=$1
    local ipv4=$2
    echo "ifconfig eth0 inet add $ipv4 port $port"
}

# Function to generate ifconfig commands for IPv6 and save to file
gen_ifconfig_ipv6() {
    local port=$1
    local ipv6=$2
    echo "ifconfig eth0 inet6 add $ipv6/64 port $port"
}

# Generate IPv6 addresses and save to file
generate_ipv6_addresses() {
    local ipv6_prefix="$1"
    local port_count=$2
    for ((i = 0; i < $port_count; i++)); do
        local ipv6_address="$ipv6_prefix:$(ip64):$(ip64):$(ip64):$(ip64)"
        echo "$ipv6_address"
    done
}

# Main script
WORKDIR="home/cloudfly"  # Change directory path if needed
mkdir -p "$WORKDIR" && cd "$WORKDIR" || exit
PORT_COUNT=100
IPv4="192.168.1.151"  # Change to your desired IPv4 address
IPv6_PREFIX="2001:db8:abcd"  # Change to your desired IPv6 prefix

# Array containing hex values from 0 to f
array=(0 1 2 3 4 5 6 7 8 9 a b c d e f)

# Generate IPv6 addresses and save to file
generate_ipv6_addresses "$IPv6_PREFIX" "$PORT_COUNT" > ipv6_addresses.txt

# Generate ifconfig commands for IPv4 and save to file
port=10000  # Starting port
for ((i = 0; i < $PORT_COUNT; i++)); do
    gen_ifconfig_ipv4 "$port" "$IPv4" >> boot_ifconfig.sh
    ((port++))
done

# Generate ifconfig commands for IPv6 and save to file
port=10000  # Starting port
while IFS= read -r ipv6_address; do
    gen_ifconfig_ipv6 "$port" "$ipv6_address" >> boot_ifconfig.sh
    ((port++))
done < ipv6_addresses.txt

# Grant permission and execute boot_ifconfig.sh
chmod +x boot_ifconfig.sh
./boot_ifconfig.sh
