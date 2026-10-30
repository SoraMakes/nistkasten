#!/bin/bash
# low-latency stream 1080p25: video pipe into ffmpeg input 0 (queue 64), audio via arecord into input 1
libcamera-vid -v 0 -t 0 -b 2000000 --width 1920 --height 1080 --framerate 25 -g 25 --codec h264 --inline --output - | \
ffmpeg -fflags nobuffer -flags low_delay -thread_queue_size 64 -i - \
-f s32le -ar 48000 -ac 2 -thread_queue_size 8192 -i <(arecord -q -D plughw:CARD=sndrpigooglevoi,DEV=0 -c2 -r48000 -f S32_LE -t raw --buffer-size=65536 --period-size=8192 -) \
-vcodec copy -filter:a "volume=20dB" -acodec:a libopus -b:a 64k \
-map 0:v -map 1:a \
-use_wallclock_as_timestamps 1 \
-fflags nobuffer -flags low_delay \
-f rtsp -rtsp_transport tcp rtsp://localhost:8554/unicast \
-hide_banner -nostats