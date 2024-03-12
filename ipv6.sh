#!/bin/bash
YUM=$(which yum)
#####
if [ "$YUM" ]; then
echo > /etc/sysctl.conf
##
tee -a /etc/sysctl.conf <<EOF
net.ipv6.conf.default.disable_ipv6 = 0
net.ipv6.conf.all.disable_ipv6 = 0
EOF
##
sysctl -p
IPC=$(curl -4 -s icanhazip.com | cut -d"." -f3)
IPD=$(curl -4 -s icanhazip.com | cut -d"." -f4)

if [ $IPC == 4 ]; then
    IPV6_ADDRESS="2403:6a40:0:40::$IPD:0000/64"
    GATEWAY="2403:6a40:0:40::1"
elif [ $IPC == 5 ]; then
    IPV6_ADDRESS="2403:6a40:0:40::$IPD:0000/64"
    GATEWAY="2403:6a40:0:40::1"
elif [ $IPC == 244 ]; then
    IPV6_ADDRESS="2403:6a40:0:40::$IPD:0000/64"
    GATEWAY="2403:6a40:0:40::1"
else
    IPV6_ADDRESS="2403:6a40:0:40:$IPC::$IPD:0000/64"
    GATEWAY="2403:6a40:0:$IPC::1"
fi

INTERFACE="eth0"  # Thay thế bằng tên giao diện mạng của bạn

cat <<EOF > /etc/sysconfig/network-scripts/ifcfg-$INTERFACE
IPV6INIT=yes
IPV6_AUTOCONF=no
IPV6_DEFROUTE=yes
IPV6_FAILURE_FATAL=no
IPV6_ADDR_GEN_MODE=stable-privacy
IPV6ADDR=$IPV6_ADDRESS
IPV6_DEFAULTGW=$GATEWAY
EOF

service network restart

echo 'Đã tạo IPv6 thành công!'
