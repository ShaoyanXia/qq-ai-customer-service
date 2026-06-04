# 原生部署指南

本指南支持 Ubuntu、Debian、CentOS、RHEL、Alibaba Cloud Linux 等常见服务器系统。原则是：NapCatQQ 使用 Shell/Launcher 原生运行，AstrBot 使用源码或 uv 运行，二者交给 systemd 托管。

如果你已经把本项目发布到 Git 仓库，优先使用根目录的 `install.sh`：

```bash
curl -fsSL https://raw.githubusercontent.com/ShaoyanXia/qq-ai-customer-service/main/install.sh | sudo bash -s -- --repo https://github.com/ShaoyanXia/qq-ai-customer-service.git
```

下面是手动部署步骤，适合排障或二次定制。

## 1. 基础依赖

```bash
sudo apt update
sudo apt install -y git curl ca-certificates python3 python3-venv python3-pip sqlite3 unzip
```

NapCat Shell/Launcher 可能需要 `xvfb` 等图形相关依赖，按官方脚本提示安装即可：

```bash
sudo apt install -y xvfb
```

## 2. 目录规划

```text
/opt/napcat
/opt/AstrBot
/opt/xigua-web-chat
/opt/qqbot-backups
```

建议单独建服务用户：

```bash
sudo useradd -r -m -s /bin/bash qqbot || true
sudo mkdir -p /opt/napcat /opt/xigua-web-chat /opt/qqbot-backups
sudo chown -R qqbot:qqbot /opt/napcat /opt/xigua-web-chat /opt/qqbot-backups
```

## 3. 安装 NapCatQQ Shell

按 NapCat 官方 Shell 文档，优先使用非容器安装：

```bash
cd /opt/napcat
curl -o napcat.sh https://nclatest.znin.net/NapNeko/NapCat-Installer/main/script/install.sh
bash napcat.sh --docker n --cli y
```

如果上面的镜像不可用，可参考官方文档换用 GitHub raw 地址。安装后进入 NapCat WebUI，扫码登录 QQ 小号，并配置 OneBot v11 反向 WebSocket。

建议：

- NapCat WebUI 只绑定 `127.0.0.1`。
- 通过 SSH 隧道临时访问 WebUI。
- 不要为了改 AstrBot 插件而重启 NapCat。

## 4. 安装 AstrBot

```bash
cd /opt
sudo git clone https://github.com/AstrBotDevs/AstrBot.git
sudo chown -R qqbot:qqbot /opt/AstrBot
sudo -u qqbot bash -lc 'cd /opt/AstrBot && python3 -m venv venv'
sudo -u qqbot bash -lc 'cd /opt/AstrBot && source venv/bin/activate && pip install -U pip'
sudo -u qqbot bash -lc 'cd /opt/AstrBot && source venv/bin/activate && pip install -r requirements.txt'
```

首次前台启动，记下 WebUI 初始用户名和随机密码：

```bash
sudo -u qqbot bash -lc 'cd /opt/AstrBot && source venv/bin/activate && python main.py'
```

确认日志里出现 Dashboard 地址后，按 `Ctrl+C` 停止，再安装 systemd 服务。

## 5. systemd 托管 AstrBot

复制模板：

```bash
sudo cp configs/systemd/astrbot.service /etc/systemd/system/astrbot.service
sudo install -m 600 configs/astrbot.env.example /etc/qqbot/astrbot.env
sudo systemctl daemon-reload
sudo systemctl enable --now astrbot.service
sudo systemctl status astrbot.service --no-pager -l
```

访问 WebUI：

```bash
ssh -L 6185:127.0.0.1:6185 root@<SERVER_IP>
```

然后打开：

```text
http://127.0.0.1:6185
```

## 6. 连接 OneBot v11

在 AstrBot WebUI：

1. 进入 `Bots`。
2. 新建 `OneBot v11`。
3. 反向 WebSocket host 填 `0.0.0.0`。
4. 端口建议 `6199`。
5. 如设置 token，NapCat 端也要填同一个 token。

在 NapCat WebUI：

```text
ws://127.0.0.1:6199/ws
```

验证 AstrBot 控制台出现类似 “aiocqhttp adapter connected” 的日志。

## 7. 配置模型 provider

参考 `configs/astrbot-provider.example.json`，重点：

- `api_base` 必须带 `/v1`。
- 图片排障需要 provider 的 `modalities` 包含 `image`。
- 如果模型不支持视觉，不要打开图片能力。

## 8. 安装记忆插件

```bash
sudo -u qqbot mkdir -p /opt/AstrBot/data/plugins
sudo -u qqbot cp -r plugins/astrbot_plugin_group_memory /opt/AstrBot/data/plugins/
sudo systemctl restart astrbot.service
```

进入群里发几条消息后执行：

```text
/chatmem_status
```

## 9. 安装 Web Chat

```bash
sudo mkdir -p /opt/xigua-web-chat
sudo cp -r web-chat/* /opt/xigua-web-chat/
sudo chown -R qqbot:qqbot /opt/xigua-web-chat
sudo -u qqbot bash -lc 'cd /opt/xigua-web-chat && python3 -m venv venv && source venv/bin/activate && pip install -r requirements.txt'
sudo cp configs/systemd/xigua-web-chat.service /etc/systemd/system/xigua-web-chat.service
sudo install -m 600 configs/web-chat.env.example /etc/qqbot/web-chat.env
sudo editor /etc/qqbot/web-chat.env
sudo systemctl daemon-reload
sudo systemctl enable --now xigua-web-chat.service
```

健康检查：

```bash
curl -sS http://127.0.0.1:18887/health
```

公网访问前必须设置 `ACCESS_TOKEN`，并建议放在 Nginx 后面。
