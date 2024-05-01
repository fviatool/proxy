#!/bin/bash

# Kiểm tra nếu script không được chạy với quyền root
if [ "$EUID" -ne 0 ]; then
  echo "Vui lòng chạy với quyền root"
  exit 1
fi

# Thiết lập các giá trị mặc định cho các tham số tùy chọn
subnet=64
proxy_count=3
proxies_type="http"
start_port=30000
rotating_interval=0
use_localhost=false
auth=true

# Xử lý các tùy chọn dòng lệnh
while getopts ":hs:c:u:p:t:r:l" option; do
  case $option in
    h) # Hiển thị thông tin trợ giúp
       echo "Sử dụng: $0 [-s <32|48|64> subnet (mặc định 64)] [-c <số lượng> số lượng proxy] [-u <tên> tên người dùng] [-p <mật khẩu> mật khẩu] [-t <http|socks5> loại proxy (mặc định http)] [-r <0-59> thời gian xoay ip proxy (mặc định 0)] [-l chỉ cho phép kết nối cho localhost]"
       exit 1;;
    s) subnet="$OPTARG";; # Thiết lập subnet
    c) proxy_count="$OPTARG";; # Thiết lập số lượng proxy
    u) user="$OPTARG";; # Thiết lập tên người dùng
    p) password="$OPTARG";; # Thiết lập mật khẩu
    t) proxies_type="$OPTARG";; # Thiết lập loại proxy
    r) rotating_interval="$OPTARG";; # Thiết lập khoảng thời gian xoay IP
    l) use_localhost=true;; # Cho phép kết nối chỉ cho localhost
    \?) echo "Tùy chọn không hợp lệ: -$OPTARG" >&2
        exit 1;;
  esac
done

# Kiểm tra tính hợp lệ của các tham số do người dùng cung cấp
re='^[0-9]+$'
if ! [[ $proxy_count =~ $re ]] ; then
	echo "Lỗi: Đối số -c (số lượng proxy) phải là một số nguyên dương" 1>&2;
	usage;
fi;

if [ -z $user ] && [ -z $password]; then auth=false; fi;

if ([ -z $user ] || [ -z $password ]) && [ $auth = true] ; then
	echo "Lỗi: cần nhập tên người dùng và mật khẩu cho proxy có xác thực (chỉ định cả hai tham số '--username' và '--password' khi khởi động)" 1>&2;
	usage;
fi;

if [ $proxies_type != "http" ] && [ $proxies_type != "socks5" ] ; then
  echo "Lỗi: giá trị không hợp lệ của tham số '-t' (loại proxy)" 1>&2;
  usage;
fi;

if [ $subnet != 64 ] && [ $subnet != 48 ] && [ $subnet != 32 ]; then
  echo "Lỗi: giá trị không hợp lệ của tham số '-s' (subnet)" 1>&2;
  usage;
fi;

if [ $rotating_interval -lt 0 ] || [ $rotating_interval -gt 59 ]; then
  echo "Lỗi: giá trị không hợp lệ của tham số '-r' (khoảng thời gian xoay IP proxy bên ngoài)" 1>&2;
  usage;
fi;

if [ $start_port -lt 5000 ] || (($start_port - $proxy_count > 65536 )); then
  echo "Lỗi: giá trị của tham số '--start-port' không đúng, nó phải lớn hơn 5000 và '--start-port' + '--proxy-count' phải nhỏ hơn 65536, vì Linux chỉ có 65536 cổng tiềm năng" 1>&2;
  usage;
fi;

if [ -z $subnet_mask ]; then 
  blocks_count=$((($subnet / 16) - 1));
  subnet_mask="$(ip -6 addr|awk '{print $2}'|grep -m1 -oP '^(?!fe80)([0-9a-fA-F]{1,4}:){'$blocks_count'}[0-9a-fA-F]{1,4}'|cut -d '/' -f1)";
fi;

