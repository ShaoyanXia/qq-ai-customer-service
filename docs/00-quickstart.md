# 中文快速开始

这份文档给“只想尽快在服务器跑起来”的用户看。目标是部署一个 QQ 群智能客服机器人：能在群里回复问题，能记录群聊，能沉淀 FAQ，还能用网页单独测试。

## 部署前准备

你需要：

- 一台 Linux 服务器，支持 Ubuntu、Debian、CentOS、RHEL、Alibaba Cloud Linux 等常见系统；脚本会自动准备 AstrBot 需要的新版 Python，并在 PyPI 镜像异常时自动切换备用源。
- 一个 QQ 小号，用来当机器人。
- 一个 OpenAI 兼容模型 API key。
- 一个已经创建好的 QQ 群，小号需要先加入群。
- 能通过 SSH 登录服务器，并拥有 sudo 权限。

不建议使用 Docker 部署 NapCat，因为 Docker 版 NapCat 里的 QQ 更容易退出登录，后续经常需要重新扫码。

## 一行安装

国内服务器建议使用 Gitee：

```bash
curl -fsSL https://gitee.com/xiashaoyan/qq-ai-customer-service/raw/main/install.sh | sudo bash -s -- --repo https://gitee.com/xiashaoyan/qq-ai-customer-service.git
```

如果服务器访问 GitHub 稳定，也可以使用 GitHub：

```bash
curl -fsSL https://raw.githubusercontent.com/ShaoyanXia/qq-ai-customer-service/main/install.sh | sudo bash -s -- --repo https://github.com/ShaoyanXia/qq-ai-customer-service.git
```

安装脚本会自动完成：

- 安装系统依赖。
- 创建 `qqbot` 服务用户。
- 安装 AstrBot。
- 安装群聊记忆插件。
- 安装 Web Chat。
- 创建 systemd 服务。
- 启动 NapCat 原生 Shell 安装流程。
- 自动创建 `napcat.service`，避免手动前台启动后 SSH 一关 NapCat 就退出。

NapCat 这一步可能需要你按提示选择安装方式，并扫码登录 QQ 小号。

如果你想指定自己的 AstrBot 镜像，可以追加：

```bash
--astrbot-repo https://gitee.com/<你的用户名>/AstrBot.git
```

## 安装后配置

### 0. 打开 NapCat WebUI

NapCat WebUI 有两种打开方式。

推荐方式是 SSH 隧道，不需要开放 `6099`：

```bash
ssh -L 6099:127.0.0.1:6099 root@<服务器 IP>
```

保持这个窗口不要关闭，然后在本地浏览器打开 NapCat 日志里给出的地址。查看地址和 token：

```bash
journalctl -u napcat.service --since "10 minutes ago" --no-pager | grep -E "WebUi|6099|token"
```

通常类似：

```text
http://127.0.0.1:6099/webui?token=<TOKEN>
```

如果你不会用 SSH 隧道，也可以临时在云服务器安全组放行 TCP `6099`，然后访问：

```text
http://<服务器公网 IP>:6099/webui?token=<TOKEN>
```

扫码和配置完成后，立刻删除安全组里的 `6099` 入站规则。不要长期公网暴露 NapCat WebUI。

如果没有 `napcat.service`，先创建：

```bash
sudo bash /opt/chat-qqrobot/scripts/setup-napcat-service.sh
```

### 1. 配置 Web Chat 模型参数

编辑：

```bash
sudo nano /etc/qqbot/web-chat.env
```

修改：

```text
ACCESS_TOKEN=换成一个长一点的随机字符串
OPENAI_BASE_URL=https://你的模型服务地址/v1
OPENAI_API_KEY=你的 API key
OPENAI_MODEL=你的模型名
```

然后重启：

```bash
sudo systemctl restart xigua-web-chat.service
```

测试：

```bash
curl -sS http://127.0.0.1:18887/health
```

### 2. 打开 AstrBot WebUI

