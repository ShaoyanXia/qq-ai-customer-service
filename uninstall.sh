#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="${PROJECT_DIR:-/opt/chat-qqrobot}"
ASTRBOT_DIR="${ASTRBOT_DIR:-/opt/AstrBot}"
WEB_DIR="${WEB_DIR:-/opt/xigua-web-chat}"
NAPCAT_DIR="${NAPCAT_DIR:-/root/Napcat}"
NAPCAT_INSTALL_DIR="${NAPCAT_INSTALL_DIR:-/opt/napcat}"
BACKUP_DIR="${BACKUP_DIR:-/opt/qqbot-backups}"
CONFIG_DIR="${CONFIG_DIR:-/etc/qqbot}"
UV_PYTHON_INSTALL_DIR="${UV_PYTHON_INSTALL_DIR:-/opt/qqbot-python}"
REMOVE_NAPCAT=1
REMOVE_CONFIG=1
REMOVE_BACKUPS=0
DRY_RUN=0
YES=0

usage() {
  cat <<'EOF'
用法：
  sudo bash uninstall.sh [选项]

默认会删除本项目安装的服务、项目目录、AstrBot、Web Chat、NapCat 原生安装目录和 /etc/qqbot 配置。
不会卸载 git、curl、python、xvfb 等系统包，避免影响服务器上的其它服务。

选项：
  --yes               不再二次确认，直接执行。
  --dry-run           只显示将要执行的操作，不实际删除。
  --keep-napcat       保留 NapCat/QQ 数据：/root/Napcat 和 /opt/napcat。
  --keep-config       保留 /etc/qqbot 配置。
  --remove-backups    同时删除 /opt/qqbot-backups。
  -h, --help          显示帮助。

示例：
  sudo bash uninstall.sh --dry-run
  sudo bash uninstall.sh --yes
  sudo bash uninstall.sh --yes --keep-napcat
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --yes)
      YES=1
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --keep-napcat)
      REMOVE_NAPCAT=0
      shift
      ;;
    --keep-config)
      REMOVE_CONFIG=0
      shift
      ;;
    --remove-backups)
      REMOVE_BACKUPS=1
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

run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '[dry-run] %q ' "$@"
    printf '\n'
  else
    "$@"
  fi
}

remove_path() {
  local path="$1"
  case "$path" in
    ""|"/"|"/opt"|"/etc"|"/root"|"/usr"|"/var"|"/home")
      echo "拒绝删除危险路径：$path" >&2
      exit 1
      ;;
  esac
  if [ -e "$path" ] || [ -L "$path" ]; then
    run rm -rf -- "$path"
  fi
}

stop_disable_service() {
  local name="$1"
  if systemctl list-unit-files "$name" >/dev/null 2>&1 || [ -e "/etc/systemd/system/$name" ]; then
    run systemctl stop "$name" || true
    run systemctl disable "$name" || true
  fi
}

cat <<EOF
将卸载 QQ 群智能客服相关内容：

服务：
  - napcat.service
  - astrbot.service
  - xigua-web-chat.service

目录：
  - $PROJECT_DIR
  - $ASTRBOT_DIR
  - $WEB_DIR
  - $UV_PYTHON_INSTALL_DIR
EOF

if [ "$REMOVE_NAPCAT" -eq 1 ]; then
  cat <<EOF
  - $NAPCAT_DIR
  - $NAPCAT_INSTALL_DIR
EOF
else
  echo "保留 NapCat/QQ 数据：$NAPCAT_DIR, $NAPCAT_INSTALL_DIR"
fi

if [ "$REMOVE_CONFIG" -eq 1 ]; then
  echo "  - $CONFIG_DIR"
else
  echo "保留配置目录：$CONFIG_DIR"
fi

if [ "$REMOVE_BACKUPS" -eq 1 ]; then
  echo "  - $BACKUP_DIR"
else
  echo "保留备份目录：$BACKUP_DIR"
fi

cat <<'EOF'

不会卸载系统包，不会修改其它服务。
EOF

if [ "$YES" -ne 1 ] && [ "$DRY_RUN" -ne 1 ]; then
  printf '确认卸载请输入 yes：'
  read -r answer
  if [ "$answer" != "yes" ]; then
    echo "已取消。"
    exit 0
  fi
fi

stop_disable_service napcat.service
stop_disable_service astrbot.service
stop_disable_service xigua-web-chat.service

remove_path /etc/systemd/system/napcat.service
remove_path /etc/systemd/system/astrbot.service
remove_path /etc/systemd/system/xigua-web-chat.service
run systemctl daemon-reload

remove_path "$PROJECT_DIR"
remove_path "$ASTRBOT_DIR"
remove_path "$WEB_DIR"
remove_path "$UV_PYTHON_INSTALL_DIR"

if [ "$REMOVE_NAPCAT" -eq 1 ]; then
  remove_path "$NAPCAT_DIR"
  remove_path "$NAPCAT_INSTALL_DIR"
fi

if [ "$REMOVE_CONFIG" -eq 1 ]; then
  remove_path "$CONFIG_DIR"
fi

if [ "$REMOVE_BACKUPS" -eq 1 ]; then
  remove_path "$BACKUP_DIR"
fi

if id qqbot >/dev/null 2>&1; then
  run userdel qqbot || true
fi

echo "卸载完成。"
