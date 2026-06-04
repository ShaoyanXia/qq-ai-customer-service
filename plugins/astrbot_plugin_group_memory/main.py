import json
import sqlite3
import time
from pathlib import Path

from astrbot.api import logger
from astrbot.api.event import AstrMessageEvent, filter
from astrbot.api.provider import ProviderRequest
from astrbot.api.star import Context, Star
from astrbot.core.agent.message import TextPart
from astrbot.core.utils.astrbot_path import get_astrbot_data_path


PLUGIN_NAME = "astrbot_plugin_group_memory"


class GroupMemoryPlugin(Star):
    def __init__(self, context: Context):
        super().__init__(context)
        self.data_dir = Path(get_astrbot_data_path()) / "plugin_data" / PLUGIN_NAME
        self.data_dir.mkdir(parents=True, exist_ok=True)
        self.db_file = self.data_dir / "chat_memory.sqlite3"
        self.jsonl_file = self.data_dir / "chat_memory.jsonl"
        self._init_db()

    def _connect(self) -> sqlite3.Connection:
        conn = sqlite3.connect(self.db_file)
        conn.row_factory = sqlite3.Row
        return conn

    def _init_db(self) -> None:
        with self._connect() as conn:
            conn.executescript(
                """
                create table if not exists messages (
                  id integer primary key autoincrement,
                  ts integer not null,
                  platform text,
                  message_type text,
                  session_id text,
                  group_id text,
                  user_id text,
                  sender_name text,
                  message text not null,
                  raw_json text,
                  created_at integer not null
                );
                create index if not exists idx_messages_group_ts on messages(group_id, ts);
                create index if not exists idx_messages_session_ts on messages(session_id, ts);

                create table if not exists faq_entries (
                  id integer primary key autoincrement,
                  group_id text not null,
                  question text not null,
                  answer text not null,
                  tags text,
                  evidence text,
                  source_start_ts integer not null,
                  source_end_ts integer not null,
                  updated_at integer not null,
                  hit_count integer not null default 0,
                  unique(group_id, question)
                );

                create table if not exists faq_summary_runs (
                  group_id text not null,
                  day text not null,
                  source_start_ts integer not null,
                  source_end_ts integer not null,
                  message_count integer not null,
                  faq_count integer not null,
                  status text not null,
                  error text,
                  created_at integer not null,
                  primary key(group_id, day)
                );
                """
            )

    def _extract_raw_json(self, event: AstrMessageEvent) -> str:
        raw = getattr(event.message_obj, "raw_message", None)
        try:
            return json.dumps(raw, ensure_ascii=False, default=str)
        except Exception:
            return ""

    def _store_event(self, event: AstrMessageEvent) -> None:
        message = (event.message_str or "").strip()
        if not message:
            return

        obj = event.message_obj
        sender = getattr(obj, "sender", None)
        row = {
            "ts": int(getattr(obj, "timestamp", 0) or time.time()),
            "platform": str(getattr(event, "platform_meta", "") or ""),
            "message_type": str(getattr(obj, "type", "") or ""),
            "session_id": str(getattr(obj, "session_id", "") or ""),
            "group_id": str(getattr(obj, "group_id", "") or ""),
            "user_id": str(getattr(sender, "user_id", "") or getattr(sender, "id", "") or ""),
            "sender_name": str(event.get_sender_name() or ""),
            "message": message,
            "raw_json": self._extract_raw_json(event),
            "created_at": int(time.time()),
        }

        with self._connect() as conn:
            conn.execute(
                """
                insert into messages
                (ts, platform, message_type, session_id, group_id, user_id, sender_name, message, raw_json, created_at)
                values
                (:ts, :platform, :message_type, :session_id, :group_id, :user_id, :sender_name, :message, :raw_json, :created_at)
                """,
                row,
            )
        with self.jsonl_file.open("a", encoding="utf-8") as fp:
            fp.write(json.dumps(row, ensure_ascii=False) + "\n")

    def _stats(self, group_id: str = "") -> dict:
        with self._connect() as conn:
            total = conn.execute("select count(*) from messages").fetchone()[0]
            faq_total = conn.execute("select count(*) from faq_entries").fetchone()[0]
            if group_id:
                group_total = conn.execute(
                    "select count(*) from messages where group_id=? or session_id=? or session_id=?",
                    (group_id, group_id, "group:" + group_id),
                ).fetchone()[0]
            else:
                group_total = 0
            latest_run = conn.execute(
                """
                select group_id, day, status, message_count, faq_count, error
                from faq_summary_runs
                order by created_at desc
                limit 1
                """
            ).fetchone()
        return {
            "total": total,
            "group_total": group_total,
            "faq_total": faq_total,
            "latest_run": dict(latest_run) if latest_run else None,
        }

    def _recent_context(self, group_id: str, query: str, limit: int = 8) -> str:
        with self._connect() as conn:
            group_total = conn.execute(
                "select count(*) from messages where group_id=? or session_id=? or session_id=?",
                (group_id, group_id, "group:" + group_id),
            ).fetchone()[0]
            keyword = next((part for part in query.split() if len(part) >= 2), "")
            rows = []
            if keyword:
                rows = conn.execute(
                    """
                    select ts, sender_name, message
                    from messages
                    where (group_id=? or session_id=? or session_id=?)
                      and message like ?
                    order by ts desc
                    limit ?
                    """,
                    (group_id, group_id, "group:" + group_id, "%" + keyword + "%", limit),
                ).fetchall()
            if not rows:
                rows = conn.execute(
                    """
                    select ts, sender_name, message
                    from messages
                    where group_id=? or session_id=? or session_id=?
                    order by ts desc
                    limit ?
                    """,
                    (group_id, group_id, "group:" + group_id, limit),
                ).fetchall()

        lines = [
            "【客服角色边界】",
            "你是 QQ 群智能客服，只回答本群产品、售后、技术、报错排障和群聊历史相关问题。无关要求必须拒绝。",
            f"当前知识库内该群总记录数：{group_total} 条",
            "【相关群聊记录】",
        ]
        for row in rows:
            ts = time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(row["ts"]))
            lines.append(f"- {ts} {row['sender_name'] or 'unknown'}: {row['message']}")
        return "\n".join(lines)

    @filter.event_message_type(filter.EventMessageType.ALL)
    async def record_message(self, event: AstrMessageEvent):
        try:
            self._store_event(event)
        except Exception as exc:
            logger.warning(f"group memory write failed: {exc}")

    @filter.on_llm_request()
    async def inject_memory_context(self, event: AstrMessageEvent, req: ProviderRequest):
        group_id = str(getattr(event.message_obj, "group_id", "") or "")
        if not group_id:
            return
        try:
            context = self._recent_context(group_id, event.message_str or "")
            req.extra_user_content_parts.append(TextPart(text=context).mark_as_temp())
        except Exception as exc:
            logger.warning(f"group memory context injection failed: {exc}")

    @filter.command("chatmem_status")
    async def chatmem_status(self, event: AstrMessageEvent):
        group_id = str(getattr(event.message_obj, "group_id", "") or "")
        stats = self._stats(group_id)
        latest = stats["latest_run"] or {}
        text = (
            f"消息总数：{stats['total']}\n"
            f"当前群消息数：{stats['group_total']}\n"
            f"FAQ 数：{stats['faq_total']}\n"
            f"最近总结：{latest.get('day', '-')} {latest.get('status', '-')}"
        )
        yield event.plain_result(text)

    @filter.command("chatmem_recent")
    async def chatmem_recent(self, event: AstrMessageEvent, hours: int = 24):
        group_id = str(getattr(event.message_obj, "group_id", "") or "")
        end_ts = int(time.time())
        start_ts = end_ts - max(1, min(hours, 24 * 31)) * 3600
        with self._connect() as conn:
            count = conn.execute(
                """
                select count(*) from messages
                where (group_id=? or session_id=? or session_id=?)
                  and ts between ? and ?
                """,
                (group_id, group_id, "group:" + group_id, start_ts, end_ts),
            ).fetchone()[0]
            total = conn.execute(
                "select count(*) from messages where group_id=? or session_id=? or session_id=?",
                (group_id, group_id, "group:" + group_id),
            ).fetchone()[0]
        start = time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(start_ts))
        end = time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(end_ts))
        yield event.plain_result(f"按 {start} 至 {end} 查询，命中 {count} 条群消息；当前知识库内该群总记录数 {total} 条。")

    async def terminate(self):
        logger.info("group memory plugin terminated")

