#!/bin/bash
# Set the PATH to include common command directories
PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
apt-get update -y
apt-get install squid -y
rm -rf /etc/squid/squid.conf
cat <<EOF > /etc/squid/squid.conf
forwarded_for delete
via off
dns_v4_first off
acl to_ipv6 dst ipv6
access_log none
cache deny all
dns_nameservers 1.1.1.1
max_filedesc 65535
coredump_dir /var/spool/squid
acl QUERY urlpath_regex cgi-bin \?
refresh_pattern ^ftp:           1440    20%     10080
refresh_pattern ^gopher:        1440    0%      1440
refresh_pattern -i (/cgi-bin/|\?) 0     0%      0
refresh_pattern .               0       20%     4320
auth_param basic program /usr/lib/squid/basic_ncsa_auth /etc/squid/squid.passwords
auth_param basic children 1024
auth_param basic realm Proxy
auth_param basic credentialsttl 2 hours
auth_param basic casesensitive off
acl password proxy_auth REQUIRED
include /etc/squid/ports.conf
http_access deny !to_ipv6
http_access allow password
http_access allow to_ipv6
http_access allow all
cache deny all
request_header_access follow_x_forwarded_for deny all
request_header_access X-Forwarded-For deny all
request_header_access Allow allow all
request_header_access Authorization allow all
request_header_access WWW-Authenticate allow all
request_header_access Proxy-Authorization allow all
request_header_access Proxy-Authenticate allow all
request_header_access Cache-Control allow all
request_header_access Transfer-Encoding allow all
request_header_access Content-Encoding allow all
request_header_access Content-Length allow all
request_header_access Content-Type allow all
request_header_access Date allow all
request_header_access Expires allow all
request_header_access Host allow all
request_header_access If-Modified-Since allow all
request_header_access Last-Modified allow all
request_header_access Location allow all
request_header_access Pragma allow all
request_header_access Accept allow all
request_header_access Accept-Charset allow all
request_header_access Accept-Encoding allow all
request_header_access Accept-Language allow all
request_header_access Content-Language allow all
request_header_access Mime-Version allow all
request_header_access Retry-After allow all
request_header_access Title allow all
request_header_access Content-Encoding allow all
request_header_access Content-Length allow all
request_header_access Content-Type allow all
request_header_access Date allow all
request_header_access Expires allow all
request_header_access Host allow all
request_header_access If-Modified-Since allow all
request_header_access Last-Modified allow all
request_header_access Location allow all
request_header_access Pragma allow all
request_header_access Accept allow all
request_header_access Accept-Charset allow all
request_header_access Accept-Encoding allow all
request_header_access Accept-Language allow all
request_header_access Content-Language allow all
request_header_access Mime-Version allow all
request_header_access Retry-After allow all
request_header_access Title allow all
request_header_access Connection allow all
request_header_access Proxy-Connection allow all
request_header_access User-Agent allow all
request_header_access Referer allow all
request_header_access Cookie allow all
request_header_access Set-Cookie allow all
request_header_access Content-Disposition allow all
request_header_access Range allow all
request_header_access Accept-Ranges allow all
request_header_access Vary allow all
request_header_access Etag allow all
request_header_access If-None-Match allow all
request_header_replace Referer example.com
request_header_access All deny all
request_header_access From deny all
request_header_access Referer deny all
request_header_access User-Agent deny all
reply_header_access Via deny all
reply_header_access Server deny all
reply_header_access WWW-Authenticate deny all
reply_header_access Link deny all
reply_header_access Allow allow all
reply_header_access Proxy-Authenticate allow all
reply_header_access Cache-Control allow all
reply_header_access Content-Encoding allow all
reply_header_access Content-Length allow all
reply_header_access Content-Type allow all
reply_header_access Date allow all
reply_header_access Expires allow all
reply_header_access Last-Modified allow all
reply_header_access Location allow all
reply_header_access Pragma allow all
reply_header_access Content-Language allow all
reply_header_access Retry-After allow all
reply_header_access Title allow all
reply_header_access Content-Disposition allow all
reply_header_access Connection allow all
reply_header_access All deny all
shutdown_lifetime 3 seconds
include /etc/squid/outgoing.conf
EOF
cat <<EOF > /root/setup.sh
#!/bin/bash
# Set the PATH to include common command directories
PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# Define the range of ports
FIRST_PORT=30001
LAST_PORT=30010
# Set username and password
USERNAME="oldboy"
PASSWORD="dota2vn"

