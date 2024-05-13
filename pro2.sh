#!/bin/bash

echo "Đang xoay IPv6..."
gen_ipv6_64
gen_ifconfig > "$WORKDIR/boot_ifconfig.sh"
bash "$WORKDIR/boot_ifconfig.sh"
service network restart

echo "IPv6 đã được xoay và cập nhật."
