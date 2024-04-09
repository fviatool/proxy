#!/bin/bash
# Set the PATH to include common command directories
PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/count=0
cmd_ip="/sbin/ip"
cmd_awk="/usr/bin/awk"
cmd_head="/usr/bin/head"
squid_confd="/etc/squid/conf.d/"
interface="eth0"
ipv4Local="192.168.1.9" 
network=$($cmd_ip -o -f inet6 addr show dev $interface | $cmd_awk '/scope global/ {print $4}' | $cmd_head -c -24)
sleeptime="30s"
port_range_start=8000
port_range_end=9000

# -----
# Generate Random Address
# Thx to Vladislav V. Prodan [https://gist.github.com/click0/939739]
# -----
GenerateAddress() {
  array=( 1 2 3 4 5 6 7 8 9 0 a b c d e f )
  a=${array[$RANDOM%16]}${array[$RANDOM%16]}${array[$RANDOM%16]}${array[$RANDOM%16]}
  b=${array[$RANDOM%16]}${array[$RANDOM%16]}${array[$RANDOM%16]}${array[$RANDOM%16]}
  c=${array[$RANDOM%16]}${array[$RANDOM%16]}${array[$RANDOM%16]}${array[$RANDOM%16]}
  d=${array[$RANDOM%16]}${array[$RANDOM%16]}${array[$RANDOM%16]}${array[$RANDOM%16]}
  echo $network:$a:$b:$c:$d
}

# -----
# Run IPv6-Address-Loop
# -----
while [ 0=1 ]
do
  # Generate a random number of ports between 1 and 3
  num_ports=$(( (RANDOM % 3) + 1 ))
  for ((i=1; i<=$num_ports; i++)); do
    ip=$(GenerateAddress)
    port=$(( (RANDOM % ($port_range_end - $port_range_start + 1)) + $port_range_start ))
    echo "[+] add ip$count port$i $ip:$port"

    $cmd_ip -6 addr add $ip/64 dev $interface
    echo "acl ip$count port$i random 1/3
tcp_outgoing_address $ip ip$count" > $squid_confd"0${count}-random-ip${count}-port${i}.conf"
  done

  if [[ $count > 0 ]]; then
    for ((i=1; i<=$num_ports; i++)); do
      echo "[-] del ip$count port$i $ip"
      $cmd_ip -6 addr del $ip/64 dev $interface
      rm $squid_confd"66-random-ip$count-port$i.conf" > /dev/null 2>&1
    done
  fi
  /bin/systemctl reload squid
  sleep $sleeptime

  ((count++))
done
