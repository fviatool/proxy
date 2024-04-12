#!/bin/bash

# Function to generate random IPv6 addresses within a subnet
genIPv6() {
    local subnet="$1"
    local count="$2"
    local ipv6=()
    for ((i = 0; i < count; i++)); do
        ipv6+=("$(openssl rand -hex 8 | sed 's/\(..\)/\1:/g; s/.$//')$subnet")
    done
    echo "${ipv6[@]}"
}

# Function to get the IPv4 address of the machine
getIPv4() {
    echo "$(hostname -I | cut -d' ' -f1)"
}

# Function to generate a random IPv6 subnet
getIPv6Subnet() {
    echo "2001:ee0:4f9b:92b0::/64"  # Example subnet. Replace it with your desired range.
}

# Function to add IPv6 addresses to the network interface
addIPv6() {
    local subnet="$1"
    local interface="$2"
    sudo ip -6 addr flush dev "$interface"  # Flush existing IPv6 addresses
    for ip in $subnet; do
        sudo ip -6 addr add "$ip/64" dev "$interface"
    done
}

# Function to generate Squid configuration with IPv6 addresses
genSquidConfig() {
    local subnet="$1"
    local external_ip="$2"
    local start_port="$3"
    local end_port="$4"
    local number_ips="$5"

    local config="max_filedesc 500000
access_log          none
cache_store_log     none
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
cache           deny    all
acl to_ipv6 dst ipv6
http_access deny all !to_ipv6
acl allow_net src 1.1.1.1
"

    local bash_ipadd=""
    local proxy_list=""

    local ips=($(genIPv6 "$subnet" "$number_ips"))
    for ip in "${ips[@]}"; do
        bash_ipadd+="\nip addr add $ip/64 dev eth0"
        local random_port=$((RANDOM % ($end_port - $start_port + 1) + $start_port))
        config+="
http_port $random_port
acl p$random_port localport $random_port
tcp_outgoing_address $ip p$random_port
"
        proxy_list+="\n$external_ip:$random_port"
    done

    # Write Squid configuration to file
    echo -e "$config" | sudo tee /etc/squid/squid.conf > /dev/null

    # Write IP addresses to a bash script
    echo -e "#!/bin/bash\n$sudo bash -c \"$bash_ipadd\"" | sudo tee add_ips.sh > /dev/null
    sudo chmod +x add_ips.sh

    # Write proxy list to file
    echo -e "$proxy_list" | sudo tee proxy_list.txt > /dev/null
}

# Main function
main() {
    local ipv6_subnet="$(getIPv6Subnet)"
    local external_ip="$(getIPv4)"
    local number_ips="250"
    local start_port="10000"
    local end_port="90000"

    addIPv6 "$ipv6_subnet" "eth0"
    genSquidConfig "$ipv6_subnet" "$external_ip" "$start_port" "$end_port" "$number_ips"
}

main
