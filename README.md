# nistkasten

Raspberry Pi 3A+ nest-box camera: 1080p25 H264 + INMP441 I2S mic via MediaMTX (RTSP/HLS/WebRTC).

## Flash & first boot

1. Flash Raspberry Pi OS Trixie (64-bit lite) or later with Raspberry Pi Imager 2.0+ or `dd`.
2. Copy everything from `boot/` to the root of the boot partition.
3. On the boot partition:
   - fill in `network-config` (wifi SSID/password, static IP, country);
   - fill in `authorized_keys` with your SSH public key;
   - for the user either use the Imager settings (then delete `userconf.txt`) or replace the hash on the first line of `userconf.txt`.
4. Append `config_additions.txt` to the end of `config.txt`, after the final `[all]` line. The stock file ends with `[all]`, so the settings apply to every model. Do not replace `config.txt`.
5. Boot. cloud-init applies `network-config` (wifi + static IP `192.168.32.30`) on first boot.
6. SSH in as your user, run once:
   ```
   sudo bash /boot/firmware/setup.sh
   ```
   Installs ffmpeg + MediaMTX v1.21.3, writes `/etc/asound.conf`, deploys the three
   systemd services (mediamtx, ffmpeg-stream, ffmpeg-merge), enables zram swap,
   then reboots once for the I2S overlay. Idempotent — safe to re-run.

## What setup.sh does

| Step | What |
|------|------|
| packages | `ffmpeg` only — alsa-utils (arecord) and zram swap already ship enabled in the Trixie base image |
| `/etc/asound.conf` | `inmp` PCM -> `hw:CARD=sndrpigooglevoi` (INMP441 via I2S overlay) |
| MediaMTX v1.21.3 | `/opt/mediamtx`, config with low-latency HLS (3x1s segments, 100ms parts), RTSP TCP, WebRTC, 30s timeouts, writeQueueSize 2048 |
| services | `mediamtx.service`, `ffmpeg-stream.service` (split publishers), `ffmpeg-merge.service` (merge to unicast), all `Restart=always` |
| reboot | once, so the `googlevoicehat-soundcard` overlay activates |

## Stream URLs

- VLC / RTSP: `rtsp://192.168.32.30:8554/unicast` (video+audio merged)
- Browser HLS: `http://192.168.32.30:8888/unicast/`
- Browser WebRTC: `http://192.168.32.30:8889/unicast`
- Raw paths: `rtsp://192.168.32.30:8554/video` and `rtsp://192.168.32.30:8554/audio`

## Why two ffmpeg services (video/audio split + merge)

The I2S capture device (INMP441 via googlevoicehat overlay) xruns and freezes
after a few minutes when a single ffmpeg process reads the ALSA hw device while
also muxing 1080p video. Splitting publishers fixes it: `boot/ffmpeg_cmd.sh` runs
arecord (SCHED_FIFO, large buffer) into a FIFO and publishes audio-only to
`audio`, plus rpicam-vid video-only (1080p25, fixed exposure) to `video`;
`boot/ffmpeg_merge.sh` recombines both into `unicast` (it touches no ALSA device).
Verified stable on kernel 6.18.50 (current apt kernel, no downgrade): 1080p25 +
mono Opus, 0 service restarts, 0 dropped frames over 25+ min, no ALSA xruns.

## Troubleshooting

- No audio: `arecord -D plughw:CARD=sndrpigooglevoi,DEV=0 -d 5 -f S32_LE /tmp/t.wav`
  then check level with ffmpeg `volumedetect`. Card name: `arecord -l`.
- Stream not up: `systemctl status ffmpeg-stream ffmpeg-merge mediamtx`;
  merge waits until both `/video` and `/audio` answer HLS 200 before publishing.
- After kernel updates the ALSA card may renumber — check `arecord -l` and
  adjust the `CARD=` name in `/etc/asound.conf` and `boot/ffmpeg_cmd.sh`.

## INMP441 wiring

| INMP441 | Pi pin | GPIO |
|---------|--------|------|
| SCK     | 12     | 18   |
| WS      | 35     | 19   |
| SD      | 38     | 20   |
| L/R     | GND    | —    |
| VDD     | 3.3V   | —    |
