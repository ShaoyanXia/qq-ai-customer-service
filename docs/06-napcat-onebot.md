# NapCat 连接 AstrBot：OneBot v11 反向 WebSocket

这一步的目标是让 NapCat 主动连接 AstrBot：

```text
NapCat -> ws://127.0.0.1:6199/ws -> AstrBot
```

注意：QQ 扫码登录不能自动完成；OneBot 连接也建议在扫码登录后配置。

## 1. 确认 AstrBot 正在运行

```bash
systemctl status astrbot.service --no-pager -l
```

如果没启动：

```bash
systemctl restart astrbot.service
```

## 2. 打开 AstrBot WebUI

AstrBot Dashboard 默认端口是 `6185`。你可以二选一：

| 方式 | 推荐程度 | 适合场景 |
|---|---|---|
| SSH 隧道 | 推荐 | 自己配置，最安全，不需要开放 `6185` |
| 临时开放端口 | 谨慎使用 | 不会用 SSH 隧道，或需要短时间让别人协助配置 |

### 方式 A：SSH 隧道打开 AstrBot

在本地电脑开 SSH 隧道：

```bash
ssh -L 6185:127.0.0.1:6185 root@<服务器 IP>
```

浏览器打开：

```text
http://127.0.0.1:6185
```

安全组只需要开放 SSH 端口，一般是 `22`。

### 方式 B：临时开放 AstrBot 端口

如果你确实要直接访问：

1. 云服务器安全组临时放行 TCP `6185`。
2. 系统防火墙也放行 `6185`，如果你启用了 ufw：

```bash
ufw allow 6185/tcp
```

3. 浏览器访问：

```text
http://<服务器公网 IP>:6185
```

配置完成后立刻关闭：

```bash
ufw delete allow 6185/tcp
```

并在云服务器安全组里删除 `6185` 入站规则。

不要长期公网暴露 AstrBot Dashboard。

在 AstrBot WebUI 里：

1. 进入“机器人”或“Bots”。
2. 创建机器人。
3. 平台/适配器选择 `OneBot v11`。
4. 连接方式使用反向 WebSocket。
5. 监听地址保持 `0.0.0.0` 或默认值。
6. 端口填 `6199`。
7. 路径填 `/ws`。
8. 保存并启用。

如果有 token 选项，先留空。等跑通后再加 token。

## 3. 打开 NapCat WebUI

NapCat WebUI 默认端口是 `6099`。同样有两种方式：

| 方式 | 推荐程度 | 适合场景 |
|---|---|---|
| SSH 隧道 | 推荐 | 自己扫码和配置，最安全，不需要开放 `6099` |
| 临时开放端口 | 谨慎使用 | 手机/电脑网络环境不方便隧道，或短时间让别人协助 |

### 方式 A：SSH 隧道打开 NapCat

在本地电脑开 SSH 隧道：

```bash
ssh -L 6099:127.0.0.1:6099 root@<服务器 IP>
```

查看 WebUI 地址和 token：

```bash
journalctl -u napcat.service --since "10 minutes ago" --no-pager | grep -E "WebUi|6099|token"
```

浏览器打开类似地址：

```text
http://127.0.0.1:6099/webui?token=<TOKEN>
```

安全组只需要开放 SSH 端口，一般是 `22`。

### 方式 B：临时开放 NapCat 端口

如果你确实要直接访问：

1. 云服务器安全组临时放行 TCP `6099`。
2. 系统防火墙也放行 `6099`，如果你启用了 ufw：

```bash
ufw allow 6099/tcp
```

3. 查看 WebUI token：

```bash
journalctl -u napcat.service --since "10 minutes ago" --no-pager | grep -E "WebUi|6099|token"
```

日志里会出现类似：

```text
http://127.0.0.1:6099/webui?token=<TOKEN>
```

复制里面的 `<TOKEN>`，拼到公网地址里。

4. 浏览器访问：

```text
http://<服务器公网 IP>:6099/webui?token=<TOKEN>
```

扫码和配置完成后立刻关闭：

```bash
ufw delete allow 6099/tcp
```

并在云服务器安全组里删除 `6099` 入站规则。

不要长期公网暴露 NapCat WebUI。它涉及 QQ 登录和机器人网络配置。

如果 NapCat 还没登录 QQ，先扫码登录。

## 4. 在 NapCat 新建 WebSocket 客户端

在 NapCat WebUI 里：

1. 进入“网络配置”。
2. 点击“新建”或“添加网络配置”。
3. 类型选择 `WebSocket 客户端`。
4. 启用这个配置。
5. URL 填：

```text
ws://127.0.0.1:6199/ws
```

6. 如果有“消息格式”，建议选择 `array`；没有就保持默认。
7. 如果有 token/access_token，先留空，和 AstrBot 保持一致。
8. 保存。

不要填服务器公网 IP。NapCat 和 AstrBot 在同一台服务器上，填 `127.0.0.1` 最安全。

## 5. 验证是否连接成功

看 AstrBot 日志：

```bash
journalctl -u astrbot.service --since "5 minutes ago" --no-pager | grep -Ei "onebot|aiocqhttp|connected|websocket|连接"
```

看 NapCat 日志：

```bash
journalctl -u napcat.service --since "5 minutes ago" --no-pager | grep -Ei "websocket|onebot|连接|ws"
```

群里 @机器人 测试：

```text
@机器人 你好
```

再测试记忆插件：

```text
/chatmem_status
```

如果 `/chatmem_status` 有回复，并且消息数增长，说明 OneBot 连接和插件都跑通了。

## 常见问题

### NapCat WebUI 里填公网 IP 可以吗？

不建议。NapCat 和 AstrBot 在同一台服务器上，填：

```text
ws://127.0.0.1:6199/ws
```

这样不需要开放 `6199` 公网端口。

### 保存后没有连接

按顺序检查：

```bash
systemctl status astrbot.service --no-pager -l
ss -lntp | grep 6199
journalctl -u astrbot.service --since "10 minutes ago" --no-pager
journalctl -u napcat.service --since "10 minutes ago" --no-pager
```

如果 `ss -lntp | grep 6199` 没输出，说明 AstrBot 的 OneBot v11 机器人没有创建成功或没有启用。

### 需要开放 6199 吗？

不需要。`6199` 只给服务器本机的 NapCat 连接 AstrBot，不要放到安全组公网入站。

## 端口开放建议

| 端口 | 用途 | SSH 隧道方案 | 临时公网方案 |
|---|---|---|---|
| `22` | SSH | 必须开放，最好只允许你的 IP | 必须开放，最好只允许你的 IP |
| `6099` | NapCat WebUI | 不开放 | 临时开放，配置完关闭 |
| `6185` | AstrBot Dashboard | 不开放 | 临时开放，配置完关闭 |
| `6199` | OneBot v11 | 不开放 | 不开放 |
| `18887` | Web Chat | 可不开放 | 如需给别人测试，可开放但必须带 token |
