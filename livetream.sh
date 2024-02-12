#!/bin/bash

# Function to check and install FFMPEG if not installed
function installFFMPEG() {
    if ! command -v ffmpeg &> /dev/null; then
        sudo apt-get update
        sudo apt-get install -y ffmpeg
    fi
}

# Function to activate stream with automatic port change on error
function activateStream() {
    local videoLink=$1
    local streamKey=$2

    local logFile="stream_$streamKey.log"
    local fbLiveUrl="rtmp://live-api-s.facebook.com:80/rtmp/$streamKey"
    local ffmpegCommand="ffmpeg -re -stream_loop -1 -i \$(youtube-dl -f 'best[height<720]' -g \"$videoLink\" --restrict-filenames) -re -stream_loop -1 -i \$(youtube-dl -f bestaudio[ext=m4a] -g \"$videoLink\" --restrict-filenames) -vcodec copy -acodec copy -f flv \"$fbLiveUrl\" > $logFile 2>&1 & echo \$!"

    eval "$ffmpegCommand"
}

# Function to configure stream
function configureStream() {
    local streamNum=$1
    local videoLink=""
    local streamKey=""

    checkAndRetry "1. Enter video link (link_video): " "videoLink" ".+"
    checkAndRetry "2. Enter Facebook Live stream key (stream_key): " "streamKey" ".+"

    activateStream "$videoLink" "$streamKey"
}

# Function to check errors and retry
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
            # Automatically change port without notifying
            echo "Invalid choice. Changing port..."
            fbLiveUrl="rtmp://live-api-s.facebook.com:443/rtmp/$streamKey"
            ffmpegCommand="ffmpeg -re -stream_loop -1 -i \$(youtube-dl -f 'best[height<720]' -g \"$videoLink\" --restrict-filenames) -re -stream_loop -1 -i \$(youtube-dl -f bestaudio[ext=m4a] -g \"$videoLink\" --restrict-filenames) -vcodec copy -acodec copy -f flv \"$fbLiveUrl\" > $logFile 2>&1 & echo \$!"
            eval "$ffmpegCommand"
            break
        fi
    done
}

# Main program
installFFMPEG

echo "Enter the number of streams you want to activate:"
read -r numStreams

for ((i=1; i<=numStreams; i++)); do
    configureStream "$i"
done

echo "All streams have been activated and will automatically broadcast and loop videos on Facebook Live. Please wait a moment."
