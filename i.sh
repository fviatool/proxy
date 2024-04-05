#!/bin/bash

ipv4=$(curl -4 -s icanhazip.com)
IPC=$(echo "$ipv4" | cut -d"." -f3)
IPD=$(echo "$ipv4" | cut -d"." -f4)
INT=$(ls /sys/class/net | grep e)

if [ "$IPC" = "4" ]; then
    IPV6_ADDRESS="2001:ee0:4f9b::$IPD:0000/64"
    GATEWAY="2001:ee0:4f9b:92b0::1"
elif [ "$IPC" = "5" ]; then
    IPV6_ADDRESS="2001:ee0:4f9b::$IPD:0000/64"
    GATEWAY="2001:ee0:4f9b:92b0::1"
elif [ "$IPC" = "244" ]; then
    IPV6_ADDRESS="2001:ee0:4f9b::$IPD:0000/64"
    GATEWAY="2001:ee0:4f9b:92b0::1"
else
    IPV6_ADDRESS="2001:ee0:0:$IPC::$IPD:0000/64"
    GATEWAY="2001:ee0:0:$IPC::1"
fi

# Kiểm tra xem tệp cấu hình Netplan có tồn tại không trước khi thay đổi nó
NETPLAN_PATH="/etc/netplan/99-netcfg-vmware.yaml"  
if [ -f "$NETPLAN_PATH" ]; then
    NETPLAN_CONFIG=$(cat "$NETPLAN_PATH")
    
    NEW_NETPLAN_CONFIG=$(sed "/gateway4:/i \ \ \ \ \ \ \  - $IPV6_ADDRESS" <<< "$NETPLAN_CONFIG")
    NEW_NETPLAN_CONFIG=$(sed "/gateway4:.*/a \ \ \ \ \  gateway6: $GATEWAY" <<< "$NEW_NETPLAN_CONFIG")

    echo "$NEW_NETPLAN_CONFIG" > "$NETPLAN_PATH"

    # Áp dụng cấu hình Netplan
    sudo netplan apply
else
    echo "Tệp cấu hình Netplan không tồn tại."
fi

# Configure IPv6 settings
echo "IPV6_ADDR_GEN_MODE=stable-privacy" >> /etc/network/interfaces
echo "IPV6ADDR=$IPV6_ADDRESS/64" >> /etc/network/interfaces
echo "IPV6_DEFAULTGW=$GATEWAY" >> /etc/network/interfaces

# Restart networking service
service networking restart
