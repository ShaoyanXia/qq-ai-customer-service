#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="/opt/chat-qqrobot"
ASTRBOT_DIR="/opt/AstrBot"
WEB_DIR="/opt/xigua-web-chat"
REPO_URL="${REPO_URL:-}"
BRANCH="${BRANCH:-main}"
INSTALL_NAPCAT=1
UV_BIN=""
PYTHON_VERSION="${PYTHON_VERSION:-3.12}"
PIP_INDEX_URL="${PIP_INDEX_URL:-https://mirrors.aliyun.com/pypi/simple}"
PIP_FALLBACK_INDEX_URL="${PIP_FALLBACK_INDEX_URL:-https://pypi.org/simple}"

usage() {
  cat <<'EOF'
Usage:
  bash install.sh --repo https://github.com/<owner>/<repo>.git [options]

Options:
  --repo <url>          Git repository URL of this project.
  --branch <name>       Git branch to install. Default: main.
  --python <version>    Python version for AstrBot. Default: 3.12.
  --project-dir <path>  Project install path. Default: /opt/chat-qqrobot.
  --astrbot-dir <path>  AstrBot install path. Default: /opt/AstrBot.
  --web-dir <path>      Web Chat install path. Default: /opt/xigua-web-chat.
  --skip-napcat         Skip NapCat Shell installer.
  -h, --help            Show help.

Example:
  curl -fsSL https://raw.githubusercontent.com/<owner>/<repo>/main/install.sh | sudo bash -s -- --repo https://github.com/<owner>/<repo>.git
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --repo)
      REPO_URL="$2"
      shift 2
      ;;
    --branch)
      BRANCH="$2"
      shift 2
      ;;
    --python)
      PYTHON_VERSION="$2"
      shift 2
      ;;
    --project-dir)
      PROJECT_DIR="$2"
      shift 2
      ;;
    --astrbot-dir)
      ASTRBOT_DIR="$2"
      shift 2
      ;;
    --web-dir)
      WEB_DIR="$2"
      shift 2
      ;;
    --skip-napcat)
      INSTALL_NAPCAT=0
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [ "$(id -u)" -ne 0 ]; then
  echo "Please run as root, for example with sudo." >&2
  exit 1
fi

if [ -z "$REPO_URL" ]; then
  echo "Missing --repo. Publish this project to GitHub/Gitee first, then pass its git URL." >&2
  usage
  exit 1
fi

run_as_qqbot() {
  runuser -u qqbot -- bash -lc "$*"
}

install_system_packages() {
  if command -v apt-get >/dev/null 2>&1; then
    apt-get update
    apt-get install -y git curl ca-certificates python3 python3-venv python3-pip sqlite3 unzip xvfb
    return
  fi

  if command -v dnf >/dev/null 2>&1; then
    dnf install -y git curl ca-certificates python3 python3-pip sqlite unzip xorg-x11-server-Xvfb
    return
  fi

  if command -v yum >/dev/null 2>&1; then
    yum install -y git curl ca-certificates python3 python3-pip sqlite unzip xorg-x11-server-Xvfb
    return
  fi

  echo "No supported package manager found. Supported: apt-get, dnf, yum." >&2
  exit 1
}

install_uv() {
  if command -v uv >/dev/null 2>&1; then
    UV_BIN="$(command -v uv)"
    return
  fi

  if [ -x /root/.local/bin/uv ]; then
    UV_BIN="/root/.local/bin/uv"
    return
  fi

  echo "Installing uv for Python runtime management..."
  curl -LsSf https://astral.sh/uv/install.sh | sh
  if [ -x /root/.local/bin/uv ]; then
    UV_BIN="/root/.local/bin/uv"
    return
  fi

  echo "uv installation failed." >&2
  exit 1
}

venv_python_matches() {
  local dir="$1"
  [ -x "$dir/venv/bin/python" ] || return 1
  "$dir/venv/bin/python" - <<PY
import sys
want = tuple(map(int, "${PYTHON_VERSION}".split(".")[:2]))
have = sys.version_info[:2]
raise SystemExit(0 if have >= want else 1)
PY
}

create_python_venv() {
  local dir="$1"
  install_uv
  "$UV_BIN" python install "$PYTHON_VERSION"
  if ! venv_python_matches "$dir"; then
    rm -rf "$dir/venv"
    cd "$dir"
    "$UV_BIN" venv --python "$PYTHON_VERSION" venv
    chown -R qqbot:qqbot "$dir/venv"
  fi
}

install_python_requirements() {
  local dir="$1"
  cd "$dir"
  "$UV_BIN" pip install --python "$dir/venv/bin/python" -U pip
  "$UV_BIN" pip install --python "$dir/venv/bin/python" \
    --only-binary=:all: \
    --no-binary=aiocqhttp \
    --no-binary=python-ripgrep \
    -r requirements.txt \
    -i "$PIP_INDEX_URL" || \
    "$UV_BIN" pip install --python "$dir/venv/bin/python" \
      --only-binary=:all: \
      --no-binary=aiocqhttp \
      --no-binary=python-ripgrep \
      -r requirements.txt \
      -i "$PIP_FALLBACK_INDEX_URL" || \
    CXXFLAGS="${CXXFLAGS:-} -std=c++11" "$UV_BIN" pip install --python "$dir/venv/bin/python" -r requirements.txt -i "$PIP_FALLBACK_INDEX_URL"
  chown -R qqbot:qqbot "$dir/venv"
}

echo "[1/9] Installing system packages..."
install_system_packages

