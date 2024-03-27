#!/bin/bash

# Get IPv6 address
ipv6_address=$(ip addr show eth0 | awk '/inet6/{print $2}' | grep -v '^fe80' | head -n1)

# Check if IPv6 address is obtained
if [ -n "$ipv6_address" ]; then
    echo "IPv6 address obtained: $ipv6_address"
    
    # Configure IPv6 settings
    echo "IPV6_ADDR_GEN_MODE=stable-privacy" >> /etc/network/interfaces
    echo "IPV6ADDR=$ipv6_address/64" >> /etc/network/interfaces
    echo "IPV6_DEFAULTGW=$(ip -6 route show default | awk '/via/{print $3}')" >> /etc/network/interfaces
    
    # Restart networking service
    service networking restart
    systemctl restart NetworkManager.service
    ifconfig eth0
    echo"Done!"
