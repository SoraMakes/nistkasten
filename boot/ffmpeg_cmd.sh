#!/bin/bash
# low-latency stream 1080p25: video pipe into ffmpeg input 0, mono audio via arecord into input 1.
#
# arecord is used instead of ffmpeg's ALSA input: the I2S device has a tiny
# buffer (min 64 frames) and xruns when ffmpeg opens it directly under load.
# Use plughw:, not a type hw alias, so ALSA converts the format.
# The INMP441 is mono and wired to the left channel (L/R=GND); pan selects it.
#
# The video queue stays small (64); larger queues added ~10s of latency.
rpicam-vid -t 0 -b 2000000 --width 1920 --height 1080 --framerate 25 -g 25 --codec h264 --inline --output - | \
ffmpeg -fflags nobuffer -flags low_delay -thread_queue_size 64 -i - \
-f s32le -ar 48000 -ac 2 -thread_queue_size 8192 -i <(arecord -D plughw:CARD=sndrpigooglevoi,DEV=0 -c2 -r48000 -f S32_LE -t raw --buffer-size=65536 --period-size=8192 -) \
-vcodec copy -filter:a "pan=mono|c0=c0,volume=20dB" -ac 1 -acodec:a libopus -b:a 64k \
-map 0:v -map 1:a \
-use_wallclock_as_timestamps 1 \
-fflags nobuffer -flags low_delay \
-f rtsp -rtsp_transport tcp rtsp://localhost:8554/unicast