#!/bin/bash

# Cài đặt FFMPEG nếu chưa được cài
if ! command -v ffmpeg &> /dev/null; then
    echo "Đang cài đặt FFMPEG..."
    sudo apt-get update
    sudo apt-get install -y ffmpeg
    echo "FFMPEG đã được cài đặt."
fi

# Hàm kiểm tra lỗi và nhập lại
function checkAndRetry() {
    local prompt=$1
    local variable=$2
    local validation=$3
    local input

    while true; do
        read -p "$prompt" input
        if [[ $input =~ $validation ]]; then
            eval "$variable=$input"
            break
        else
            echo "Lựa chọn không hợp lệ. Vui lòng thử lại."
        fi
    done
}

# Hàm kích hoạt luồng
function activateStream() {
    local streamNum=$1
    local videoLink=""
    local streamKey=""
    local duration=""

    while true; do
        clear
        echo "-------- Cấu hình cho Luồng $streamNum --------"

        checkAndRetry "1. Thay đổi link video (link_video): " "videoLink" ".+"
        checkAndRetry "2. Thay đổi Facebook Live stream key (stream_key): " "streamKey" ".+"
        checkAndRetry "3. Thay đổi thời gian phát live (thoi_gian, ví dụ: 30m): " "duration" "^([0-9]+[smh])$"

        if [[ $stopStream =~ (dung_live|D|d) ]]; then
            echo "Đang dừng live cho Luồng $streamNum."
            pkill -f "ffmpeg.*$streamKey"
            echo "Luồng $streamNum đã được dừng."
            return
        elif [[ $continueStream =~ (tiep_tuc|T|t) ]]; then
            break
        else
            echo "Lựa chọn không hợp lệ. Vui lòng thử lại."
        fi
    done

    echo "Đang phát video cho Luồng $streamNum..."
    local ffmpegCommand="ffmpeg -stream_loop 2 -t $duration -re -i \$(youtube-dl -f 'best[height<720]' -g \"$videoLink\" --restrict-filenames) -stream_loop 2 -re -i \$(youtube-dl -f bestaudio[ext=m4a] -g \"$videoLink\" --restrict-filenames) -c:v libx264 -preset veryfast -tune zerolatency -pix_fmt yuv420p -c:a aac -ar 44100 -b:a 128k -f flv \"rtmp://live-api-s.facebook.com:80/rtmp/$streamKey\" > /dev/null & echo \$!"

    gnome-terminal --tab --title="Luồng $streamNum" --command="bash -c '$ffmpegCommand'"
    echo "Luồng $streamNum đã được kích hoạt với key $streamKey trong $duration."
}

# Chương trình chính
echo "Nhập số luồng bạn muốn kích hoạt:"
read -r numStreams

for ((i=1; i<=numStreams; i++)); do
    activateStream "$i"
done
