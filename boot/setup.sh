#!/bin/bash
# nistkasten first-boot setup. Run once as root after first SSH login:
#   sudo bash /boot/firmware/setup.sh
# Idempotent: safe to run multiple times.
set -e

BOOT=/boot/firmware

# --- 1. packages ---
# ffmpeg is the only real dependency: alsa-utils (arecord) ships with the base
# image, and zram swap is enabled by default via systemd-zram-generator.
apt-get update
apt-get install -y ffmpeg

# --- 1b. ALSA config for the INMP441 I2S mic ---
cat > /etc/asound.conf <<'EOF'
pcm.inmp { type plug slave { pcm "hw:CARD=sndrpigooglevoi,DEV=0" } }
ctl.inmp { type hw card sndrpigooglevoi }
EOF

# --- 2. SSH key + passwordless sudo for the login user ---
USER_NAME="${SUDO_USER:-markus}"
USER_HOME=$(getent passwd "$USER_NAME" | cut -d: -f6)
mkdir -p "$USER_HOME/.ssh"
[ -f "$BOOT/authorized_keys" ] && cat "$BOOT/authorized_keys" >> "$USER_HOME/.ssh/authorized_keys"
chown -R "$USER_NAME:$USER_NAME" "$USER_HOME/.ssh"
chmod 700 "$USER_HOME/.ssh"
chmod 600 "$USER_HOME/.ssh/authorized_keys" || true
echo "$USER_NAME ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/nistkasten

# --- 3. mediamtx ---
MTX_VER="v1.21.3"
mkdir -p /opt/mediamtx
cd /tmp
curl -LO "https://github.com/bluenviron/mediamtx/releases/download/${MTX_VER}/mediamtx_${MTX_VER}_linux_arm64.tar.gz"
tar xzf "mediamtx_${MTX_VER}_linux_arm64.tar.gz" -C /opt/mediamtx mediamtx
chmod +x /opt/mediamtx/mediamtx
cat > /opt/mediamtx/mediamtx.yml <<'EOF'
rtsp: yes
rtspTransports: [tcp]
rtspAddress: :8554
hls: yes
hlsAddress: :8888
hlsVariant: lowLatency
hlsSegmentCount: 3
hlsSegmentDuration: 1s
hlsPartDuration: 100ms
webrtc: yes
webrtcAddress: :8889
readTimeout: 30s
writeTimeout: 30s
writeQueueSize: 2048
paths:
  unicast:
  audio:
  video:
EOF
cp "$BOOT/mediamtx.service" /etc/systemd/system/

# --- 4. stream scripts + services ---
# audio+video are published separately (video path, audio path) because the
# I2S capture xruns when ffmpeg holds the hw device together with video;
# ffmpeg-merge combines both into "unicast".
cp "$BOOT/ffmpeg_cmd.sh" /opt/ffmpeg_cmd.sh
chmod 755 /opt/ffmpeg_cmd.sh
cp "$BOOT/ffmpeg-stream.service" /etc/systemd/system/
cp "$BOOT/ffmpeg_merge.sh" /opt/ffmpeg_merge.sh
chmod 755 /opt/ffmpeg_merge.sh
cp "$BOOT/ffmpeg-merge.service" /etc/systemd/system/

systemctl daemon-reload
systemctl enable mediamtx.service ffmpeg-stream.service ffmpeg-merge.service
systemctl start mediamtx.service ffmpeg-stream.service ffmpeg-merge.service

echo "setup done, rebooting"
systemctl reboot