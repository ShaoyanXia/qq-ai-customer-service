# 一键卸载

如果安装中断、配置错了，或者不想继续使用，可以运行卸载脚本。

## 默认卸载

国内服务器建议：

```bash
curl -fsSL https://gitee.com/xiashaoyan/qq-ai-customer-service/raw/main/uninstall.sh | sudo bash -s -- --yes
```

它会删除：

- `napcat.service`
- `astrbot.service`
- `xigua-web-chat.service`
- `/opt/chat-qqrobot`
- `/opt/AstrBot`
- `/opt/xigua-web-chat`
- `/root/Napcat`
- `/opt/napcat`
- `/etc/qqbot`
- `qqbot` 服务用户

它不会卸载：

- `git`
- `curl`
- `python`
- `xvfb`
- `sqlite`
- 其它系统包
- 其它 systemd 服务

这样可以避免影响服务器上其它服务。

## 先看会删什么

```bash
curl -fsSL https://gitee.com/xiashaoyan/qq-ai-customer-service/raw/main/uninstall.sh | sudo bash -s -- --dry-run
```

## 保留 NapCat 和 QQ 登录数据

如果你只想重装 AstrBot/Web Chat，但保留 NapCat 和 QQ 登录状态：

```bash
curl -fsSL https://gitee.com/xiashaoyan/qq-ai-customer-service/raw/main/uninstall.sh | sudo bash -s -- --yes --keep-napcat
```

会保留：

```text
/root/Napcat
/opt/napcat
```

## 保留配置

如果想保留模型 key、Web Chat token 等配置：

```bash
curl -fsSL https://gitee.com/xiashaoyan/qq-ai-customer-service/raw/main/uninstall.sh | sudo bash -s -- --yes --keep-config
```

会保留：

```text
/etc/qqbot
```

## 删除备份

默认保留备份目录：

```text
/opt/qqbot-backups
```

如果确认不要备份：

```bash
curl -fsSL https://gitee.com/xiashaoyan/qq-ai-customer-service/raw/main/uninstall.sh | sudo bash -s -- --yes --remove-backups
```

## 手动本地卸载

如果已经有项目目录：

```bash
sudo bash /opt/chat-qqrobot/uninstall.sh --yes
```

