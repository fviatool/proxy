#!/bin/bash

# Get interface name with default route
interface_name=$(ip -6 route show default | awk '/dev/ {print $5}')

# Check if interface name is obtained
if [ -n "$interface_name" ]; then
    echo "Interface name obtained: $interface_name"
    
    # Get IPv6 address
    ipv6_address=$(ip addr show "$interface_name" | awk '/inet6/{print $2}' | grep -v '^fe80' | head -n1)

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
        ifconfig "$interface_name"
        echo "Done!"
    else
        echo "Error: No IPv6 address obtained for interface $interface_name"
    fi
else
    echo "Error: No interface name obtained with default route"
fi
