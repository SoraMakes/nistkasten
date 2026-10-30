#!/bin/bash
# nistkasten first-boot setup. Run once as root after first SSH login:
#   sudo bash /boot/firmware/setup.sh
# Idempotent: safe to run multiple times.
set -e

STATIC_IP="192.168.32.30/24"
GATEWAY="192.168.32.1"
BOOT=/boot/firmware

# --- 1. packages ---
apt-get update -qq
apt-get install -y -qq ffmpeg zram-tools

# --- 2. static IP via NetworkManager ---
con=$(nmcli -t -f NAME,TYPE con show | awk -F: '$2=="802-11-wireless"{print $1; exit}')
[ -n "$con" ] && nmcli con mod "$con" ipv4.addresses "$STATIC_IP" ipv4.gateway "$GATEWAY" ipv4.dns "$GATEWAY" ipv4.method manual

# --- 3. SSH key + passwordless sudo for markus ---
mkdir -p /home/markus/.ssh
[ -f "$BOOT/authorized_keys" ] && cat "$BOOT/authorized_keys" >> /home/markus/.ssh/authorized_keys
chown -R markus:markus /home/markus/.ssh
chmod 700 /home/markus/.ssh
chmod 600 /home/markus/.ssh/authorized_keys 2>/dev/null || true
echo "markus ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/markus

# --- 4. zram instead of SD swap ---
printf 'ALGO=zstd\nPERCENT=100\nPRIORITY=100\n' > /etc/default/zramswap
systemctl restart zramswap
swapoff /var/swap 2>/dev/null || true
systemctl disable var-swap.swap 2>/dev/null || true

# --- 5. mediamtx ---
MTX_VER="v1.21.3"
mkdir -p /opt/mediamtx
cd /tmp
curl -sLO "https://github.com/bluenviron/mediamtx/releases/download/${MTX_VER}/mediamtx_${MTX_VER}_linux_arm64.tar.gz"
tar xzf "mediamtx_${MTX_VER}_linux_arm64.tar.gz" -C /opt/mediamtx mediamtx
chmod +x /opt/mediamtx/mediamtx
cat > /opt/mediamtx/mediamtx.yml <<'EOF'
rtsp: yes
rtspTransports: [tcp]
rtspAddress: :8554
hls: yes
hlsAddress: :8888
hlsVariant: lowLatency
hlsSegmentCount: 7
hlsSegmentDuration: 1s
hlsPartDuration: 100ms
webrtc: yes
webrtcAddress: :8889
paths:
  unicast:
EOF
cp "$BOOT/mediamtx.service" /etc/systemd/system/

# --- 6. stream script + service ---
cp "$BOOT/ffmpeg_cmd.sh" /opt/ffmpeg_cmd.sh
chmod 755 /opt/ffmpeg_cmd.sh
cp "$BOOT/ffmpeg-stream.service" /etc/systemd/system/

systemctl daemon-reload
systemctl enable mediamtx.service ffmpeg-stream.service
systemctl start mediamtx.service ffmpeg-stream.service

echo "setup done. reboot recommended (I2S overlay needs it): sudo reboot"