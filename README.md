# nistkasten

Raspberry Pi 3A+ nest-box camera: 1080p25 H264 + INMP441 I2S mic via MediaMTX (RTSP/HLS/WebRTC).

## Flash & first boot

1. Flash Raspberry Pi OS Bookworm (64-bit lite) with Raspberry Pi Imager; enable SSH and set user/wifi in the imager (or drop `boot/ssh` + `boot/wpa_supplicant.conf` + `boot/userconf.txt` onto the boot partition).
2. Copy `setup.sh`, `ffmpeg_cmd.sh`, `ffmpeg-stream.service`, `mediamtx.service` and your `authorized_keys` onto the boot partition.
3. Append `boot/config_additions.txt` to `config.txt` (I2S overlay for the mic).
4. Boot, SSH in as your user, run once:
   ```
   sudo bash /boot/firmware/setup.sh
   ```
   (installs everything, then reboot once for the I2S overlay)

## Stream URLs

- VLC / RTSP: `rtsp://192.168.32.30:8554/unicast`
- Browser HLS: `http://192.168.32.30:8888/unicast/`
- Browser WebRTC: `http://192.168.32.30:8889/unicast`

## INMP441 wiring

| INMP441 | Pi pin | GPIO |
|---------|--------|------|
| SCK     | 12     | 18   |
| WS      | 35     | 19   |
| SD      | 38     | 20   |
| L/R     | GND    | —    |
| VDD     | 3.3V   | —    |

## Pitfalls (why setup.sh is written this way)

- Mic is read via `arecord` into a pipe: the I2S hw device has a tiny buffer (min 64 frames) and xruns when ffmpeg opens it directly under load.
- Never use a `type hw` ALSA alias as ffmpeg input; use `plughw:CARD=...,DEV=0`.
- Video queue in ffmpeg stays small (64) — large queues caused ~10s latency.
- `-f s32le` before `-i <device>` breaks ffmpeg; `-f` belongs to the demuxer only.
- WS is physical pin 35 (= GPIO19), not pin 19.
- zram (zstd, 100% RAM) replaces the SD swapfile — SD-card swap caused load spikes.