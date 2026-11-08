#!/bin/bash
# Merge /video + /audio into /unicast, but wait until both are online before
# publishing. Loops forever; systemd restarts on hard failure.
while true; do
  # wait for both source paths to exist
  for i in $(seq 1 60); do
    V=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8888/video/index.m3u8)
    A=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8888/audio/index.m3u8)
    [ "$V" = "200" ] && [ "$A" = "200" ] && break
    sleep 2
  done
  ffmpeg -loglevel warning -fflags nobuffer -flags low_delay \
    -rtsp_transport tcp -thread_queue_size 2048 -i rtsp://localhost:8554/video \
    -rtsp_transport tcp -thread_queue_size 2048 -i rtsp://localhost:8554/audio \
    -c copy -vsync passthrough -map 0:v -map 1:a -max_interleave_delta 10000000 \
    -fflags nobuffer -flags low_delay \
    -f rtsp -rtsp_transport tcp rtsp://localhost:8554/unicast
  echo "merge exited (code $?), retrying in 3s" >&2
  sleep 3
done
