#!/bin/bash
############################################################
# Squid Proxy Installer
############################################################

if [ "$(whoami)" != root ]; then
	echo "ERROR: Bạn cần chạy script với quyền root hoặc user có quyền sudo."
	exit 1
fi

# Lấy danh sách các IP hiện có
IP4=$(/sbin/ip -4 -o addr show scope global | awk '{gsub(/\/.*/,"",$4); print $4}' | sed 's/ /\n/g')
IP6=$(/sbin/ip -6 -o addr show scope global | awk '{gsub(/\/.*/,"",$4); print $4}' | sed 's/ /\n/g')

if [ -z "$IP6" ]; then
    echo "Server chưa có IPv6, vui lòng liên hệ support@vinahost.vn hoặc truy cập https://livechat.vinahost.vn/chat.php để được hỗ trợ"
else
    /usr/bin/wget --no-check-certificate -O /usr/local/bin/find-os https://gitlab.com/hungmv/squid-proxy/-/raw/master/find-os.sh >> squid-install.log 2>&1
    chmod 755 /usr/local/bin/find-os

    /usr/bin/wget --no-check-certificate -O /usr/local/bin/squid-uninstall https://gitlab.com/hungmv/squid-proxy/-/raw/master/squid-uninstall.sh >> squid-install.log 2>&1
    chmod 755 /usr/local/bin/squid-uninstall

    /usr/bin/wget --no-check-certificate -O /usr/local/bin/squid-add-user https://gitlab.com/hungmv/squid-proxy/-/raw/master/squid-add-user.sh >> squid-install.log 2>&1 
    chmod 755 /usr/local/bin/squid-add-user 

    if [[ -d /etc/squid/ || -d /etc/squid3/ ]]; then
        echo "Squid Proxy đã được cài đặt. Nếu bạn muốn cài đặt lại, hãy trước tiên gỡ bỏ squid proxy bằng lệnh: squid-uninstall"
        exit 1
    fi

    # Lưu thông tin ngày vào file log
    echo "Date: $(date)" >> squid-install.log

    if cat /etc/os-release | grep PRETTY_NAME | grep "Ubuntu 22.04"; then
        # Cấu hình Squid cho Ubuntu 22.04
    elif cat /etc/os-release | grep PRETTY_NAME | grep "Ubuntu 20.04"; then
        # Cấu hình Squid cho Ubuntu 20.04
    elif cat /etc/os-release | grep PRETTY_NAME | grep "Ubuntu 18.04"; then
        # Cấu hình Squid cho Ubuntu 18.04
    elif cat /etc/os-release | grep PRETTY_NAME | grep "jessie"; then
        # Cấu hình Squid cho Debian 8
    elif cat /etc/os-release | grep PRETTY_NAME | grep "stretch"; then
        # Cấu hình Squid cho Debian 9
    elif cat /etc/os-release | grep PRETTY_NAME | grep "buster"; then
        # Cấu hình Squid cho Debian 10
    elif cat /etc/os-release | grep PRETTY_NAME | grep "CentOS Linux 7"; then
        # Cấu hình Squid cho CentOS 7
    elif cat /etc/os-release | grep PRETTY_NAME | grep "CentOS Linux 8"; then
        # Cấu hình Squid cho CentOS 8
    else
        echo "Hệ điều hành không được hỗ trợ."
        exit 1;
    fi

    # Tạo và cấu hình người dùng và proxy cho IPv6
    USER_FILE="/root/users.txt"
    > "$USER_FILE"
    SQUID_CONFIG="\n"
    for ip in "${IP6[@]}"; do
        ACL_NAME="proxy_ip_${ip//\./_}"
        SQUID_CONFIG+="acl ${ACL_NAME} myip ${IP4}\n"
        SQUID_CONFIG+="tcp_outgoing_address ${ip} ${ACL_NAME}\n\n"
    done

    # Tạo tên người dùng và mật khẩu ngẫu nhiên
    USERNAME=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 10)
    PASSWORD=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 16)

    # Ghi thông tin người dùng vào file
    echo "$USERNAME,$PASSWORD,${IP_ADDR}" >> $USER_FILE

    # Tạo người dùng và mật khẩu cho Squid
    /usr/bin/htpasswd -b /etc/squid/passwd $USERNAME $PASSWORD

    # Cập nhật cấu hình Squid với IPv6
    echo -e $SQUID_CONFIG >> /etc/squid/squid.conf
    systemctl restart squid

echo

echo "Xem thông tin đăng nhập tại file /root/users.txt"

fi
