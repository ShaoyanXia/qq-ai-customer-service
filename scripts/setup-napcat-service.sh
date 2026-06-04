#!/usr/bin/env bash
set -euo pipefail

QQ_BIN="${QQ_BIN:-/root/Napcat/opt/QQ/qq}"
SERVICE_FILE="/etc/systemd/system/napcat.service"

if [ "$(id -u)" -ne 0 ]; then
  echo "请使用 root 或 sudo 运行。比如：sudo bash scripts/setup-napcat-service.sh" >&2
  exit 1
fi

if ! command -v xvfb-run >/dev/null 2>&1; then
  if command -v apt-get >/dev/null 2>&1; then
    apt-get update
    apt-get install -y xvfb
  elif command -v dnf >/dev/null 2>&1; then
    dnf install -y xorg-x11-server-Xvfb
  elif command -v yum >/dev/null 2>&1; then
    yum install -y xorg-x11-server-Xvfb
  else
    echo "未找到 xvfb-run，也无法识别包管理器。请先安装 Xvfb。" >&2
    exit 1
  fi
fi

if [ ! -x "$QQ_BIN" ]; then
  echo "找不到 QQ 可执行文件：$QQ_BIN" >&2
  echo "如果你的路径不同，请这样运行：" >&2
  echo "QQ_BIN=/实际路径/qq sudo -E bash scripts/setup-napcat-service.sh" >&2
  exit 1
fi

cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=NapCatQQ native service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=$(dirname "$(dirname "$QQ_BIN")")
Environment=DISPLAY=:99
ExecStart=/usr/bin/xvfb-run -a $QQ_BIN --no-sandbox
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now napcat.service
systemctl status napcat.service --no-pager -l

cat <<'EOF'

NapCat systemd 服务已安装。

常用命令：
  systemctl status napcat.service --no-pager -l
  journalctl -u napcat.service -f
  systemctl restart napcat.service

查看 WebUI 地址和 token：
  journalctl -u napcat.service --since "5 minutes ago" --no-pager | grep -E "WebUi|6099|token"

注意：不要频繁 restart napcat.service，重启 NapCat 可能导致 QQ 需要重新扫码。
EOF

