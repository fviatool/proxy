#!/bin/bash

# Define the IPv6 address and gateway
read -p "Enter your IPv6 address: " IPV6ADDR
read -p "Enter your IPv6 gateway: " IPV6_DEFAULTGW

# Check if IPv6 is enabled in sysctl.conf
ipv6_enabled=$(grep -c "^net.ipv6.conf.default.disable_ipv6 = 0" /etc/sysctl.conf)

if [ "$ipv6_enabled" -eq 0 ]; then
    echo "net.ipv6.conf.default.disable_ipv6 = 0" >> /etc/sysctl.conf
    echo "net.ipv6.conf.all.disable_ipv6 = 0" >> /etc/sysctl.conf
    echo "IPv6 enabled in sysctl.conf"
fi

# Check if network interfaces are configured for IPv6
interfaces_configured=$(grep -c "^IPV6_FAILURE_FATAL=no" /etc/network/interfaces)

if [ "$interfaces_configured" -eq 0 ]; then
    echo "IPV6_FAILURE_FATAL=no" >> /etc/network/interfaces
    echo "IPV6_ADDR_GEN_MODE=stable-privacy" >> /etc/network/interfaces
    echo "IPV6ADDR=$IPV6ADDR/64" >> /etc/network/interfaces
    echo "IPV6_DEFAULTGW=$IPV6_DEFAULTGW" >> /etc/network/interfaces
    service networking restart
    echo "IPv6 interfaces configured"
fi
    echo"ifconfig eth0"
