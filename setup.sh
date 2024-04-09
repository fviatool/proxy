#!/bin/bash

# Path to IP and AWK commands
cmd_ip="/sbin/ip"

# Configuration directory for Squid
squid_confd="/etc/squid/conf.d/"

# Network interface
interface="eth0"

# Local IPv4 address
ipv4Local="192.168.1.9"

# Get the global IPv6 address
ipv6Global=$($cmd_ip -o -f inet6 addr show dev $interface | $cmd_awk '/scope global/ {print $4}' | $cmd_head -c -24)

# Sleep time between iterations
sleeptime="30s"

# Port range
port_range_start=8000
port_range_end=9000

# Function to generate random IPv6 addresses
GenerateAddress() {
  array=( 1 2 3 4 5 6 7 8 9 0 a b c d e f )
  a=${array[$RANDOM%16]}${array[$RANDOM%16]}${array[$RANDOM%16]}${array[$RANDOM%16]}
  b=${array[$RANDOM%16]}${array[$RANDOM%16]}${array[$RANDOM%16]}${array[$RANDOM%16]}
  c=${array[$RANDOM%16]}${array[$RANDOM%16]}${array[$RANDOM%16]}${array[$RANDOM%16]}
  d=${array[$RANDOM%16]}${array[$RANDOM%16]}${array[$RANDOM%16]}${array[$RANDOM%16]}
  echo $ipv6Global:$a:$b:$c:$d
}

# Run the IPv6 address loop
while true; do
  # Generate a random number of ports between 1 and 3
  num_ports=$(( (RANDOM % 3) + 1 ))

  for ((i=1; i<=$num_ports; i++)); do
    ip=$(GenerateAddress)
    port=$(( (RANDOM % ($port_range_end - $port_range_start + 1)) + $port_range_start ))
    echo "[+] Adding IP $ip:$port"

    # Add IPv6 address to the interface
    $cmd_ip -6 addr add $ip/64 dev $interface

    # Create Squid configuration for the IP and port
    echo "acl ip$i random 1/3
tcp_outgoing_address $ip" > $squid_confd"0${i}-random-ip${i}.conf"
  done

  # Reload Squid configuration
  systemctl reload squid

  # Wait for some time before next iteration
  sleep $sleeptime
done
