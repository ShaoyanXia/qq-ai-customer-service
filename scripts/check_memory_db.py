#!/usr/bin/env python3
import argparse
import datetime as dt
import sqlite3


def fmt_ts(value: int | None) -> str:
    if not value:
        return "-"
    return dt.datetime.fromtimestamp(value).strftime("%Y-%m-%d %H:%M:%S")


def main() -> None:
    parser = argparse.ArgumentParser(description="Check QQ customer service memory database.")
    parser.add_argument("--db", required=True, help="Path to chat_memory.sqlite3")
    parser.add_argument("--group-id", default="", help="Optional QQ group id")
    args = parser.parse_args()

    conn = sqlite3.connect(args.db)
    conn.row_factory = sqlite3.Row

    total = conn.execute("select count(*) c, min(ts) mn, max(ts) mx from messages").fetchone()
    print(f"messages_total={total['c']}")
    print(f"messages_earliest={fmt_ts(total['mn'])}")
    print(f"messages_latest={fmt_ts(total['mx'])}")

    faq_total = conn.execute("select count(*) from faq_entries").fetchone()[0]
    print(f"faq_total={faq_total}")

    if args.group_id:
        where = "group_id=? or session_id=? or session_id=?"
        params = (args.group_id, args.group_id, "group:" + args.group_id)
        group = conn.execute(
            f"select count(*) c, min(ts) mn, max(ts) mx from messages where {where}",
            params,
        ).fetchone()
        print(f"group_messages={group['c']}")
        print(f"group_earliest={fmt_ts(group['mn'])}")
        print(f"group_latest={fmt_ts(group['mx'])}")

    print("recent_summary_runs:")
    for row in conn.execute(
        """
        select group_id, day, status, message_count, faq_count, error
        from faq_summary_runs
        order by created_at desc
        limit 10
        """
    ):
        print(dict(row))

    conn.close()


if __name__ == "__main__":
    main()