INTERFACE="eth0"
# Generate hashed password
HASHED_PASSWORD=$(openssl passwd -apr1 "$PASSWORD")

# Generate squid.passwords file with hashed password
echo "$USERNAME:$HASHED_PASSWORD" > /etc/squid/squid.passwords

# Get IP addresses
IP4=$(curl -4 -s icanhazip.com)
IP6_PREFIX=$(curl -6 -s icanhazip.com | cut -f1-3 -d':')

# Display IP information
echo "Internal ip = ${IP4}. Prefix for ip6 = ${IP6_PREFIX}"

# Define an array of characters for generating IPv6 addresses
array=(1 2 3 4 5 6 7 8 9 0 a b c d e f)

# Define a function to generate an IPv6 address with random segments
gen48() {
    ip64() {
        echo "${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}"
    }
    echo "$1:$(ip64):$(ip64):$(ip64):$(ip64):$(ip64)"
}

# Generate random ipv6
gen_ipv6() {
    seq $FIRST_PORT $LAST_PORT | while read port; do
        echo "$(gen48 $IP6_PREFIX)"
    done
}

# Generate ports configuration and save to file
generate_ports_config() {
    for port in $(seq $FIRST_PORT $LAST_PORT); do
        echo "http_port ${IP4}:${port}"
    done
}

# Generate ACLs and save to outgoing.conf
generate_acls() {
    for port in $(seq $FIRST_PORT $LAST_PORT); do
        port_var="port$port"
        echo "acl ${port_var} localport ${port}" >> /etc/squid/outgoing.conf
    done
}

# Generate tcp_outgoing_address lines and append to outgoing.conf
generate_tcp_outgoing() {
    for port in $(seq $FIRST_PORT $LAST_PORT); do
        port_var="port$port"
        ip=$(echo "$IPv6_ADDRESSES" | head -n 1)
        IPv6_ADDRESSES=$(echo "$IPv6_ADDRESSES" | sed -e '1d')
        echo "tcp_outgoing_address ${ip} ${port_var}" >> /etc/squid/outgoing.conf
    done
}

generate_interfaces() {
    # Clear old interfaces
    for iface in $(ip -o -6 addr show | awk '{print $2}'); do
        # Iterate through all IPv6 addresses on the current network interface
        ip -6 addr show dev $iface | awk '/inet6/ && !/:$/ {print $2}' | while read addr; do
            # Check if the address is a full IPv6 address (not a subnet)
            if [[ "$addr" == *:*:*:*:*:*:*:* ]]; then
                # Delete the full IPv6 address
                ip -6 addr del $addr dev $iface
                #echo "Deleted $addr on $iface"
            fi
        done
    done
    # Read IPv6 addresses from file
    IPv6_ADDRESSES=$(cat /etc/squid/ipv6add.acl)

    # Add each IPv6 address to the interface
    for ip in $IPv6_ADDRESSES; do
        ip -6 addr add $ip/64 dev $INTERFACE
    done    
}

gen_ipv6 >/etc/squid/ipv6add.acl

generate_ports_config > /etc/squid/ports.conf

# Read IPv6 addresses from file
IPv6_ADDRESSES=$(cat /etc/squid/ipv6add.acl)

# Generate ACLs and tcp_outgoing_address lines, and save to outgoing.conf
generate_acls > /etc/squid/outgoing.conf
generate_tcp_outgoing >> /etc/squid/outgoing.conf

generate_interfaces

# Restart Squid service
systemctl restart squid

# Set up crontab job to run the entire script every 15 minutes
# Check if the cron job already exists before adding it
if ! crontab -l | grep -q "/root/gen_ipv6.sh"; then
    # Add the cron job to run the script every 20 minutes
   (crontab -l; echo "*/20 * * * * /bin/bash /root/gen_ipv6.sh >> /root/cron.log 2>&1") | crontab -
    echo "Added cron job to run the script every 20 minutes."
else
    echo "Cron job already exists."
fi

echo "Finished"

# set shutdown_lifetime to 2 to reduce rotate time
EOF
chmod 0755 /root/setup.sh
sh /root/setup.sh
