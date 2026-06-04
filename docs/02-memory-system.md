# 群聊记忆系统

记忆系统分三层：原始群聊消息、长期 FAQ、运行状态。原始消息用于追溯和检索，FAQ 用于沉淀稳定客服答案，运行状态用于排查每日总结是否成功。

## 数据库位置

默认路径：

```text
/opt/AstrBot/data/plugin_data/astrbot_plugin_group_memory/chat_memory.sqlite3
```

插件也会写 JSONL：

```text
/opt/AstrBot/data/plugin_data/astrbot_plugin_group_memory/chat_memory.jsonl
```

JSONL 方便备份、人工审计和迁移；SQLite 负责查询。

## 表结构

```sql
CREATE TABLE messages (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  ts INTEGER NOT NULL,
  platform TEXT,
  message_type TEXT,
  session_id TEXT,
  group_id TEXT,
  user_id TEXT,
  sender_name TEXT,
  message TEXT NOT NULL,
  raw_json TEXT,
  created_at INTEGER NOT NULL
);

CREATE TABLE faq_entries (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  group_id TEXT NOT NULL,
  question TEXT NOT NULL,
  answer TEXT NOT NULL,
  tags TEXT,
  evidence TEXT,
  source_start_ts INTEGER NOT NULL,
  source_end_ts INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  hit_count INTEGER NOT NULL DEFAULT 0,
  UNIQUE(group_id, question)
);

CREATE TABLE faq_summary_runs (
  group_id TEXT NOT NULL,
  day TEXT NOT NULL,
  source_start_ts INTEGER NOT NULL,
  source_end_ts INTEGER NOT NULL,
  message_count INTEGER NOT NULL,
  faq_count INTEGER NOT NULL,
  status TEXT NOT NULL,
  error TEXT,
  created_at INTEGER NOT NULL,
  PRIMARY KEY(group_id, day)
);
```

## 插件能力

`plugins/astrbot_plugin_group_memory` 当前是最小可用参考实现：

- 监听群聊和私聊消息。
- 写入 SQLite 和 JSONL。
- 在 LLM 请求前追加少量动态上下文。
- 提供 `/chatmem_status` 查看消息数、群消息数、FAQ 数。
- 提供 `/chatmem_recent <小时数>` 查看时间范围统计。

后续可扩展：

- 每日 FAQ 自动总结。
- OneBot HTTP 历史消息导入。
- OCR 或视觉摘要入库。
- 更强的检索排序和召回。

## 时间范围策略

用户问“最近聊了什么”时，不要固定取最近 N 条。活跃群的 100 条可能只覆盖几分钟，冷群的 100 条可能跨越几周。

建议规则：

- 未指定范围：默认近 1 天。
- 支持：今天、昨天、前天、本周、本月、近 N 小时、近 N 天、近 N 周、近 N 个月。
- 回答开头必须说明：时间范围、命中消息数、知识库总记录数。

示例：

```text
按 2026-05-28 12:27 至 2026-05-29 12:27 查询，命中 207 条群消息；当前知识库内该群总记录数 495 条。
```

## FAQ 沉淀策略

每日 FAQ 只收长期可复用的知识：

- 产品使用方法。
- 充值、额度、套餐、账号、售后流程。
- 常见报错和解决步骤。
- 模型、渠道、工具配置相关问题。
- 管理员或售后明确确认的信息。

不要收：

- 闲聊、玩笑、情绪输出。
- 没结论的讨论。
- 个人隐私。
- 一次性问题。
- 未确认的后台状态。

## 图片入库

图片能力分两层：

1. 当前对话看图：模型看到截图并即时排障。
2. 长期知识库入库：OCR 或视觉摘要写入 `messages`，再参与 FAQ 总结。

只配置 provider 的图片能力，通常只能解决第一层。如果要沉淀截图里的报错，需要新增摘要流程。

