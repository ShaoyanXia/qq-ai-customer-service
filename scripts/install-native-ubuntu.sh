#!/usr/bin/env bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Please run as root." >&2
  exit 1
fi

apt update
apt install -y git curl ca-certificates python3 python3-venv python3-pip sqlite3 unzip xvfb

useradd -r -m -s /bin/bash qqbot || true
mkdir -p /opt/napcat /opt/xsy-web-chat /opt/qqbot-backups
chown -R qqbot:qqbot /opt/napcat /opt/xsy-web-chat /opt/qqbot-backups

if [ ! -d /opt/AstrBot/.git ]; then
  git clone https://github.com/AstrBotDevs/AstrBot.git /opt/AstrBot
fi
chown -R qqbot:qqbot /opt/AstrBot

sudo -u qqbot bash -lc 'cd /opt/AstrBot && python3 -m venv venv'
sudo -u qqbot bash -lc 'cd /opt/AstrBot && source venv/bin/activate && pip install -U pip && pip install -r requirements.txt'

echo "AstrBot source deployment is ready."
echo "Next:"
echo "1. Install NapCat Shell manually with official installer in /opt/napcat."
echo "2. Copy configs/systemd/astrbot.service to /etc/systemd/system/."
echo "3. Install the memory plugin into /opt/AstrBot/data/plugins/."


