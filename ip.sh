#!/bin/bash

# Kiểm tra card mạng eth0
if ip link show eth0 &> /dev/null; then
    echo "Card mang eth0 !"
    
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
IPV6ADDR=2001:ee0:4f9b:92b0::75:0000/64
IPV6_DEFAULTGW=2001:ee0:4f9b:92b0::1
EOF

    # Kiểm tra kết nối IPv6
    if ip -6 route get 2001:ee0:4f9b:92b0::8888 &> /dev/null; then
        echo "Ket Noi ipv6 eth0 start."
    else
        echo "Lỗi: Kết nối IPv6 cho eth0 không hoạt động."
    fi

    # Cấp quyền cho địa chỉ IPv4 của eth0
    firewall-cmd --zone=public --add-source=192.168.1.17 --permanent
    firewall-cmd --reload

# Kiểm tra card mạng ens33
elif ip link show ens33 &> /dev/null; then
    echo "Card mang ens33 !"
    
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
IPV6ADDR=2001:ee0:4f9b:92b0::75:0000/64
IPV6_DEFAULTGW=2001:ee0:4f9b:92b0::1
EOF

    # Kiểm tra kết nối IPv6
    if ip -6 route get 2001:ee0:4f9b:92b0::8888 &> /dev/null; then
        echo "Ket Noi ipv6 ens33 Start"
    else
        echo "Lỗi: Kết nối IPv6 cho ens33 không hoạt động."
    fi

    # Cấp quyền cho địa chỉ IPv4 của ens33
    firewall-cmd --zone=public --add-source=192.168.1.17 --permanent
    firewall-cmd --reload 

else
    echo "Không tìm thấy card mạng eth0 hoặc ens33."
fi

# Khởi động lại dịch vụ mạng
sudo systemctl restart network

# Ping google.com bằng IPv6
ping_google6() {
    ping6 -c 3 google.com
}

# Đếm tổng số địa chỉ IPv6 trên máy chủ
ip -6 addr | grep inet6 | wc -l

# Kiểm tra kết nối IPv6 bằng cách ping Google
ping_google6
