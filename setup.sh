#!/usr/bin/env bash

echo "=========== Install Required Packages ================="
yum -y groupinstall 'Development Tools'
yum install -y perl gcc autoconf automake make sudo wget libxml2-devel libcap-devel libtool-ltdl-devel gcc-c++
yum -y install python pip

echo "=========== Re Compile Squid With Custom Configuration Params ================="
cd /opt
mkdir youni_ipv4_to_ipv6
cd youni_ipv4_to_ipv6

# Download necessary files
wget -c https://raw.githubusercontent.com/abdelyouni/ipv4_to_ipv6/main/gen_squid_conf.py
wget -c http://www.squid-cache.org/Versions/v4/squid-4.17.tar.gz
tar -zxvf squid-4.17.tar.gz
cd squid-4.17

# Compile Squid with custom configuration
./configure 'CXXFLAGS=-DMAXTCPLISTENPORTS=50000' \
--build=x86_64-redhat-linux-gnu \
--host=x86_64-redhat-linux-gnu \
--program-prefix= \
--disable-dependency-tracking \
--prefix=/usr \
--exec-prefix=/usr \
--bindir=/usr/bin \
--sbindir=/usr/sbin \
--sysconfdir=/etc \
--datadir=/usr/share \
--includedir=/usr/include \
--libdir=/usr/lib64 \
--libexecdir=/usr/libexec \
--localstatedir=/var \
--sharedstatedir=/var/lib \
--mandir=/usr/share/man \
--infodir=/usr/share/info \
--exec_prefix=/usr \
--libexecdir=/usr/lib64/squid \
--localstatedir=/var \
--datadir=/usr/share/squid \
--sysconfdir=/etc/squid \
--with-logdir=/var/log/squid \
--with-pidfile=/var/run/squid.pid \
--disable-dependency-tracking \
--enable-follow-x-forwarded-for \
--enable-auth \
--enable-auth-basic=DB,LDAP,NCSA,NIS,POP3,RADIUS,SASL,SMB,getpwnam,fake \
--enable-auth-ntlm=fake \
--enable-auth-digest=file,LDAP,eDirectory \
--enable-auth-negotiate=kerberos,wrapper \
--enable-external-acl-helpers=wbinfo_group,kerberos_ldap_group,LDAP_group,delayer,file_userip,SQL_session,unix_group \
--enable-cache-digests \
--enable-cachemgr-hostname=localhost \
--enable-delay-pools \
--enable-epoll \
--enable-icap-client \
--enable-ident-lookups \
--enable-linux-netfilter \
--enable-removal-policies=heap,lru \
--enable-snmp \
--enable-storeio=aufs,diskd,ufs,rock \
--enable-wccpv2 \
--enable-esi \
--enable-security-cert-generators \
--enable-security-cert-validators \
--with-aio \
--with-default-user=squid \
--with-filedescriptors=16384 \
--with-dl \
--with-openssl \
--enable-ssl-crtd \
--with-pthreads \
--with-included-ltdl \
--disable-arch-native \
--without-nettle

# Compile and install Squid
make && make install

# Increase file descriptors limit
ulimit -n 65536

# Create Squid user
useradd squid

# Set permissions for Squid log directory
chmod 777 /var/log/squid/

# Disable firewalld (optional, make sure it's safe for your environment)
systemctl disable firewalld


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
