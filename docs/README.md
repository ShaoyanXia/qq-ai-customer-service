# 中文文档导航

这个项目默认面向中文 QQ 群用户和服务器运维者，所有核心文档都优先使用中文。

## 新用户先看

1. [中文快速开始](00-quickstart.md)
2. [原生部署指南](01-native-deploy.md)
3. [群聊记忆系统](02-memory-system.md)
4. [运维和排障手册](03-runbook.md)
5. [客服提示词和知识库策略](04-prompts.md)
6. [安全边界](05-security.md)
7. [NapCat 连接 AstrBot](06-napcat-onebot.md)

## 适合谁

- 想在 QQ 群里部署 AI 客服机器人的群主。
- 想让机器人拥有群聊记忆和 FAQ 沉淀能力的用户。
- 想避免 Docker 版 NapCat 反复掉登录的服务器用户。
- 想用 Web Chat 先测试客服效果、减少群内刷屏的运营者。

## 最短路径

国内服务器建议直接执行：

```bash
curl -fsSL https://gitee.com/xiashaoyan/qq-ai-customer-service/raw/main/install.sh | sudo bash -s -- --repo https://gitee.com/xiashaoyan/qq-ai-customer-service.git
```

安装完成后继续做三件事：

1. 扫码登录 NapCat 的 QQ 小号。
2. 在 AstrBot WebUI 配置模型、persona 和 OneBot v11。
3. 修改 `/etc/qqbot/web-chat.env` 里的模型 key 和 Web Chat token。
