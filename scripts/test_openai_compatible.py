#!/usr/bin/env python3
import argparse
import base64
import json
import struct
import urllib.request
import zlib


def red_png_base64() -> str:
    width = 32
    height = 32
    raw = b"".join(b"\x00" + bytes((255, 0, 0)) * width for _ in range(height))

    def chunk(name: bytes, data: bytes) -> bytes:
        return (
            struct.pack(">I", len(data))
            + name
            + data
            + struct.pack(">I", zlib.crc32(name + data) & 0xFFFFFFFF)
        )

    data = (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(raw))
        + chunk(b"IEND", b"")
    )
    return base64.b64encode(data).decode()


def post_chat(base_url: str, api_key: str, body: dict) -> str:
    url = base_url.rstrip("/") + "/chat/completions"
    req = urllib.request.Request(
        url,
        data=json.dumps(body, ensure_ascii=False).encode("utf-8"),
        headers={
            "Content-Type": "application/json",
            "Authorization": "Bearer " + api_key,
        },
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=90) as resp:
        return resp.read().decode("utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(description="Test an OpenAI-compatible chat API.")
    parser.add_argument("mode", choices=["text", "vision"])
    parser.add_argument("--base-url", required=True, help="Example: https://host.example/v1")
    parser.add_argument("--api-key", required=True)
    parser.add_argument("--model", required=True)
    args = parser.parse_args()

    if args.mode == "text":
        messages = [{"role": "user", "content": "回复 ok"}]
    else:
        messages = [
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": "这张图片主要是什么颜色？只回答颜色。"},
                    {
                        "type": "image_url",
                        "image_url": {"url": "data:image/png;base64," + red_png_base64()},
                    },
                ],
            }
        ]

    body = {
        "model": args.model,
        "messages": messages,
        "max_tokens": 80,
    }
    print(post_chat(args.base_url, args.api_key, body))


if __name__ == "__main__":
    main()

