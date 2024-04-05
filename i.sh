#!/bin/bash
ipv4=$(curl -4 -s icanhazip.com)
IPC=$(curl -4 -s icanhazip.com | cut -d"." -f3)
IPD=$(curl -4 -s icanhazip.com | cut -d"." -f4)
INT=$(ls /sys/class/net | grep -E 'e(n)?s[0-9]+$')

if [ "$IPC" = "4" ]; then
	IPV6_ADDRESS="2001:ee0:4f9b::$IPD:0000/64"
	PREFIX_LENGTH="64"
	GATEWAY="2001:ee0:4f9b:92b0::1"
elif [ "$IPC" = "5" ]; then
	IPV6_ADDRESS="2001:ee0:4f9b::$IPD:0000/64"
	PREFIX_LENGTH="64"
	GATEWAY="2001:ee0:4f9b:92b0::1"
elif [ "$IPC" = "244" ]; then
	IPV6_ADDRESS="2001:ee0:4f9b::$IPD:0000/64"
	PREFIX_LENGTH="64"
	GATEWAY="2001:ee0:4f9b:92b0::1"
else
	IPV6_ADDRESS="2001:ee0:0:$IPC::$IPD:0000/64"
	PREFIX_LENGTH="64"
	GATEWAY="2001:ee0:0:$IPC::1"
fi

interface_name="$INT"  # Thay thế bằng tên giao diện mạng của bạn
ipv6_address="$IPV6_ADDRESS"
gateway6_address="$GATEWAY"

if [ -n "$INT" ]; then
	netplan_path="/etc/netplan/"
	if [ -f "$netplan_path/99-netcfg-vmware.yaml" ]; then
		netplan_config="$netplan_path/99-netcfg-vmware.yaml"
	elif [ -f "$netplan_path/50-cloud-init.yaml" ]; then
		netplan_config="$netplan_path/50-cloud-init.yaml"
	else
		echo 'Không tìm thấy tệp cấu hình Netplan phù hợp'
		exit 1
	fi

	# Đọc nội dung của tệp cấu hình Netplan
	netplan_content=$(<"$netplan_config")

	# Thêm địa chỉ IPv6 mới vào tệp cấu hình Netplan
	new_netplan_content=$(sed "/gateway4:/i \ \ \ \ \ \ \  - $ipv6_address" <<< "$netplan_content")

	# Thêm địa chỉ Gateway IPv6 vào tệp cấu hình Netplan
	new_netplan_content=$(sed "/gateway4:.*/a \ \ \ \ \  gateway6: $gateway6_address" <<< "$new_netplan_content")

	# Ghi lại nội dung mới vào tệp cấu hình Netplan
	echo "$new_netplan_content" > "$netplan_config"

	# Áp dụng cấu hình Netplan
	sudo netplan apply
else
	echo 'Không tìm thấy card mạng phù hợp'
fi
