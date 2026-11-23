#!/usr/bin/env python3
"""Мини-сервер для просмотра видео из песочницы: отдаёт статику и поддерживает
HTTP Range (нужен браузеру, чтобы перематывать и играть без полной загрузки).

    python3 scripts/serve-video.py [--port 8080] [--dir assets/cinematic-teaser]
"""
import argparse
import os
import re
import sys
from email.utils import formatdate
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

MIME = {
    ".html": "text/html; charset=utf-8",
    ".mp4": "video/mp4",
    ".webm": "video/webm",
    ".gif": "image/gif",
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".png": "image/png",
    ".txt": "text/plain; charset=utf-8",
    ".json": "application/json",
    ".svg": "image/svg+xml",
}
RANGE_RE = re.compile(r"bytes=(\d*)-(\d*)")


class Handler(BaseHTTPRequestHandler):
    root = "."
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt, *args):  # компактный лог
        sys.stderr.write("%s %s\n" % (self.command, self.path))

    def _resolve(self):
        path = self.path.split("?", 1)[0].lstrip("/") or "index.html"
        full = os.path.normpath(os.path.join(self.root, path))
        if not full.startswith(os.path.abspath(self.root)):
            return None
        return full

    def _send_file(self, full, status=HTTPStatus.OK, start=0, end=None):
        size = os.path.getsize(full)
        end = size - 1 if end is None else min(end, size - 1)
        length = end - start + 1
        ctype = MIME.get(os.path.splitext(full)[1].lower(), "application/octet-stream")

        self.send_response(status)
        self.send_header("Content-Type", ctype)
        self.send_header("Accept-Ranges", "bytes")
        self.send_header("Content-Length", str(length))
        self.send_header("Last-Modified", formatdate(os.path.getmtime(full), usegmt=True))
        self.send_header("Cache-Control", "no-cache")
        if status == HTTPStatus.PARTIAL_CONTENT:
            self.send_header("Content-Range", f"bytes {start}-{end}/{size}")
        self.end_headers()

        if self.command == "HEAD":
            return
        with open(full, "rb") as fh:
            fh.seek(start)
            remaining = length
            while remaining > 0:
                chunk = fh.read(min(64 * 1024, remaining))
                if not chunk:
                    break
                try:
                    self.wfile.write(chunk)
                except (BrokenPipeError, ConnectionResetError):
                    return
                remaining -= len(chunk)

    def do_GET(self):
        self.handle_request(head=False)

    def do_HEAD(self):
        self.handle_request(head=True)

    def handle_request(self, head):
        full = self._resolve()
        if full is None or not os.path.isfile(full):
            self.send_error(HTTPStatus.NOT_FOUND)
            return

        header = self.headers.get("Range")
        if header:
            m = RANGE_RE.match(header.strip())
            if m:
                size = os.path.getsize(full)
                raw_start, raw_end = m.groups()
                start = int(raw_start) if raw_start else max(0, size - int(raw_end or 0))
                end = int(raw_end) if (raw_end and raw_start) else size - 1
                if start >= size:
                    self.send_response(HTTPStatus.REQUESTED_RANGE_NOT_SATISFIABLE)
                    self.send_header("Content-Range", f"bytes */{size}")
                    self.send_header("Content-Length", "0")
                    self.end_headers()
                    return
                self._send_file(full, HTTPStatus.PARTIAL_CONTENT, start, end)
                return
        self._send_file(full)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", type=int, default=8080)
    ap.add_argument("--host", default="0.0.0.0")
    ap.add_argument("--dir", default="assets/cinematic-teaser")
    args = ap.parse_args()

    root = os.path.abspath(args.dir)
    Handler.root = root
    srv = ThreadingHTTPServer((args.host, args.port), Handler)
    print(f"отдаю {root} на http://{args.host}:{args.port}/player.html", flush=True)
    srv.serve_forever()


if __name__ == "__main__":
    main()
