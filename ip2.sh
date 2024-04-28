#!/bin/bash

# Tự động lấy địa chỉ IPv4 từ thiết bị
IP4=$(ip addr show | grep -oP '(?<=inet\s)192(\.\d+){2}\.\d+' | head -n 1)

# Tự động lấy địa chỉ IPv6/64
IPV6ADDR=$(ip -6 addr show | grep -oP '(?<=inet6\s)[\da-fA-F:]+(?=/64)' | head -n 1)

# Kiểm tra card mạng eth0
if ip link show eth0 &> /dev/null; then
    echo "Card mạng eth0 đã được tìm thấy."
    
    # Thiết lập cấu hình mạng cho eth0
    cat <<EOF > /etc/sysconfig/network-scripts/ifcfg-eth0
    TYPE=Ethernet
    NAME=eth0
    DEVICE=eth0
    ONBOOT=yes
    BOOTPROTO=dhcp
    IPV6_INIT=yes
    IPV6_AUTOCONF=yes
    IPV6_DEFROUTE=yes
    IPV6_FAILURE_FATAL=no
    IPV6_ADDR_GEN_MODE=eui64
    IPADDR=$IP4
    NETMASK=255.255.255.0
    GATEWAY=192.168.1.1
    DNS1=8.8.8.8
    IPV6ADDR=$IPV6ADDR/64
    IPV6_DEFAULTGW=2001:ee0:4f9b:92b0::1
EOF

    # Kiểm tra kết nối IPv6
    if ip -6 route get 2001:ee0:4f9b:92b0::8888 &> /dev/null; then
        echo "Kết nối IPv6 cho eth0 hoạt động."
    else
        echo "Lỗi: Kết nối IPv6 cho eth0 không hoạt động."
    fi

    # Cấp quyền cho địa chỉ IPv4 của eth0
    firewall-cmd --zone=public --add-source="$IP4" --permanent
    firewall-cmd --reload

# Kiểm tra card mạng ens33
elif ip link show ens33 &> /dev/null; then
    echo "Card mạng ens33 đã được tìm thấy."
    
    # Thiết lập cấu hình mạng cho ens33
    cat <<EOF > /etc/sysconfig/network-scripts/ifcfg-ens33
    TYPE=Ethernet
    NAME=ens33
    DEVICE=ens33
    ONBOOT=yes
    BOOTPROTO=dhcp
    IPV6_INIT=yes
    IPV6_AUTOCONF=yes
    IPV6_DEFROUTE=yes
    IPV6_FAILURE_FATAL=no
    IPV6_ADDR_GEN_MODE=eui64
    IPADDR=$IP4
    NETMASK=255.255.255.0
    GATEWAY=192.168.1.1
    DNS1=8.8.8.8
    IPV6ADDR=$IPV6ADDR/64
    IPV6_DEFAULTGW=2001:ee0:4f9b:92b0::1
EOF

    # Kiểm tra kết nối IPv6
    if ip -6 route get 2001:ee0:4f9b:92b0::8888 &> /dev/null; then
        echo "Kết nối IPv6 cho ens33 hoạt động."
    else
        echo "Lỗi: Kết nối IPv6 cho ens33 không hoạt động."
    fi

    # Cấp quyền cho địa chỉ IPv4 của ens33
    firewall-cmd --zone=public --add-source="$IP4" --permanent
    firewall-cmd --reload 
fi

# Khởi động lại dịch vụ mạng
sudo systemctl restart network

# Kiểm tra kết nối IPv6 bằng cách ping Google
ping6 -c 3 google.com

# Hiển thị thông tin địa chỉ mạng
ip addr show
ip route show
service network restart
ping_google6

