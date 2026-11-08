#!/bin/bash
# nistkasten: TWO independent publishers to MediaMTX — audio-only path "audio",
# video-only path "video". Decouples the I2S capture (which xruns when ffmpeg
# shares the process with video) from the video encoder.
FIFO=/tmp/nk_audio.fifo
rm -f "$FIFO"; mkfifo "$FIFO"

# audio publisher: arecord -> fifo -> ffmpeg -> opus -> rtsp audio
chrt -f 50 arecord -q -D plughw:CARD=sndrpigooglevoi,DEV=0 -c2 -r48000 -f S32_LE -t raw \
  --buffer-size=131072 --period-size=16384 "$FIFO" &
AP=$!
trap 'kill $AP 2>/dev/null' EXIT
ffmpeg -fflags nobuffer -flags low_delay -thread_queue_size 256 \
-f s32le -ar 48000 -ac 2 -i "$FIFO" \
-filter:a "pan=mono|c0=c0,volume=20dB" -ac 1 -acodec:a libopus -b:a 64k \
-fflags nobuffer -flags low_delay \
-f rtsp -rtsp_transport tcp rtsp://localhost:8554/audio &

# video publisher: rpicam-vid -> ffmpeg copy -> rtsp video
rpicam-vid -t 0 -b 2000000 --width 1920 --height 1080 --framerate 25 -g 50 --shutter 4000 --gain 8 --denoise cdn_off --codec h264 --inline --output - | \
ffmpeg -fflags nobuffer -flags low_delay -use_wallclock_as_timestamps 1 -thread_queue_size 64 -i - \
-vcodec copy -vsync vfr -map 0:v \
-fflags nobuffer -flags low_delay \
-f rtsp -rtsp_transport tcp rtsp://localhost:8554/video &

wait