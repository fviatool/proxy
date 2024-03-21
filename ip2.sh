#!/bin/sh

# Thêm cấu hình IPv6 mới vào tệp sysctl.conf
cat <<EOF >> /etc/sysctl.conf
net.ipv6.conf.default.disable_ipv6 = 0
net.ipv6.conf.all.disable_ipv6 = 0
EOF

# Tải lại cấu hình từ sysctl.conf
sysctl -p

# Kiểm tra xem địa chỉ IP của bạn là IPv4 hay IPv6
if [ $(curl -4 -s icanhazip.com) ]; then
    # Lấy địa chỉ IPv6 và gateway từ lệnh ip
    IPV6ADDR=$(ip -6 addr show dev eth0 | grep inet6 | awk '{print $2}' | grep -v '^fe80' | cut -d'/' -f1)
    IPV6_DEFAULTGW=$(ip -6 route show default | awk '/via/ {print $3}')

    # Thêm cấu hình IPv6 vào tệp cấu hình của giao diện mạng
    echo "IPV6_FAILURE_FATAL=no
    IPV6_ADDR_GEN_MODE=stable-privacy
    IPV6ADDR=$IPV6ADDR/64
    IPV6_DEFAULTGW=$IPV6_DEFAULTGW" >> /etc/sysconfig/network-scripts/ifcfg-eth0

    # Khởi động lại dịch vụ mạng để áp dụng cấu hình mới
    service network restart
fi

# Xóa script sau khi thực thi xong
rm -rf ip2.sh
