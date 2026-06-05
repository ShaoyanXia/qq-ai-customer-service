# QQ 登录后的收尾一键命令

当 NapCat 已经启动，并且 QQ 小号已经扫码登录后，可以执行收尾脚本。

## 一行命令

国内服务器：

```bash
curl -fsSL https://gitee.com/xiashaoyan/qq-ai-customer-service/raw/main/scripts/post-login-setup.sh | sudo bash
```

如果想让脚本顺便打印公网访问地址：

```bash
curl -fsSL https://gitee.com/xiashaoyan/qq-ai-customer-service/raw/main/scripts/post-login-setup.sh | sudo bash -s -- --server-ip <服务器公网 IP>
```

## 它会自动做什么

- 检查并启动 `napcat.service`、`astrbot.service`、`xsy-web-chat.service`。
- 修复 AstrBot/Web Chat venv 指向 root 私有 Python 导致的 `Permission denied`。
- 根据 `/etc/qqbot/web-chat.env` 生成 AstrBot provider 参考配置：

```text
/etc/qqbot/astrbot-provider.generated.json
```

- 打印 NapCat WebUI token。
- 打印 SSH 隧道打开 NapCat/AstrBot 的命令。
- 打印 OneBot v11 反向 WebSocket 配置：

```text
ws://127.0.0.1:6199/ws
```

- 检查 `6099`、`6185`、`6199`、`18887` 端口状态。
- 测试 Web Chat `/health`。

## 它不会自动做什么

这些步骤仍需要用户在 WebUI 里点选：

- QQ 扫码登录。
- 在 AstrBot WebUI 里配置 provider。
- 在 AstrBot WebUI 里创建 OneBot v11。
- 在 NapCat WebUI 里新增 WebSocket 客户端。

原因是这些配置依赖 WebUI 当前状态、登录账号和页面表单，强行改配置文件容易写错或导致 NapCat 重新登录。

## 收尾后测试

群里发送：

```text
/chatmem_status
```

如果机器人回复消息数、FAQ 数等信息，说明 AstrBot、NapCat 和记忆插件已经连通。