# Định nghĩa đường dẫn cần thiết cho các script / cấu hình / v.v.
cd ~
user_home_dir="$(pwd)"
# Đường dẫn đến thư mục chứa thông tin tất cả các proxy
proxy_dir="$user_home_dir/proxyserver"
# Đường dẫn đến tệp cấu hình cho máy chủ proxy backconnect
proxyserver_config_path="$proxy_dir/3proxy/3proxy.cfg"
# Đường dẫn đến tệp chứa tất cả các địa chỉ IPv6 bên ngoài (kết nối lại)
random_ipv6_list_file="$proxy_dir/ipv6.list"
# Script khởi động máy chủ (tạo id ngẫu nhiên và chạy proxy daemon)
startup_script_path="$proxy_dir/proxy-startup.sh"
# Đường dẫn cấu hình Cron (bắt đầu máy chủ proxy sau khi khởi động lại Linux và xoay địa chỉ IP)
cron_script_path="$proxy_dir/proxy-server.cron"
# Tên giao diện mạng toàn cầu
interface_name="$(ip -br l | awk '$1 !~ "lo|vir|wl" { print $1}')"

# Lấy địa chỉ IP bên ngoài cho backconnect
external_ipv4="$(curl https://ipinfo.io/ip)"
# Sử dụng địa chỉ IPv4 localhost nếu người dùng muốn proxy cục bộ
localhost_ipv4="127.0.0.1"
backconnect_ipv4=$([ "$use_localhost" == true ] && echo "$localhost_ipv4" || echo "$external_ipv4")

# Hàm kiểm tra xem máy chủ proxy đã được cài đặt hay chưa
function is_proxyserver_installed(){
  if [ -d $proxy_dir ] && [ "$(ls -A $proxy_dir)" ]; then return 0; fi;
  return 1;
}

function check_ipv6(){
  # Kiểm tra xem IPv6 có được bật hay không
  if test -f /proc/net/if_inet6; then
	  echo "Giao diện IP v6 được kích hoạt";
  else
	  echo "Lỗi: giao diện inet6 (IPv6) không được kích hoạt. Bật IPv6 trên hệ thống của bạn." 1>&2;
	  exit 1;
  fi;

  if [[ $(ip -6 addr show scope global) ]]; then
    echo "Đã cấp phát địa chỉ IPv6 toàn cầu cho máy chủ";
  else
    echo "Lỗi: Địa chỉ IPv6 toàn cầu không được cấp phát cho máy chủ, hãy cấp phát hoặc liên hệ với bộ phận hỗ trợ VPS/VDS của bạn." 1>&2;
    exit 1;
  fi;

  local ifaces_config="/etc/network/interfaces";
  if test -f $ifaces_config; then
    if grep 'inet6' $ifaces_config; then
      echo "Cấu hình giao diện mạng cho IPv6 đúng";
    else
      echo "Lỗi: $ifaces_config không có cấu hình inet6 (IPv6)." 1>&2;
      exit 1;
    fi;
  fi;

  if [[ $(ping6 -c 1 google.com) != *"Network is unreachable"* ]]; then 
    echo "Kiểm tra ping google.com thành công";
  else
    echo "Lỗi: kiểm tra ping google.com thông qua IPv6 không thành công, mạng không thể đạt được." 1>&2;
    exit 1;
  fi; 

}

# Cài đặt các thư viện cần thiết
function install_requred_libs(){
  apt  update
  apt install make g++ wget curl cron -y
}

function install_3proxy(){

  mkdir $proxy_dir && cd $proxy_dir

  # Tải về máy chủ proxy
  wget https://github.com/3proxy/3proxy/archive/refs/tags/0.9.4.tar.gz
  tar -xf 0.9.4.tar.gz
  rm 0.9.4.tar.gz
  mv 3proxy-0.9.4 3proxy

  # Cài đặt máy chủ proxy
  cd 3proxy
  make -f Makefile.Linux
  cd ..
}

function configure_ipv6(){
  # Bật các tùy chọn sysctl để định tuyến và liên kết các địa chỉ từ mạng con với giao diện mặc định

  tee -a /etc/sysctl.conf > /dev/null << EOF
  net.ipv6.conf.$interface_name.proxy_ndp=1
  net.ipv6.conf.all.proxy_ndp=1
  net.ipv6.conf.default.forwarding=1
  et.ipv6.conf.all.forwarding=1
  net.ipv6.ip_nonlocal_bind = 1
EOF
  sysctl -p
}

function add_to_cron(){
  if test -f $cron_script_path; then rm $cron_script_path; fi;
  # Thêm script khởi động vào Cron (bộ lập lịch công việc) để khởi động lại máy chủ proxy sau khi khởi động lại và xoay pool proxy
  echo "@reboot $startup_script_path" > $cron_script_path;
  if [ $rotating_interval -ne 0 ]; then echo "*/$rotating_interval * * * * $startup_script_path" >> "$cron_script_path"; fi;
  crontab $cron_script_path
}

