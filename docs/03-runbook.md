# 运维和排障手册

## 服务状态

```bash
systemctl status napcat.service --no-pager -l
systemctl status astrbot.service --no-pager -l
systemctl status xigua-web-chat.service --no-pager -l
```

如果 NapCat 还没有 systemd 服务，运行：

```bash
sudo bash /opt/chat-qqrobot/scripts/setup-napcat-service.sh
```

## 日志查看

```bash
journalctl -u napcat.service --since "30 minutes ago" --no-pager
journalctl -u astrbot.service --since "30 minutes ago" --no-pager
journalctl -u xigua-web-chat.service --since "30 minutes ago" --no-pager
```

原则：

- 改 Web Chat，只重启 `xigua-web-chat.service`。
- 改 AstrBot 插件、persona、provider，只重启 `astrbot.service`。
- 不到必须，不重启 NapCat，避免 QQ 小号重新扫码。

## 打开 NapCat WebUI

不要开放 `6099` 到公网。使用 SSH 隧道：

```bash
ssh -L 6099:127.0.0.1:6099 root@<SERVER_IP>
```

查看 WebUI 地址和 token：

```bash
journalctl -u napcat.service --since "10 minutes ago" --no-pager | grep -E "WebUi|6099|token"
```

本地浏览器打开类似地址：

```text
http://127.0.0.1:6099/webui?token=<TOKEN>
```

如果浏览器打开时报 SSH 里的 `Connection refused`，说明 NapCat 没在服务器本机监听 `6099`：

```bash
systemctl status napcat.service --no-pager -l
ss -lntp | grep 6099
```

## 检查知识库数量

```bash
python3 scripts/check_memory_db.py \
  --db /opt/AstrBot/data/plugin_data/astrbot_plugin_group_memory/chat_memory.sqlite3 \
  --group-id <GROUP_ID>
```

## 手动测试 Web Chat

```bash
curl -sS http://127.0.0.1:18887/health
```

```bash
curl -sS --max-time 120 \
  -H 'Content-Type: application/json' \
  -d '{"message":"总结近一天群聊消息，开头说明时间范围和条数","history":[]}' \
  'http://127.0.0.1:18887/api/chat?token=<WEB_CHAT_TOKEN>'
```

## 手动测试模型 API

文本：

```bash
python3 scripts/test_openai_compatible.py text \
  --base-url https://<YOUR_API_HOST>/v1 \
  --api-key <API_KEY> \
  --model <MODEL>
```

图片：

```bash
python3 scripts/test_openai_compatible.py vision \
  --base-url https://<YOUR_API_HOST>/v1 \
  --api-key <API_KEY> \
  --model <VISION_MODEL>
```

如果图片测试能回答“红色”，说明模型端支持视觉。

## 机器人看不到图片

排查顺序：

1. AstrBot 日志是否收到图片事件。
2. provider 配置是否有 `modalities: ["image"]`。
3. 模型或中转服务是否真的支持 OpenAI 兼容图片输入。
4. 重启 AstrBot，不要重启 NapCat。

## 群历史拉不全

NapCat 能拉到的历史取决于 QQ 当前可见缓存和服务端允许回溯范围。继续向前翻只返回同一条或空列表时，通常不是导入脚本 bug。

关键点：

- 翻页使用 `message_seq`。
- `real_seq` 只适合排序和观察，不要当翻页游标。

## 群总结太短或没有范围

修复方向：

- 将“最近”解析成默认近 1 天。
- 注入时间范围、命中条数、知识库总条数。
- 提示词要求回答开头说明统计范围。

## QQ 小号掉线

处理：

1. 打开 NapCat WebUI。
2. 扫码登录。
3. 确认机器人 QQ 已回到群里。
4. 检查 OneBot v11 是否重新连接 AstrBot。

建议：

- 使用小号。
- 避免短时间高频主动发言。
- 尽量用 Web Chat 调试，减少群内刷屏。

## 备份

至少备份：

```text
/opt/AstrBot/data/config
/opt/AstrBot/data/cmd_config.json
/opt/AstrBot/data/plugins/astrbot_plugin_group_memory
/opt/AstrBot/data/plugin_data/astrbot_plugin_group_memory/chat_memory.sqlite3
/opt/xigua-web-chat
```

SQLite 在线备份：

```bash
sqlite3 /opt/AstrBot/data/plugin_data/astrbot_plugin_group_memory/chat_memory.sqlite3 ".backup '/opt/qqbot-backups/chat_memory_backup.sqlite3'"
```
