#!/usr/bin/env bash

echo "=========== Install Required Packages ================="
yum -y groupinstall 'Development Tools'
yum install -y perl gcc autoconf automake make sudo wget libxml2-devel libcap-devel libtool-ltdl-devel gcc-c++
yum install -y python
pip install netaddr
useradd -r -s /sbin/nologin squid

echo "=========== Re Compile Squid With Custom Configuration Params ================="
cd /opt
mkdir -p youni_ipv4_to_ipv6
cd youni_ipv4_to_ipv6
wget -c https://raw.githubusercontent.com/abdelyouni/ipv4_to_ipv6/main/gen_squid_conf.py
wget -c http://www.squid-cache.org/Versions/v4/squid-4.17.tar.gz
tar -zxvf squid-4.17.tar.gz
cd squid-4.17
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

make && make install
ulimit -n 65536
ulimit -a
chmod 755 /var/log/squid/
systemctl disable firewalld

cd /opt/youni_ipv4_to_ipv6
python gen_squid_conf.py
