# nistkasten

Raspberry Pi 3A+ nest-box camera: 1080p25 H264 + INMP441 I2S mic via MediaMTX (RTSP/HLS/WebRTC).

## Flash & first boot

1. Flash Raspberry Pi OS Trixie (64-bit lite) or later with Raspberry Pi Imager 2.0+ or `dd`.
2. Edit `boot/network-config` (wifi SSID/password, static IP) and copy it, `setup.sh`, `ffmpeg_cmd.sh`, `ffmpeg-stream.service`, `mediamtx.service` and your `authorized_keys` onto the boot partition. For user/SSH either use the Imager settings or rename `boot/userconf.txt.example` to `userconf.txt` and `boot/ssh.placeholder` to `ssh`.
3. Append `boot/config_additions.txt` to `config.txt` (I2S overlay for the mic).
4. Boot. cloud-init applies `network-config` (wifi + static IP `192.168.32.30`) on first boot.
5. SSH in as your user, run once:
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

## Pitfalls

- Mic is read via `arecord` into a pipe: the I2S hw device has a tiny buffer (min 64 frames) and xruns when ffmpeg opens it directly under load.
- Never use a `type hw` ALSA alias for `arecord`; use `plughw:CARD=...,DEV=0`.
- Video queue in ffmpeg stays small (64) — large queues caused ~10s latency.
- WS is physical pin 35 (= GPIO19), not pin 19.
- zram (zstd, 100% RAM) replaces the SD swapfile — SD-card swap caused load spikes.
- Trixie uses cloud-init/Netplan: wifi and the static IP live in `boot/network-config`; `wpa_supplicant.conf` is no longer read.