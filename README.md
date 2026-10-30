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