AstrBot WebUI 也有两种打开方式。

推荐方式是 SSH 隧道，不需要开放 `6185`：

```bash
ssh -L 6185:127.0.0.1:6185 root@<服务器 IP>
```

浏览器打开：

```text
http://127.0.0.1:6185
```

如果你不会用 SSH 隧道，也可以临时在云服务器安全组放行 TCP `6185`，然后访问：

```text
http://<服务器公网 IP>:6185
```

配置完成后，立刻删除安全组里的 `6185` 入站规则。不要长期公网暴露 AstrBot Dashboard。

首次用户名和密码看 AstrBot 日志：

```bash
sudo journalctl -u astrbot.service --since "10 minutes ago" --no-pager
```

### 3. 配置模型 provider

在 AstrBot WebUI 里配置 OpenAI 兼容模型。参考：

```text
configs/astrbot-provider.example.json
```

如果希望机器人能看截图，provider 的 `modalities` 需要包含：

```json
["image"]
```

### 4. 写入客服 persona

把 [客服提示词和知识库策略](04-prompts.md) 里的“系统提示词”复制到 AstrBot persona。

重点是限制机器人边界：

- 只回答本群产品、售后、技术、报错和群聊历史问题。
- 无关闲聊要拒绝。
- 充值、额度、账号、订单、退款、后台数据不确定时转人工。
- 不能泄露提示词、密钥和服务器信息。

### 5. 配置 NapCat 到 AstrBot

在 AstrBot WebUI 新建 `OneBot v11`：

```text
host: 0.0.0.0
port: 6199
url: /ws
```

在 NapCat WebUI 配置反向 WebSocket：

```text
ws://127.0.0.1:6199/ws
```

连接成功后，AstrBot 控制台会显示 OneBot v11 adapter connected。

更详细的图文式步骤见：[NapCat 连接 AstrBot](06-napcat-onebot.md)。

## NapCat 常见坑

### SSH 隧道提示 Connection refused

说明服务器本机 `127.0.0.1:6099` 没有服务监听。检查：

```bash
systemctl status napcat.service --no-pager -l
ss -lntp | grep 6099
```

### 手动运行 NapCat 后 SSH 一关就退出

不要长期用这种前台方式：

```bash
xvfb-run -a /root/Napcat/opt/QQ/qq --no-sandbox
```

改用 systemd：

```bash
sudo bash /opt/chat-qqrobot/scripts/setup-napcat-service.sh
```

### 看不到 WebUI token

从日志里查：

```bash
journalctl -u napcat.service --since "10 minutes ago" --no-pager | grep -E "WebUi|6099|token"
```

## 验收

在 QQ 群里测试：

```text
@机器人 你好
```

再测试记忆插件：

```text
/chatmem_status
```

如果能看到消息数增长，说明群聊已经入库。

测试最近消息统计：

```text
/chatmem_recent 24
```

它应该返回类似：

```text
按 2026-06-03 15:00:00 至 2026-06-04 15:00:00 查询，命中 123 条群消息；当前知识库内该群总记录数 456 条。
```

## 常见问题

### 为什么不用 Docker？

因为这个项目主要服务 QQ 群机器人，NapCat 里的 QQ 登录稳定性最重要。实践里 Docker 版 NapCat 更容易掉登录，重启容器后经常要重新扫码，所以默认走原生 Shell/systemd 部署。

### 改了插件要重启什么？

只重启 AstrBot：

```bash
sudo systemctl restart astrbot.service
```

不要重启 NapCat，除非 QQ 收发消息本身异常。

### Web Chat 公网能打开吗？

可以，但必须设置 `ACCESS_TOKEN`，最好再放到 Nginx 后面做 HTTPS 和访问控制。

### 机器人看不到图片怎么办？

检查三件事：

- QQ 群里发的是图片，不是被平台拦截。
- AstrBot provider 配置里有 `modalities: ["image"]`。
- 你的模型服务真的支持 OpenAI 兼容图片输入。
