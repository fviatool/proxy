#!/bin/bash

# Lấy tên giao diện mạng
interface_name=$(ip -o link show | awk -F': ' '{print $2}')

# Lấy địa chỉ IPv6 của giao diện mạng đầu tiên
ipv6_address=$(ip -6 addr show dev "$interface_name" | grep inet6 | awk '{print $2}' | head -n1)

# Kiểm tra xem có địa chỉ IPv6 nào được tìm thấy không
if [ -z "$ipv6_address" ]; then
    echo "Không tìm thấy địa chỉ IPv6 trên giao diện $interface_name"
    exit 1
fi

# Lấy địa chỉ gateway IPv6 từ routing table
gateway6_address=$(ip -6 route show | grep default | awk '{print $3}')

# Kiểm tra xem có gateway IPv6 nào được tìm thấy không
if [ -z "$gateway6_address" ]; then
    echo "Không tìm thấy gateway IPv6"
    exit 1
fi

# Đường dẫn đến tệp cấu hình Netplan
netplan_path="/etc/netplan"

# Kiểm tra và cập nhật cấu hình Netplan cho các phiên bản Ubuntu khác nhau
if [ -d "$netplan_path" ]; then
    if [ -f "$netplan_path/01-netcfg.yaml" ]; then
        netplan_config="$netplan_path/01-netcfg.yaml"
    elif [ -f "$netplan_path/50-cloud-init.yaml" ]; then
        netplan_config="$netplan_path/50-cloud-init.yaml"
    elif [ -f "$netplan_path/99-netcfg.yaml" ]; then
        netplan_config="$netplan_path/99-netcfg.yaml"
    else
        echo "Không tìm thấy tệp cấu hình Netplan"
        exit 1
    fi
else
    echo "Thư mục $netplan_path không tồn tại"
    exit 1
fi

# Tạo đoạn cấu hình IPv6 mới
new_netplan_config=$(cat "$netplan_config")
new_netplan_config+="\n      - $ipv6_address"
new_netplan_config+="\n  gateway6: $gateway6_address"

# Ghi đè cấu hình Netplan
echo -e "$new_netplan_config" > "$netplan_config"

# Áp dụng cấu hình Netplan
netplan apply