function create_startup_script(){
  if test -f $startup_script_path; then rm $startup_script_path; fi;
  # Thêm script chính để chạy máy chủ proxy và xoay địa chỉ IP, nếu máy chủ đã hoạt động
  cat > $startup_script_path <<-EOF
  #!/bin/bash
  # Hàm loại bỏ dấu cách ở đầu mỗi chuỗi trong văn bản
  function dedent() {
    local -n reference="\$1"
    reference="\$(echo "\$reference" | sed 's/^[[:space:]]*//')"
  }
  # Đóng 3proxy daemon, nếu nó đang chạy
  ps -ef | awk '/[3]proxy/{print \$2}' | while read -r pid; do
    kill \$pid
  done
  # Xóa danh sách IP ngẫu nhiên cũ trước khi tạo danh sách mới
  if test -f $random_ipv6_list_file; 
  then
    # Xóa các IP cũ từ giao diện
    for ipv6_address in \$(cat $random_ipv6_list_file); do ip -6 addr del \$ipv6_address dev $interface_name;done;
    rm $random_ipv6_list_file; 
  fi;
  # Mảng chứa các ký tự được phép trong hệ thập lục phân (trong địa chỉ IPv6)
  array=( 1 2 3 4 5 6 7 8 9 0 a b c d e f )
  # Tạo ký tự thập lục phân ngẫu nhiên
  function rh () { echo \${array[\$RANDOM%16]}; }
  rnd_subnet_ip () {
    echo -n $subnet_mask;
    symbol=$subnet
    while (( \$symbol < 128)); do
      if ((\$symbol % 16 == 0)); then echo -n :; fi;
      echo -n \$(rh);
      let "symbol += 4";
    done;
    echo ;
  }
  # Biến tạm để đếm số IP được tạo trong vòng lặp
  count=1
  # Tạo 'proxy_count' IPv6 ngẫu nhiên của mạng con được chỉ định và ghi vào tệp 'ip.list'
  while [ "\$count" -le $proxy_count ]
  do
    rnd_subnet_ip >> $random_ipv6_list_file;
    let "count += 1";
  done;
  immutable_config_part="daemon
    nserver 1.1.1.1
    maxconn 200
    nscache 65536
    timeouts 1 5 30 60 180 1800 15 60
    setgid 65535
    setuid 65535
    flush"
  auth_part="auth none"
  if [ $auth = true ]; then
    auth_part="auth strong
      users $user:CL:$password
      allow $user"
  fi;
  dedent immutable_config_part;
  dedent auth_part;   
  echo "\$immutable_config_part"\$'\n'"\$auth_part"  > $proxyserver_config_path
  # Thêm tất cả các proxy backconnect IPv6 ngẫu nhiên với địa chỉ ngẫu nhiên vào cấu hình khởi động máy chủ proxy
  port=$start_port
  count=1
  for random_ipv6_address in \$(cat $random_ipv6_list_file); do
      if [ "$proxies_type" = "http" ]; then proxy_startup_depending_on_type="proxy -6 -n -a"; else proxy_startup_depending_on_type=“socks -6 -a”; fi;
echo “$proxy_startup_depending_on_type -p$port -i$backconnect_ipv4 -e$random_ipv6_address” >> $proxyserver_config_path
((port+=1))
((count+=1))
if [ $count -eq 10001 ]; then
exit 1
fi
done

Script thêm tất cả các địa chỉ IPv6 ngẫu nhiên vào giao diện mặc định và chạy máy chủ proxy backconnect

ulimit -n 600000
ulimit -u 600000
for ipv6_address in $(cat ${random_ipv6_list_file}); do ip -6 addr add ${ipv6_address} dev ${interface_name};done;
${user_home_dir}/proxyserver/3proxy/bin/3proxy ${proxyserver_config_path}
exit 0
EOF
chmod +x $startup_script_path
}

if is_proxyserver_installed; then
echo ‘Máy chủ proxy đã được cài đặt, đang cấu hình lại:\n’;
check_ipv6;
create_startup_script;
add_to_cron;
/bin/bash $startup_script_path;
else
check_ipv6;
install_requred_libs;
configure_ipv6;
install_3proxy;
create_startup_script;
add_to_cron;
/bin/bash $startup_script_path
fi;

exit 0
