#!/bin/bash

WORKDIR="/home/cloudfly"
WORKDATA="${WORKDIR}/data.txt"

rotate_ipv6() {
    echo "Xoay địa chỉ IPv6..."
    new_ipv6=$(get_new_ipv6)
    update_3proxy_config "$new_ipv6"
    service 3proxy restart
    echo "3proxy khởi động lại thành công."
    echo "Xoay IPv6 hoàn tất."
}

get_new_ipv6() {
    random_ipv6=$(openssl rand -hex 8 | sed 's/\(..\)/:\1/g; s/://1')
    echo "$random_ipv6"
}

update_3proxy_config() {
    new_ipv6=$1
    sed -i "s/old_ipv6_address/$new_ipv6/" /usr/local/etc/3proxy/3proxy.cfg
}

add_rotation_cronjob() {
    echo "*/10 * * * * root ${WORKDIR}/rotate_proxies.sh" >> /etc/crontab
    echo "Đã thêm cronjob cho xoay IPv6 mỗi 10 phút."
}
# Tự động xoay proxy sau mỗi 10 phút
(crontab -l ; echo "*/10 * * * * ${WORKDIR}/rotate_proxies.sh") | crontab -

display_proxy_list() {
    echo "Hiển thị danh sách proxy:"
    cat proxy.txt
}

main_menu() {
    echo "Menu tạo và xoay proxy IPv6"
    echo "---------------------------"

    while true; do
        echo "1. Xoay proxy IPv6"
        echo "2. Hiển thị danh sách proxy"
        echo "3. Thoát"

        read -p "Chọn một tùy chọn (1-3): " choice

        case $choice in
            1)
                rotate_ipv6
                ;;
            2)
                display_proxy_list
                ;;
            3)
                echo "Chọn 3: Thoát"
                echo "Tạm biệt!"
                exit 0
                ;;
            *)
                echo "Lựa chọn không hợp lệ. Vui lòng chọn từ 1 đến 3"
                ;;
        esac
    done
}

# Gọi hàm main_menu để bắt đầu chương trình
main_menu
