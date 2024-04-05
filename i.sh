#!/bin/bash

# Kiểm tra xem có sự tồn tại của mô-đun IPv6 trong kernel hay không
if lsmod | grep -q '^ipv6\s'; then
    echo "IPv6 module is already loaded"
else
    # Nếu mô-đun IPv6 chưa được tải, hãy tải nó lên
    modprobe ipv6
    echo "IPv6 module loaded"
fi

# Thiết lập cấu hình mặc định cho IPv6
sysctl -w net.ipv6.conf.all.disable_ipv6=0
sysctl -w net.ipv6.conf.default.disable_ipv6=0

# Kiểm tra xem địa chỉ IPv6 đã được cấu hình hay chưa
if ip -6 address show | grep -q 'inet6'; then
    echo "IPv6 address already configured"
else
    # Nếu chưa có địa chỉ IPv6, hãy tạo một địa chỉ IPv6 mới
    ip -6 address add 2001:ee0:4f9b:92b0::1/64 dev eth0
    echo "IPv6 address configured"
fi

# Kiểm tra xem đã có gateway IPv6 được cấu hình hay chưa
if ip -6 route show default | grep -q 'via'; then
    echo "IPv6 default gateway already configured"
else
    # Nếu chưa có gateway IPv6, hãy thêm một gateway IPv6 mới
    ip -6 route add default via 2001:ee0:4f9b:92b0::1 dev eth0
    echo "IPv6 default gateway configured"
fi
service networking restart
