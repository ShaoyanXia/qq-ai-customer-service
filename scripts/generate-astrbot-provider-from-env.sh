#!/usr/bin/env bash
set -euo pipefail

ENV_FILE="${ENV_FILE:-/etc/qqbot/web-chat.env}"
OUT_FILE="${OUT_FILE:-/etc/qqbot/astrbot-provider.generated.json}"

if [ ! -f "$ENV_FILE" ]; then
  echo "找不到配置文件：$ENV_FILE" >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

OPENAI_BASE_URL="${OPENAI_BASE_URL:-}"
OPENAI_API_KEY="${OPENAI_API_KEY:-}"
OPENAI_MODEL="${OPENAI_MODEL:-}"

if [ -z "$OPENAI_BASE_URL" ] || [ -z "$OPENAI_API_KEY" ] || [ -z "$OPENAI_MODEL" ]; then
  echo "请先在 $ENV_FILE 填写 OPENAI_BASE_URL、OPENAI_API_KEY、OPENAI_MODEL。" >&2
  exit 1
fi

python3 - "$OUT_FILE" <<'PY'
import json
import os
import sys

out_file = sys.argv[1]
data = {
    "provider_sources": [
        {
            "id": "openai_compatible_source",
            "provider": "openai",
            "type": "openai_chat_completion",
            "provider_type": "chat_completion",
            "key": [os.environ["OPENAI_API_KEY"]],
            "api_base": os.environ["OPENAI_BASE_URL"].rstrip("/"),
            "timeout": 120,
            "proxy": "",
            "custom_headers": {},
        }
    ],
    "provider": [
        {
            "id": "openai_compatible_chat",
            "enable": True,
            "model": os.environ["OPENAI_MODEL"],
            "provider_source_id": "openai_compatible_source",
            "modalities": ["image"],
            "custom_extra_body": {},
        }
    ],
}

with open(out_file, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
    f.write("\n")
PY

chmod 600 "$OUT_FILE"

cat <<EOF
已生成 AstrBot provider 参考配置：

  $OUT_FILE

查看：

  cat $OUT_FILE

说明：
  Web Chat 和 AstrBot 是两个独立服务，/etc/qqbot/web-chat.env 只会被 Web Chat 读取。
  AstrBot 仍需要在 WebUI 里配置 provider。你可以把上面的 JSON 内容复制到 AstrBot 的 provider 配置里，或按 WebUI 表单逐项填写。
EOF

