#!/bin/bash

# Function to get network interface name
get_interface_name() {
    # Check if eth0 exists
    if ip link show eth0 &> /dev/null; then
        echo "eth0"
    # Check if ens33 exists
    elif ip link show ens33 &> /dev/null; then
        echo "ens33"
    # Check if ens32 exists
    elif ip link show ens32 &> /dev/null; then
        echo "ens32"
    # Add more checks for other interface names if needed
    else
        echo "Cannot determine network interface name."
        exit 1
    fi
}

# Function to get public IPv4 address
get_ipv4() {
    curl -4 -s icanhazip.com
}

# Function to update IPv6 configuration
update_ipv6() {
    local ipv4="$1"
    local ipc="$(echo $ipv4 | cut -d'.' -f3)"
    local ipd="$(echo $ipv4 | cut -d'.' -f4)"
    
    local ipv6_address=""
    local gateway6_address=""
    local interface_name="$(get_interface_name)"

    if [ "$ipc" = "4" ]; then
        ipv6_address="2403:6a40:0:40::$ipd:0000/64"
        gateway6_address="2403:6a40:0:40::1"
    elif [ "$ipc" = "5" ]; then
        ipv6_address="2403:6a40:0:41::$ipd:0000/64"
        gateway6_address="2403:6a40:0:41::1"
    elif [ "$ipc" = "244" ]; then
        ipv6_address="2403:6a40:2000:244::$ipd:0000/64"
        gateway6_address="2403:6a40:2000:244::1"
    else
        ipv6_address="2403:6a40:0:$ipc::$ipd:0000/64"
        gateway6_address="2403:6a40:0:$ipc::1"
    fi

    # Update IPv6 configuration
    sed -i "/^IPV6ADDR/c IPV6ADDR=$ipv6_address" "/etc/sysconfig/network-scripts/ifcfg-$interface_name"
    sed -i "/^IPV6_DEFAULTGW/c IPV6_DEFAULTGW=$gateway6_address" "/etc/sysconfig/network-scripts/ifcfg-$interface_name"

    # Apply changes
    if [ -x "$(command -v systemctl)" ]; then
        sudo systemctl restart network
    elif [ -x "$(command -v service)" ]; then
        sudo service network restart
    else
        echo "Cannot restart network service."
        exit 1
    fi
}

# Function to ping6 Google
ping_google6() {
    ping6 -c 3 google.com
}

# Get IPv4 address
ipv4_address=$(get_ipv4)

# Check if IPv4 address is valid
if [[ -n "$ipv4_address" ]]; then
    echo "IPv4 Address: $ipv4_address"
    update_ipv6 "$ipv4_address"
    echo "IPv6 configuration updated successfully."
    echo "Pinging Google over IPv6..."
    ping_google6
else
    echo "Failed to retrieve valid IPv4 address."
    exit 1
fi