echo "[2/9] Creating service user and directories..."
useradd -r -m -s /bin/bash qqbot || true
mkdir -p "$PROJECT_DIR" "$ASTRBOT_DIR" "$WEB_DIR" /opt/napcat /opt/qqbot-backups /etc/qqbot
chown -R qqbot:qqbot "$PROJECT_DIR" "$ASTRBOT_DIR" "$WEB_DIR" /opt/napcat /opt/qqbot-backups
chmod 750 /etc/qqbot

echo "[3/9] Fetching this project..."
if [ -d "$PROJECT_DIR/.git" ]; then
  run_as_qqbot "cd '$PROJECT_DIR' && git remote set-url origin '$REPO_URL' && git fetch origin '$BRANCH' --prune && git checkout '$BRANCH' && git pull --ff-only origin '$BRANCH'"
else
  if [ -d "$PROJECT_DIR" ] && [ "$(find "$PROJECT_DIR" -mindepth 1 -maxdepth 1 | head -n 1)" ]; then
    echo "$PROJECT_DIR exists and is not a git repository. Move it away or choose --project-dir." >&2
    exit 1
  fi
  git clone --branch "$BRANCH" "$REPO_URL" "$PROJECT_DIR"
  chown -R qqbot:qqbot "$PROJECT_DIR"
fi

echo "[4/9] Installing AstrBot from source..."
if [ -d "$ASTRBOT_DIR/.git" ]; then
  echo "AstrBot already exists at $ASTRBOT_DIR, skip source update to avoid GitHub connectivity issues."
else
  if [ -d "$ASTRBOT_DIR" ] && [ "$(find "$ASTRBOT_DIR" -mindepth 1 -maxdepth 1 | head -n 1)" ]; then
    echo "$ASTRBOT_DIR exists and is not a git repository. Move it away or choose --astrbot-dir." >&2
    exit 1
  fi
  git clone https://github.com/AstrBotDevs/AstrBot.git "$ASTRBOT_DIR"
  chown -R qqbot:qqbot "$ASTRBOT_DIR"
fi
create_python_venv "$ASTRBOT_DIR"
install_python_requirements "$ASTRBOT_DIR"

echo "[5/9] Installing memory plugin..."
run_as_qqbot "mkdir -p '$ASTRBOT_DIR/data/plugins/astrbot_plugin_group_memory'"
run_as_qqbot "cp -a '$PROJECT_DIR/plugins/astrbot_plugin_group_memory/.' '$ASTRBOT_DIR/data/plugins/astrbot_plugin_group_memory/'"

echo "[6/9] Installing Web Chat..."
run_as_qqbot "cp -a '$PROJECT_DIR/web-chat/.' '$WEB_DIR/'"
create_python_venv "$WEB_DIR"
install_python_requirements "$WEB_DIR"

echo "[7/9] Writing environment files..."
if [ ! -f /etc/qqbot/astrbot.env ]; then
  install -m 600 "$PROJECT_DIR/configs/astrbot.env.example" /etc/qqbot/astrbot.env
fi
if [ ! -f /etc/qqbot/web-chat.env ]; then
  install -m 600 "$PROJECT_DIR/configs/web-chat.env.example" /etc/qqbot/web-chat.env
  sed -i "s#^MEMORY_DB=.*#MEMORY_DB=$ASTRBOT_DIR/data/plugin_data/astrbot_plugin_group_memory/chat_memory.sqlite3#" /etc/qqbot/web-chat.env
fi

echo "[8/9] Installing systemd services..."
tmp_astrbot_service="$(mktemp)"
tmp_web_service="$(mktemp)"
cp "$PROJECT_DIR/configs/systemd/astrbot.service" "$tmp_astrbot_service"
cp "$PROJECT_DIR/configs/systemd/xigua-web-chat.service" "$tmp_web_service"
sed -i "s#/opt/AstrBot#$ASTRBOT_DIR#g" "$tmp_astrbot_service" "$tmp_web_service"
sed -i "s#/opt/xigua-web-chat#$WEB_DIR#g" "$tmp_web_service"
install -m 644 "$tmp_astrbot_service" /etc/systemd/system/astrbot.service
install -m 644 "$tmp_web_service" /etc/systemd/system/xigua-web-chat.service
rm -f "$tmp_astrbot_service" "$tmp_web_service"
systemctl daemon-reload
systemctl enable --now astrbot.service
systemctl enable --now xigua-web-chat.service

if [ "$INSTALL_NAPCAT" -eq 1 ]; then
  echo "[9/9] Launching NapCat Shell installer in non-container mode..."
  echo "This step may be interactive. Choose Shell/native install when prompted."
  cd /opt/napcat
  curl -fsSL -o napcat.sh https://nclatest.znin.net/NapNeko/NapCat-Installer/main/script/install.sh
  bash napcat.sh --docker n --cli y || {
    echo "NapCat installer exited with a non-zero status. Continue with manual setup from docs/01-native-deploy.md." >&2
  }
else
  echo "[9/9] Skipped NapCat installer."
fi

cat <<EOF

Install complete.

Next steps:
1. Edit /etc/qqbot/web-chat.env and set OPENAI_BASE_URL, OPENAI_API_KEY, OPENAI_MODEL, ACCESS_TOKEN.
2. Configure AstrBot provider and persona in the AstrBot WebUI.
3. Configure NapCat OneBot v11 reverse WebSocket to ws://127.0.0.1:6199/ws.
4. Restart changed services:
   systemctl restart astrbot.service
   systemctl restart xigua-web-chat.service
5. Open AstrBot via SSH tunnel:
   ssh -L 6185:127.0.0.1:6185 root@<SERVER_IP>
   http://127.0.0.1:6185
6. Test Web Chat health:
   curl -sS http://127.0.0.1:18887/health

Important: do not expose NapCat WebUI, AstrBot Dashboard, or OneBot ports directly to the public internet.
EOF
