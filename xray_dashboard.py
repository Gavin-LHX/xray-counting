#!/usr/bin/env python3
import argparse
import html
import os
import re
import ssl
from collections import Counter
from datetime import datetime
from http.server import BaseHTTPRequestHandler, HTTPServer
from socketserver import ThreadingMixIn


IPV4_RE = re.compile(r"from ((?:\d{1,3}\.){3}\d{1,3}):\d+")
IPV6_RE = re.compile(r"from \[([0-9a-fA-F:]+)\]:\d+")


def parse_ips(log_file: str):
    ips = []
    if not os.path.isfile(log_file):
        return ips, "日志文件不存在"
    try:
        with open(log_file, "r", encoding="utf-8", errors="ignore") as f:
            for line in f:
                m4 = IPV4_RE.search(line)
                if m4:
                    ips.append(m4.group(1))
                    continue
                m6 = IPV6_RE.search(line)
                if m6:
                    ips.append(m6.group(1))
    except Exception as e:
        return [], f"读取日志失败: {e}"
    return ips, ""


def render_page(log_file: str, top_n: int):
    ips, err = parse_ips(log_file)
    counter = Counter(ips)
    unique_count = len(counter)
    total_hits = sum(counter.values())
    now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    rows = []
    for i, (ip, cnt) in enumerate(counter.most_common(top_n), start=1):
        rows.append(
            f"<tr><td>{i}</td><td>{html.escape(ip)}</td><td>{cnt}</td></tr>"
        )
    rows_html = "\n".join(rows) if rows else '<tr><td colspan="3">暂无数据</td></tr>'

    err_html = f'<p class="warn">{html.escape(err)}</p>' if err else ""

    return f"""<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width,initial-scale=1" />
  <meta http-equiv="refresh" content="15" />
  <title>Xray 客户端统计面板</title>
  <style>
    :root {{
      --bg: #0b1220;
      --card: #111a2e;
      --text: #e8eefc;
      --muted: #9db0d9;
      --accent: #4fd1c5;
      --line: #233252;
      --warn: #ffd166;
    }}
    body {{
      margin: 0;
      font-family: "Segoe UI", "PingFang SC", "Microsoft YaHei", sans-serif;
      background: radial-gradient(1200px 500px at 20% -10%, #1f2d50 0%, var(--bg) 60%);
      color: var(--text);
    }}
    .wrap {{
      max-width: 980px;
      margin: 28px auto;
      padding: 0 16px;
    }}
    .card {{
      background: var(--card);
      border: 1px solid var(--line);
      border-radius: 14px;
      padding: 18px;
      margin-bottom: 14px;
      box-shadow: 0 10px 30px rgba(0,0,0,0.25);
    }}
    h1 {{ margin: 0 0 8px; font-size: 24px; }}
    .meta {{ color: var(--muted); font-size: 14px; }}
    .stats {{
      display: grid;
      grid-template-columns: repeat(2, minmax(0, 1fr));
      gap: 10px;
      margin-top: 12px;
    }}
    .stat {{
      border: 1px solid var(--line);
      border-radius: 10px;
      padding: 12px;
      background: rgba(255,255,255,0.02);
    }}
    .label {{ color: var(--muted); font-size: 12px; }}
    .value {{ font-size: 28px; font-weight: 700; color: var(--accent); }}
    table {{
      width: 100%;
      border-collapse: collapse;
      margin-top: 8px;
    }}
    th, td {{
      border-bottom: 1px solid var(--line);
      text-align: left;
      padding: 10px 8px;
      font-size: 14px;
    }}
    th {{ color: var(--muted); font-weight: 600; }}
    .warn {{ color: var(--warn); }}
  </style>
</head>
<body>
  <div class="wrap">
    <div class="card">
      <h1>Xray 客户端统计面板</h1>
      <div class="meta">更新时间: {now}（每 15 秒自动刷新）</div>
      <div class="meta">日志路径: {html.escape(log_file)}</div>
      {err_html}
      <div class="stats">
        <div class="stat">
          <div class="label">客户端数（来源 IP 去重）</div>
          <div class="value">{unique_count}</div>
        </div>
        <div class="stat">
          <div class="label">请求命中总次数（日志匹配条数）</div>
          <div class="value">{total_hits}</div>
        </div>
      </div>
    </div>
    <div class="card">
      <h1>活跃来源 IP TOP {top_n}</h1>
      <table>
        <thead><tr><th>排名</th><th>来源 IP</th><th>次数</th></tr></thead>
        <tbody>
          {rows_html}
        </tbody>
      </table>
    </div>
  </div>
</body>
</html>
"""


class Handler(BaseHTTPRequestHandler):
    log_file = "/var/log/xray/access.log"
    top_n = 10

    def do_GET(self):
        if self.path not in ("/", "/index.html"):
            self.send_response(404)
            self.end_headers()
            self.wfile.write(b"404")
            return
        body = render_page(self.log_file, self.top_n).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_HEAD(self):
        if self.path not in ("/", "/index.html"):
            self.send_response(404)
            self.end_headers()
            return
        body = render_page(self.log_file, self.top_n).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()

    def log_message(self, fmt, *args):
        return


class ThreadingHTTPServer(ThreadingMixIn, HTTPServer):
    daemon_threads = True


def main():
    parser = argparse.ArgumentParser(description="Xray dashboard")
    parser.add_argument("--host", default="0.0.0.0", help="listen host")
    parser.add_argument("--port", type=int, default=8080, help="listen port")
    parser.add_argument("--log-file", default="/var/log/xray/access.log", help="xray access.log path")
    parser.add_argument("--top", type=int, default=10, help="top n ips")
    parser.add_argument("--ssl-cert", default="", help="TLS cert path (PEM)")
    parser.add_argument("--ssl-key", default="", help="TLS private key path (PEM)")
    args = parser.parse_args()

    if args.top <= 0:
        raise SystemExit("--top must be positive")

    Handler.log_file = args.log_file
    Handler.top_n = args.top

    server = ThreadingHTTPServer((args.host, args.port), Handler)
    scheme = "http"
    if args.ssl_cert or args.ssl_key:
        if not (args.ssl_cert and args.ssl_key):
            raise SystemExit("Both --ssl-cert and --ssl-key are required for HTTPS")
        if not os.path.isfile(args.ssl_cert):
            raise SystemExit(f"SSL cert not found: {args.ssl_cert}")
        if not os.path.isfile(args.ssl_key):
            raise SystemExit(f"SSL key not found: {args.ssl_key}")
        context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        context.load_cert_chain(certfile=args.ssl_cert, keyfile=args.ssl_key)
        server.socket = context.wrap_socket(server.socket, server_side=True)
        scheme = "https"

    print(f"Dashboard running on {scheme}://{args.host}:{args.port}")
    print(f"log file: {args.log_file}, top: {args.top}")
    server.serve_forever()


if __name__ == "__main__":
    main()
