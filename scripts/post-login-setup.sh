#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="${PROJECT_DIR:-/opt/chat-qqrobot}"
ASTRBOT_DIR="${ASTRBOT_DIR:-/opt/AstrBot}"
WEB_DIR="${WEB_DIR:-/opt/xigua-web-chat}"
SERVER_IP="${SERVER_IP:-}"
FIX_VENV=1

usage() {
  cat <<'EOF'
用法：
  sudo bash scripts/post-login-setup.sh [选项]

适用场景：
  NapCat 已经启动，QQ 小号已经扫码登录后，自动完成/检查后续收尾步骤。

会做什么：
  - 确认 napcat.service、astrbot.service、xigua-web-chat.service 状态。
  - 修复 AstrBot/Web Chat venv 指向 root 私有 Python 导致的 Permission denied。
  - 根据 /etc/qqbot/web-chat.env 生成 AstrBot provider 参考配置。
  - 打印 NapCat WebUI token、SSH 隧道命令、OneBot 反向 WebSocket 地址。
  - 检查 6099、6185、18887、6199 端口状态。

不会做什么：
  - 不会自动扫码登录 QQ。
  - 不会自动点击 AstrBot/NapCat WebUI 表单。
  - 不会开放云安全组端口。

选项：
  --server-ip <ip>      用于打印公网访问地址。
  --no-fix-venv        不自动重建 venv。
  -h, --help           显示帮助。
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --server-ip)
      SERVER_IP="$2"
      shift 2
      ;;
    --no-fix-venv)
      FIX_VENV=0
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "未知选项：$1" >&2
      usage
      exit 1
      ;;
  esac
done

if [ "$(id -u)" -ne 0 ]; then
  echo "请使用 root 或 sudo 运行。" >&2
  exit 1
fi

info() {
  printf '\n[%s]\n' "$1"
}

service_status_line() {
  local name="$1"
  if systemctl is-active --quiet "$name"; then
    echo "$name: active"
  else
    echo "$name: inactive/failed"
  fi
}

fix_venv_if_needed() {
  local service="$1"
  local dir="$2"
  local req="$3"

  if [ "$FIX_VENV" -ne 1 ]; then
    return
  fi

  if ! journalctl -u "$service" --since "30 minutes ago" --no-pager | grep -q "Permission denied"; then
    return
  fi

  echo "检测到 $service 的 venv Python 权限问题，正在重建：$dir/venv"
  systemctl stop "$service" || true
  rm -rf "$dir/venv"
  cd "$dir"
  python3 -m venv venv
  "$dir/venv/bin/pip" install -U pip
  "$dir/venv/bin/pip" install -r "$req" -i https://mirrors.aliyun.com/pypi/simple
  chown -R qqbot:qqbot "$dir/venv"
  systemctl restart "$service"
}

info "1. 检查服务"
systemctl daemon-reload
systemctl enable --now napcat.service >/dev/null 2>&1 || true
systemctl enable --now astrbot.service >/dev/null 2>&1 || true
systemctl enable --now xigua-web-chat.service >/dev/null 2>&1 || true

echo "等待服务启动 15 秒..."
sleep 15

echo "$(service_status_line napcat.service)"
echo "$(service_status_line astrbot.service)"
echo "$(service_status_line xigua-web-chat.service)"

info "2. 修复可能的 venv 权限问题"
if [ -d "$ASTRBOT_DIR" ] && [ -f "$ASTRBOT_DIR/requirements.txt" ]; then
  fix_venv_if_needed astrbot.service "$ASTRBOT_DIR" "$ASTRBOT_DIR/requirements.txt"
fi
if [ -d "$WEB_DIR" ] && [ -f "$WEB_DIR/requirements.txt" ]; then
  fix_venv_if_needed xigua-web-chat.service "$WEB_DIR" "$WEB_DIR/requirements.txt"
fi

echo "等待服务重启 15 秒..."
sleep 15

info "3. 生成 AstrBot provider 参考配置"
if [ -x "$PROJECT_DIR/scripts/generate-astrbot-provider-from-env.sh" ] || [ -f "$PROJECT_DIR/scripts/generate-astrbot-provider-from-env.sh" ]; then
  bash "$PROJECT_DIR/scripts/generate-astrbot-provider-from-env.sh" || true
else
  echo "未找到 $PROJECT_DIR/scripts/generate-astrbot-provider-from-env.sh"
fi

info "4. NapCat WebUI 地址"
NAPCAT_LOG="$(journalctl -u napcat.service --since "30 minutes ago" --no-pager | grep -E "WebUi|6099|token" || true)"
if [ -n "$NAPCAT_LOG" ]; then
  echo "$NAPCAT_LOG" | tail -n 5
else
  echo "没有在最近 30 分钟日志里找到 WebUI token。可以重启 NapCat 后再查，但重启可能需要重新扫码："
  echo "  journalctl -u napcat.service -f"
fi

echo
echo "推荐 SSH 隧道打开 NapCat："
echo "  ssh -L 6099:127.0.0.1:6099 root@<服务器IP>"
echo "然后浏览器打开日志里的："
echo "  http://127.0.0.1:6099/webui?token=<TOKEN>"

if [ -n "$SERVER_IP" ]; then
  echo
  echo "如果你临时开放了 6099 公网端口，也可以访问："
  echo "  http://$SERVER_IP:6099/webui?token=<TOKEN>"
  echo "配置完成后请立刻关闭 6099 公网入站。"
fi

info "5. AstrBot WebUI 地址"
echo "推荐 SSH 隧道打开 AstrBot："
echo "  ssh -L 6185:127.0.0.1:6185 root@<服务器IP>"
echo "然后浏览器打开："
echo "  http://127.0.0.1:6185"

if [ -n "$SERVER_IP" ]; then
  echo
  echo "如果你临时开放了 6185 公网端口，也可以访问："
  echo "  http://$SERVER_IP:6185"
  echo "配置完成后请立刻关闭 6185 公网入站。"
fi

info "6. OneBot v11 配置"
cat <<'EOF'
在 AstrBot WebUI：
  机器人/Bots -> 新建 OneBot v11
  host: 0.0.0.0
  port: 6199
  path: /ws

在 NapCat WebUI：
  网络配置 -> 新建 -> WebSocket 客户端
  URL: ws://127.0.0.1:6199/ws

注意：6199 不需要开放公网端口。
EOF

info "7. 端口检查"
for port in 6099 6185 6199 18887; do
  if ss -lntp | grep -q ":$port "; then
    echo "$port: listening"
  else
    echo "$port: not listening"
  fi
done

info "8. Web Chat 健康检查"
if curl -sS --max-time 3 http://127.0.0.1:18887/health; then
  echo
else
  echo "Web Chat 未通过健康检查。查看日志："
  echo "  journalctl -u xigua-web-chat.service --since \"10 minutes ago\" --no-pager"
fi

cat <<'EOF'

收尾完成。

仍需人工完成的 WebUI 操作：
  1. 在 AstrBot WebUI 里配置 provider 和 persona。
  2. 在 AstrBot WebUI 里创建 OneBot v11。
  3. 在 NapCat WebUI 里新增 WebSocket 客户端。

配置完成后，在 QQ 群里测试：
  /chatmem_status
EOF
