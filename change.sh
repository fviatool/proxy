#!/bin/bash

# Hàm để nhận diện hệ điều hành và phiên bản của nó
detectOS() {
    if [[ -f /etc/os-release ]]; then
        # freedesktop.org and systemd
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
    elif type lsb_release >/dev/null 2>&1; then
        # linuxbase.org
        OS=$(lsb_release -si)
        VER=$(lsb_release -sr)
    elif [[ -f /etc/lsb-release ]]; then
        # For some versions of Debian/Ubuntu without lsb_release command
        . /etc/lsb-release
        OS=$DISTRIB_ID
        VER=$DISTRIB_RELEASE
    elif [[ -f /etc/debian_version ]]; then
        # Older Debian/Ubuntu/etc.
        OS=Debian
        VER=$(cat /etc/debian_version)
    elif [[ -f /etc/redhat-release ]]; then
        # Older Red Hat, CentOS, etc.
        OS=RedHat
        VER=$(cat /etc/redhat-release | grep -oE '[0-9]+' | head -1)
    else
        # Fall back to uname, e.g. "Linux <version>", also works for BSD, etc.
        OS=$(uname -s)
        VER=$(uname -r)
    fi
}

# Hàm để cài đặt Subnetcalc và xác định card mạng
installAndDetectNetworkCard() {
    if [[ "$OS" = "CentOS Linux" || "$OS" = "RedHat" ]]; then
        yum install -y subnetcalc > /dev/null
        network_card=$(ip -o link show | awk '$2 !~ "lo|vir|wl" {print $2}' | cut -d: -f1 | head -1)
    elif [[ "$OS" = "Ubuntu" && ("$VER" = "18.04" || "$VER" = "20.04") ]]; then
        apt-get install -y subnetcalc > /dev/null
        network_card=$(ip -o link show | awk '$2 !~ "lo|vir|wl" {print $2}' | cut -d: -f1 | head -1)
    else
        echo "Hệ điều hành không được hỗ trợ."
        exit 1
    fi
}

# Hàm để hiển thị menu và lựa chọn hành động
showMenuAndGetSelection() {
    echo -e "======== CÀI ĐẶT IPV6 BỞI LowendViet ========"
    echo -e "======== Chọn mục MENU tương ứng ========"
    echo -e "1. Hiển thị IPv6 hiện tại."
    echo -e "2. Thay đổi IPv6."
    echo -e "3. Kiểm tra IPv6 hoạt động."
    echo -e "4. Thoát."
    read -p "Chọn: " selection
}

# Hàm để hiển thị IPv6 hiện tại
showCurrentIPv6() {
    currentIPv6=$(ip addr show dev $network_card | sed -e's/^.*inet6 \([^ ]*\).*$/\1/;t;d' | grep -v fe80)
    echo "$currentIPv6" | while IFS= read -r line ;
    do
        prefix=$(subnetcalc $line | grep Network | cut -d "=" -f2 | cut -d "/" -f1 | awk '{$1=$1};1')
        ipv6mask=$(echo $line | cut -d "/" -f2)
        echo -e "    IPv6:" $line;
        echo "    Prefix: "$prefix
        echo "    Netmask: "$ipv6mask
    done
}

# Hàm để thay đổi IPv6
changeIPv6() {
    echo -e "Nhập địa chỉ IPv6:"
    read ipv6
    echo -e "Nhập IPv6 netmask:"
    read ipv6mask
    if [[ -z "$ipv6mask" ]]; then
        ipv6mask="64"
    fi
    ipv6="${ipv6}/${ipv6mask}"
    
    echo "Địa chỉ IPv6 mới: $ipv6"
    echo "Netmask IPv6 mới: $ipv6mask"
    echo "Vui lòng kiểm tra và xác nhận thông tin trước khi tiếp tục."
    
    read -p "Xác nhận thay đổi? (y/n): " confirm
    if [[ "$confirm" == "y" ]]; then
        if [[ "$OS" = "CentOS Linux" || "$OS" = "RedHat" ]]; then
            if grep -q IPV6ADDR "/etc/sysconfig/network-scripts/ifcfg-$network_card"; then
                sed -i "/IPV6ADDR=/c\IPV6ADDR=${ipv6}" "/etc/sysconfig/network-scripts/ifcfg-$network_card"
            else
                echo -e 'IPV6INIT="yes"' >> "/etc/sysconfig/network-scripts/ifcfg-$network_card"
                echo -e 'IPV6_AUTOCONF="no"' >> "/etc/sysconfig/network-scripts/ifcfg-$network_card"
                echo -e "IPV6ADDR=${ipv6}" >> "/etc/sysconfig/network-scripts/ifcfg-$network_card"
            fi
        fi
        systemctl restart network
        echo "IPv6 đã được thay đổi và hệ thống đã được khởi động lại."
        echo "Đang kiểm tra kết nối IPv6..."
        checkIPv6
    else
        echo "Thay đổi đã bị hủy."
    fi
}

# Hàm để kiểm tra IPv6 hoạt động
checkIPv6() {
    ping6 ipv6.google.com -c4
}

# Chương trình chính
main() {
    detectOS
    installAndDetectNetworkCard

    selection="1000"

    while [[ $selection -ne 4 ]] ; do
        showMenuAndGetSelection
        case $selection in
            1) showCurrentIPv6 ;;
            2) changeIPv6 ;;
            3) checkIPv6 ;;
            4) echo "Thoát." ;;
            *) echo "Lựa chọn không hợp lệ." ;;
        esac
    done
}

# Chạy chương trình chính
main
