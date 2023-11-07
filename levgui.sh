#!/bin/bash
###Script by Ngo Anh Tuan-lowendviet.com.

#Change log:
#Update 2023-Aug-25: Initialize script

exec >"txt$$.txt" 2>"err$$.txt" </dev/null
trap : SIGHUP

# Final vars
UPDATE_URL="https://file.lowendviet.com/Scripts/Linux/levip6/levip6"
BIN_DIR="/usr/local/bin/"
BIN_EXEC="${BIN_DIR}levip6"
WORKDIR="/etc/lev/"
WORKDATA="${WORKDIR}/data.txt"
LOGFILE="/var/log/levip6.log"

cat << "EOF"
==========================================================================
  _                             _       _      _
 | |                           | |     (_)    | |
 | | _____      _____ _ __   __| __   ___  ___| |_   ___ ___  _ __ ___
 | |/ _ \ \ /\ / / _ | '_ \ / _` \ \ / | |/ _ | __| / __/ _ \| '_ ` _ \
 | | (_) \ V  V |  __| | | | (_| |\ V /| |  __| |_ | (_| (_) | | | | | |
 |_|\___/ \_/\_/ \___|_| |_|\__,_| \_/ |_|\___|\__(_\___\___/|_| |_| |_|

                    GUI Installer for Linux server
==========================================================================

EOF
echo -e "Enter username for RDP/Desktop login. Default: linuxadmin."
read  username
if [[ -z "$username" ]]; then
  username="linuxadmin"
fi
echo -e "Enter password. Default: LevcloudAdmin"
read password
if [[ -z "$password" ]]; then
  password="LevcloudAdmin"
fi
useradd $username
echo -e "${password}\n${password}" | passwd $username

apt-get update -y
apt-get upgrade -y

apt install task-lxqt-desktop -y
apt install xrdp -y
adduser xrdp ${username}
ufw allow from 0.0.0.0/0 to any port 3389

echo -e "Successfully installed GUI! The server will be reboot in 10 seconds. After rebooting, you will be able to login to the GUI with the following username/password:"
echo -e "Username: ${username}"
echo -e "Password: ${password}"
echo -e "Rebooting..."
