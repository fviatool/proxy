Để kết hợp các bước trên vào một tập tin và xuất file proxy ip:port.txt, bạn có thể thực hiện như sau:#!/bin/bash

# Kiểm tra xem script được chạy với quyền root hay không
if [ "$(id -u)" != "0" ]; then
    echo "Bạn cần chạy script này với quyền root." 1>&2
    exit 1
fi

# Cập nhật danh sách gói và cài đặt Squid Proxy
apt update
apt -y install squid

# Sao lưu cấu hình Squid Proxy mặc định
mv /etc/squid/squid.conf /etc/squid/squid.conf.bak

# Tạo một tập tin cấu hình Squid Proxy mới
cat <<EOT >> /etc/squid/squid.conf
http_port 3128
http_port 8080
http_port 8888

acl localnet src 0.0.0.1-0.255.255.255
acl localnet src 10.0.0.0/8
acl localnet src 100.64.0.0/10
acl localnet src 169.254.0.0/16
acl localnet src 172.16.0.0/12
acl localnet src 192.168.0.0/16
acl localnet src fc00::/7
acl localnet src fe80::/10

acl SSL_ports port 443
acl Safe_ports port 80          # http
acl Safe_ports port 21          # ftp
acl Safe_ports port 443         # https
acl Safe_ports port 70          # gopher
acl Safe_ports port 210         # wais
acl Safe_ports port 1025-65535  # unregistered ports
acl Safe_ports port 280         # http-mgmt
acl Safe_ports port 488         # gss-http
acl Safe_ports port 591         # filemaker
acl Safe_ports port 777         # multiling http
acl CONNECT method CONNECT

http_access deny !Safe_ports
http_access deny CONNECT !SSL_ports
http_access allow localhost manager
http_access deny manager
http_access allow localnet
http_access allow localhost
http_access deny all
http_port 3128

coredump_dir /var/spool/squid
EOT

# Khởi động lại dịch vụ Squid
systemctl restart squid

echo "Cài đặt và cấu hình Squid Proxy đã hoàn tất."

# Xóa tệp cấu hình Squid hiện tại và tạo tập tin mới từ URL đã cho
rm -f /etc/squid/squid.conf
wget --no-check-certificate -O /etc/squid/squid.conf https://raw.githubusercontent.com/sc6r-develop3rr/Squid-Proxy-Multiple-Port-Script/main/squid.conf
    
# Tạo tập tin danh sách đen
touch /etc/squid/blacklist.acl
    
# Mở các cổng cho Squid
iptables -I INPUT -p tcp --dport 5000 -j ACCEPT
iptables -I INPUT -p tcp --dport 5001 -j ACCEPT
iptables -I INPUT -p tcp --dport 5002 -j ACCEPT
iptables -I INPUT -p tcp --dport 5003 -j ACCEPT
iptables -I INPUT -p tcp --dport 5004 -j ACCEPT
iptables -I INPUT -p tcp --dport 5005 -j ACCEPT
    
# Khởi động lại dịch vụ Squid
systemctl restart squid

echo "Cấu hình Squid Proxy với nhiều cổng đã được thiết lập."

# Xuất danh sách proxy ip:port
echo "Danh sách proxy ip:port:" > proxy_ip_port.txt
echo "127.0.0.1:3128" >> proxy_ip_port.txt
echo "127.0.0.1:8080" >> proxy_ip_port.txt
echo "127.0.0.1:8888" >> proxy_ip_port.txt

echo "File proxy_ip_port.txt đã được tạo."
Điều này sẽ thực hiện cài đặt và cấu hình Squid Proxy cùng với việc mở nhiều cổng và sau đó xuất danh sách proxy ip:port vào tập tin proxy_ip_port.txt.
