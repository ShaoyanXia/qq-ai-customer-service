# 常见问题和处理方法

这份文档按部署时最容易卡住的地方整理。遇到问题时，先看日志和端口，不要盲目重启 NapCat；频繁重启 NapCat 可能导致 QQ 需要重新扫码。

## 1. NapCat 下载失败，但安装脚本继续往下走

新版安装脚本会把这种情况识别为“部分完成”，并以 `exit 2` 退出，不会再提示完整安装成功。

如果看到 NapCat 下载失败：

```bash
cd /opt/chat-qqrobot
less docs/01-native-deploy.md
```

打开原生部署文档后，按里面的 NapCat 手动安装步骤处理。NapCat 安装到下面路径后：

```text
/root/Napcat/opt/QQ/qq
```

再执行：

```bash
bash /opt/chat-qqrobot/scripts/setup-napcat-service.sh
systemctl start napcat.service
```

## 2. NapCat WebUI 打不开

先确认 NapCat 是否在监听 `6099`：

```bash
systemctl status napcat.service --no-pager -l
ss -lntp | grep 6099
```

推荐用 SSH 隧道打开，不需要放行 `6099`：

```bash
ssh -L 6099:127.0.0.1:6099 root@<服务器公网 IP>
```

保持 SSH 窗口不要关闭，本地浏览器打开日志里的地址：

```bash
journalctl -u napcat.service --since "10 minutes ago" --no-pager | grep -E "WebUi|6099|token"
```

如果选择临时公网访问，需要先在安全组临时放行 TCP `6099`，然后用同一条日志命令拿 token：

```text
http://<服务器公网 IP>:6099/webui?token=<日志里的 token>
```

配置完成后立刻关闭 `6099` 公网入站。

## 3. NapCat 反向 WebSocket 连接失败

典型日志：

```text
connect ECONNREFUSED 127.0.0.1:6199
```

这说明 NapCat 已经在连接 AstrBot，但 AstrBot 当前没有监听 `6199`。

按顺序检查：

```bash
ss -lntp | grep 6199
journalctl -u astrbot.service --since "10 minutes ago" --no-pager | grep -Ei "onebot|aiocqhttp|6199|websocket|error|exception"
```

如果 `6199` 没输出，回到 AstrBot WebUI 检查 OneBot v11：

```text
启用：打开
反向 WebSocket 主机：0.0.0.0
反向 WebSocket 端口：6199
路径：/ws
```

保存后必须重启 AstrBot：

```bash
systemctl restart astrbot.service
sleep 15
ss -lntp | grep 6199
```

`6199` 出现监听后，NapCat 会在下一次心跳周期自动重连；也可以再看 NapCat 日志：

```bash
journalctl -u napcat.service --since "5 minutes ago" --no-pager | grep -Ei "websocket|onebot|连接|ws|error"
```

## 4. NapCat 里应该选 WebSocket Server 还是 Client

本项目使用：

```text
WebSocket 客户端 / 反向 WebSocket
```

不要把主要配置建成 `WebSocket Server`。正确填写：

```text
URL: ws://127.0.0.1:6199/ws
消息格式: Array
上报自身消息: 关
强制推送事件: 开
Token: 和 AstrBot 一致；不确定时两边先留空
```

## 5. AstrBot 配好了 OneBot，但还是连不上

如果页面里已经填好，但 `ss -lntp | grep 6199` 没输出，通常是配置没有被 AstrBot 后端重新加载。

执行：

```bash
systemctl restart astrbot.service
sleep 15
ss -lntp | grep 6199
```

这是正常现象：新增或修改消息平台、OneBot、aiocqhttp 机器人配置后，建议重启 AstrBot。

## 6. `web-chat.env` 已经填了模型，为什么 AstrBot 还要配 provider

`web-chat.env` 只给 Web Chat 服务使用；AstrBot 是另一个服务，有自己的 provider 配置。

可以用脚本从 `web-chat.env` 生成参考配置：

```bash
bash /opt/chat-qqrobot/scripts/generate-astrbot-provider-from-env.sh
cat /etc/qqbot/astrbot-provider.generated.json
```

然后复制到 AstrBot WebUI，或按表单逐项填写。

## 7. Web Chat 健康检查第一次失败

服务刚启动时可能还没完成加载。先等 15 秒：

```bash
systemctl restart xsy-web-chat.service
sleep 15
curl -sS http://127.0.0.1:18887/health
```

如果仍失败，看日志：

```bash
journalctl -u xsy-web-chat.service --since "10 minutes ago" --no-pager
```

## 8. 端口到底要不要开放

| 端口 | 用途 | 建议 |
|---|---|---|
| `22` | SSH | 开放，最好限制你的 IP |
| `6099` | NapCat WebUI | 推荐 SSH 隧道；公网只临时开放 |
| `6185` | AstrBot Dashboard | 推荐 SSH 隧道；公网只临时开放 |
| `6199` | OneBot v11 | 不开放公网 |
| `18887` | Web Chat | 可按需开放，但必须配置 `ACCESS_TOKEN` |

最安全的做法是：`6099`、`6185` 都用 SSH 隧道，`6199` 永远不开放公网。
