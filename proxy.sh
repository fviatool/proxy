
#!/bin/bash
###Script by Ngo Anh Tuan-lowendviet.com.

#Change log:
#Update 2022-Oct-05: Initialize script

# Final vars
UPDATE_URL="https://file.lowendviet.com/Scripts/Linux/levip6/levip6"
BIN_DIR="/usr/local/bin/"
BIN_EXEC="${BIN_DIR}levip6"
WORKDIR="/etc/lev/"
WORKDATA="${WORKDIR}/data.txt"
LOGFILE="/var/log/levip6.log"

updateScript() {
  wget ${UPDATE_URL} -o $LOGFILE -nv -N -P $BIN_DIR && chmod 777 $BIN_EXEC
  if grep -q "URL:" "$LOGFILE"; then
    echo -e "Đã cập nhật lên phiên bản mới nhất!"
    echo -e "Hãy chạy lại phần mềm bằng lệnh: \"levip6\"."
    exit 1
  else
    echo -e "Không cần cập nhật!"
  fi
}

updateScript

cat << "EOF"
=========================================================================

        IPv6 All In One VPS Server
==========================================================================

EOF

echo -e "Đang cài đặt thư viện và khởi tạo....."

# Function to get network card
getNetworkCard() {
  network_card=$(ip -o link show | awk '{print $2,$9}' | grep ens | cut -d: -f1)
  if [[ -z "$network_card" ]]; then
    network_card=$(ip -o link show | awk '{print $2,$9}' | grep enp | cut -d: -f1)
  fi
  if [[ -z "$network_card" ]]; then
    network_card=$(ip -o link show | awk '{print $2,$9}' | grep eno | cut -d: -f1)
  fi
  if [[ -z "$network_card" ]]; then
    network_card="eth0"
  fi
}

# Function to get OS info
getOSInfo() {
  if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    OS=$NAME
    VER=$VERSION_ID
  elif type lsb_release >/dev/null 2>&1; then
    OS=$(lsb_release -si)
    VER=$(lsb_release -sr)
  elif [[ -f /etc/lsb-release ]]; then
    . /etc/lsb-release
    OS=$DISTRIB_ID
    VER=$DISTRIB_RELEASE
  elif [[ -f /etc/debian_version ]]; then
    OS=Debian
    VER=$(cat /etc/debian_version)
  elif [[ -f /etc/SuSe-release ]]; then
    OS=$(cat /etc/SuSe-release | head -n 1)
  elif [[ -f /etc/redhat-release ]]; then
    OS=$(cat /etc/redhat-release)
  else
    OS=$(uname -s)
    VER=$(uname -r)
  fi
}

getNetworkCard
getOSInfo

# Function to update IPv6 settings
updateIPv6Settings() {
  if [[ "$OS" = "CentOS Linux" ]]; then
    if grep -q IPV6ADDR_SECONDARIES "/etc/sysconfig/network-scripts/ifcfg-${network_card}"; then
      temp=$(cat /etc/sysconfig/network-scripts/ifcfg-${network_card} | grep IPV6ADDR_SECONDARIES | cut -d "=" -f2 | sed -e 's/^"//' -e 's/"$//')
      if [[ "$isPutFirst" == "Y" || "$isPutFirst" == "y" ]]; then
        if echo $temp | grep -q "$ipv6"; then
          temp=$(echo $temp | sed "s/${ipv6}\/${ipv6mask}//")
        fi
        ipv6NewList=$(echo -n "$temp $ipv6\/${ipv6mask}")
      else
        ipv6NewList=$(echo -n "$ipv6\/${ipv6mask} $temp")
      fi

      sed -i "/IPV6ADDR_SECONDARIES=/c\IPV6ADDR_SECONDARIES=\"${ipv6NewList}\"" /etc/sysconfig/network-scripts/ifcfg-${network_card}
      if [[ $ipv6gw ]]; then
        if grep -q IPV6_DEFAULTGW "/etc/sysconfig/network-scripts/ifcfg-${network_card}"; then
          sed -i "/IPV6_DEFAULTGW=/c\IPV6_DEFAULTGW=${ipv6gw}" /etc/sysconfig/network-scripts/ifcfg-${network_card}
        else
          echo -e "IPV6_DEFAULTGW=${ipv6gw}" >> /etc/sysconfig/network-scripts/ifcfg-${network_card}
        fi
      fi
    else
      if [[ $ipv6gw ]]; then
        echo -e 'IPV6INIT="yes"' >> /etc/sysconfig/network-scripts/ifcfg-${network_card}
        echo -e 'IPV6_AUTOCONF="no"' >> /etc/sysconfig/network-scripts/ifcfg-${network_card}
        echo -e "IPV6ADDR_SECONDARIES=\"${ipv6}/${ipv6mask}\"" >> /etc/sysconfig/network-scripts/ifcfg-${network_card}
        if grep -q IPV6_DEFAULTGW "/etc/sysconfig/network-scripts/ifcfg-${network_card}"; then
          sed -i "/IPV6_DEFAULTGW=/c\IPV6_DEFAULTGW=${ipv6gw}" /etc/sysconfig/network-scripts/ifcfg-${network_card}
        else
          echo -e "IPV6_DEFAULTGW=${ipv6gw}" >> /etc/sysconfig/network-scripts/ifcfg-${network_card}
        fi
      else
        echo -e "IPV6ADDR_SECONDARIES=\"${ipv6}\/${ipv6mask}\"" >> /etc/sysconfig/network-scripts/ifcfg-${network_card}
      fi
    fi
  fi
}

# Function to create IPv6 proxy
createIPv6Proxy() {
  ipv6ProxyList=()
  for ((i=1; i<=$proxyCount; i++)); do
    randomPort=$(( ( RANDOM % 40000 )  + 10000 ))
    ipv6Proxy="[${ipv6}]:${randomPort}"
    ipv6ProxyList+=("$ipv6Proxy")echo "$ipv6Proxy" >> $WORKDIR/proxy_ipv6.txt

done
}

Main menu

echo “Menu chính:”
echo “”
echo “1 - Tự động cập nhật địa chỉ IPv6 mới”
echo “2 - Hiển thị IPv6 hiện tại”
echo “3 - Tạo proxy IPv6”
echo “0 - Thoát”
echo “”
echo -n “Nhập lựa chọn của bạn: “
read selection
echo “”

Process the selection

case $selection in
1)
echo “Đang lấy IPv6 mới từ lowendviet.com…”
wget -q -O $WORKDATA $UPDATE_URL && source $WORKDATA
if [[ -z “$ipv6” ]]; then
echo “Không thể lấy được địa chỉ IPv6 mới!”
else
echo “Đã lấy được địa chỉ IPv6 mới: $ipv6/$ipv6mask”
updateIPv6Settings
systemctl restart network
echo “IPv6 đã được cập nhật thành công!”
fi
;;
2)
ipv6addr=$(curl -s “https://v6.lowendviet.com/ip.php”)
echo “IPv6 hiện tại của bạn là: $ipv6addr”
;;
3)
echo -n “Nhập số lượng proxy IPv6 cần tạo: “
read proxyCount
echo “”
if [[ “$proxyCount” =~ ^[0-9]+$ ]]; then
createIPv6Proxy
echo “Đã tạo thành công $proxyCount proxy IPv6.”
else
echo “Số lượng proxy không hợp lệ!”
fi
;;
0)
echo “Kết thúc!”
;;
*)
echo “Xin hãy chọn lựa chính xác!”
;;
esac
