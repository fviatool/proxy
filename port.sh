#!/bin/bash

# Hàm hiển thị menu
show_menu() {
    clear
    echo "=== Menu Thiết lập Chuyển tiếp Cổng NAT ==="
    echo "1. Mở cổng Port"
    echo "2. Tắt cổng Port"
    echo "3. Kiểm tra trạng thái Port"
    echo "4. Kiểm tra tất cả các cổng port đã mở"
    echo "5. Thoát"
}

# Hàm mở một cổng
open_port() {
    read -p "Nhập cổng cần mở: " port_number
    sudo ufw allow "$port_number"
    echo "Đã mở cổng $port_number."
}

# Hàm tắt một cổng
close_port() {
    read -p "Nhập cổng cần tắt: " port_number
    sudo ufw deny "$port_number"
    echo "Đã tắt cổng $port_number."
}

# Hàm kiểm tra trạng thái của một cổng
check_port_status() {
    read -p "Nhập cổng cần kiểm tra: " port_number
    sudo ufw status | grep "$port_number"
}

# Hàm kiểm tra tất cả các cổng đã mở
check_all_open_ports() {
    sudo ufw status
}

# Hàm chính
main() {
    while true; do
        show_menu
        read -p "Nhập lựa chọn của bạn: " choice

        case $choice in
            1) open_port ;;
            2) close_port ;;
            3) check_port_status ;;
            4) check_all_open_ports ;;
            5) exit ;;
            *) echo "Lựa chọn không hợp lệ. Vui lòng thử lại." ;;
        esac
        echo "Nhấn Enter để tiếp tục..."
        read
    done
}

main
