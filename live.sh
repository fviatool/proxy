#!/bin/bash

# Hàm kiểm tra và cài đặt FFMPEG nếu chưa được cài
function installFFMPEG() {
    command -v ffmpeg &> /dev/null || { sudo apt-get update && sudo apt-get install -y ffmpeg; }
}

# Hàm kích hoạt luồng video trực tiếp lên Facebook Live
function activateStream() {
    local videoLink=$1
    local logFile="stream.log"
    local fbLiveUrl="rtmps://live-api-s.facebook.com:443/rtmp/$STREAM_KEY"
    
    ffmpeg -re -stream_loop -1 -i "$videoLink" -c:a copy -f flv "$fbLiveUrl" > "$logFile" 2>&1 & echo $!
}

# Hàm chính
installFFMPEG

# Nhập link video YouTube
read -p "Nhập link video YouTube: " videoLink

# Tự động lấy khóa luồng Facebook Live từ người dùng
read -p "Nhập khóa luồng Facebook Live (stream_key): " STREAM_KEY

# Kích hoạt luồng
activateStream "$videoLink"

echo "Luồng đã được kích hoạt và sẽ tự động phát trực tiếp video trên Facebook Live. Vui lòng đợi một lát."
