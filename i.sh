#!/bin/sh

echo > /etc/sysctl.conf
##
tee -a /etc/sysctl.conf <<EOF
net.ipv6.conf.default.disable_ipv6 = 0
net.ipv6.conf.all.disable_ipv6 = 0
EOF
##

sysctl -p

ipv4Local="192.168.1.9"

IPC=$(echo $ipv4Local | cut -d"." -f3)
IPD=$(echo $ipv4Local | cut -d"." -f4)

# Định nghĩa địa chỉ IPv6 dựa trên phần thứ 3 của địa chỉ IPv4
if [ $IPC == 4 ]; then
    IPV6_ADDRESS="2001:4860:4860::$IPD:0000/64"
    GATEWAY="2402:800:6234:a0af::1"
elif [ $IPC == 5 ]; then
    IPV6_ADDRESS="2001:4860:4860::$IPD:0000/64"
    GATEWAY="2402:800:6234:a0af::1"
elif [ $IPC == 244 ]; then
    IPV6_ADDRESS="2001:4860:4860::$IPD:0000/64"
    GATEWAY="2402:800:6234:a0af::1"
else
    IPV6_ADDRESS="2001:4860:4860::$IPC::$IPD:0000/64"
    GATEWAY="2001:ee0:4f9b:92b0:$IPC::1"
fi

INTERFACE="eth0"  # Thay thế bằng tên giao diện mạng của bạn

# Tạo tệp cấu hình cho giao diện mạng
cat <<EOF > /etc/sysconfig/network-scripts/ifcfg-eth0
IPV6INIT=yes
IPV6_AUTOCONF=no
IPV6_DEFROUTE=yes
IPV6_FAILURE_FATAL=no
IPV6_ADDR_GEN_MODE=stable-privacy
IPV6ADDR=$IPV6_ADDRESS
IPV6_DEFAULTGW=$GATEWAY
EOF

# Khởi động lại dịch vụ mạng để áp dụng cấu hình mới
service network restart

# In ra thông báo sau khi đã tạo thành công địa chỉ IPv6
echo 'Đã tạo IPv6 thành công!'

# Xóa script sau khi thực thi
rm -rf i.sh
