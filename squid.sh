#!/bin/bash

ipv6_subnet_full="$1"
net_interface="$2"
pool_name="$3"
number_ipv6="${4:-250}"
unique_ip="${5:-1}"
start_port="${6:-32000}"

sh_add_ip="add_ip_${pool_name}.sh"

gen_ipv6() {
    network="$1"
    ipv6=$(openssl rand -hex 8 | sed 's/\(..\)/\1:/g; s/.$//')
    echo "${ipv6}${network}"
}

add_ipv6() {
    num_ips="$1"
    unique_ip="$2"
    network2="$ipv6_subnet_full"
    list_network2=($(ipv6calc -s "$network2" | awk '{print $4}'))
    list_ipv6=()

    if [ -f "$sh_add_ip" ]; then
        rm "$sh_add_ip"
        echo "$sh_add_ip exists. Removed"
    fi

    if [ "$unique_ip" -eq 1 ]; then
        subnet=$(shuf -e "${list_network2[@]}" -n "$num_ips")

        for sub in $subnet; do
            ipv6=$(gen_ipv6 "$sub")
            list_ipv6+=("$ipv6")

            cmd="ip -6 addr add ${ipv6}/64 dev ${net_interface}"

            echo "$cmd" >> "$sh_add_ip"
        done
    else
        subnet=$(shuf -e "${list_network2[@]}" -n 10)

        for ((i = 0; i < num_ips; i++)); do
            sub=${subnet[$(($i % 10))]}
            ipv6=$(gen_ipv6 "$sub")
            list_ipv6+=("$ipv6")

            cmd="ip -6 addr add ${ipv6}/64 dev ${net_interface}"

            echo "$cmd" >> "$sh_add_ip"
        done
    fi

    echo "${list_ipv6[@]}"
}

cfg_squid="
max_filedesc 500000
pid_filename /usr/local/squid/var/run/${pool_name}.pid
access_log none
cache_store_log none
# Hide client ip #
forwarded_for delete
# Turn off via header #
via off
# Deny request for original source of a request
follow_x_forwarded_for allow localhost
follow_x_forwarded_for deny all
# See below
request_header_access X-Forwarded-For deny all
request_header_access Authorization allow all
request_header_access Proxy-Authorization allow all
request_header_access Cache-Control allow all
request_header_access Content-Length allow all
request_header_access Content-Type allow all
request_header_access Date allow all
request_header_access Host allow all
request_header_access If-Modified-Since allow all
request_header_access Pragma allow all
request_header_access Accept allow all
request_header_access Accept-Charset allow all
request_header_access Accept-Encoding allow all
request_header_access Accept-Language allow all
request_header_access Connection allow all
request_header_access All deny all
cache deny all
acl to_ipv6 dst ipv6
http_access deny all !to_ipv6
acl allow_net src 1.1.1.1
"

squid_conf_refresh="
refresh_pattern ^ftp: 1440 20% 10080
refresh_pattern ^gopher: 1440 0% 1440
refresh_pattern -i (/cgi-bin/|\?) 0 0% 0
refresh_pattern . 0 20% 4320
"

squid_conf_suffix="
# Common settings
acl SSL_ports port 443
acl Safe_ports port 80      # http
acl Safe_ports port 21      # ftp
acl Safe_ports port 443     # https
acl Safe_ports port 70      # gopher
acl Safe_ports port 210     # wais
acl Safe_ports port 1025-65535  # unregistered ports
acl Safe_ports port 280     # http-mgmt
acl Safe_ports port 488     # gss-http
acl Safe_ports port 591     # filemaker
acl Safe_ports port 777     # multiling http
acl CONNECT method CONNECT
http_access deny !Safe_ports
http_access deny CONNECT !SSL_ports
http_access allow localhost manager
http_access deny manager
http_access allow allow_net
http_access deny all
coredump_dir /var/spool/squid3
unique_hostname V6proxies-Net
visible_hostname V6proxies-Net
"

proxies=""

ipv6=($(add_ipv6 "$number_ipv6" "$unique_ip"))

for ip_out in "${ipv6[@]}"; do
    proxy_format="
http_port ${start_port}
acl p${start_port} localport ${start_port}
tcp_outgoing_address ${ip_out} p${start_port}
"
    start_port=$((start_port + 1))
    proxies+="$proxy_format\n"
done

cfg_squid_gen=$(echo -e "$cfg_squid" | sed "s/{pid}/${pool_name}/g" | sed "s/{squid_conf_refresh}/$squid_conf_refresh/g" | sed "s/{squid_conf_suffix}/$squid_conf_suffix/g" | sed "s/{block_proxies}/$proxies/g")

squid_conf_file="/etc/squid/squid-${pool_name}.conf"
if [ -f "$squid_conf_file" ]; then
    rm "$squid_conf_file"
    echo "$squid_conf_file exists. Removed"
fi

echo -e "$cfg_squid_gen" > "$squid_conf_file"

echo "=========================== \n"
echo "\n \n"
echo "Run two command bellow to start proxies"
echo "\n \n"
echo "bash $sh_add_ip"
echo "/usr/local/squid/sbin/squid -f $squid_conf_file"
echo "\n \n"
echo "Create $number_ipv6 proxies. Port start from $start_port"
