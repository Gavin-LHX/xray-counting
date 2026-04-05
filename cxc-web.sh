#!/usr/bin/env bash
set -euo pipefail

APP="/root/xray_dashboard.py"
LOG_FILE="/var/log/xray/access.log"
PORT="${PORT:-8080}"
TOP_N="${TOP_N:-10}"
PID_FILE="/tmp/xray_dashboard.pid"
RUN_LOG="/root/xray_dashboard.log"

cmd="${1:-start}"

is_running() {
  if [[ -f "$PID_FILE" ]]; then
    pid="$(cat "$PID_FILE" 2>/dev/null || true)"
    if [[ -n "${pid:-}" ]] && kill -0 "$pid" 2>/dev/null; then
      return 0
    fi
  fi
  pid="$(pgrep -f "python3 $APP" | head -n1 || true)"
  if [[ -n "${pid:-}" ]] && kill -0 "$pid" 2>/dev/null; then
    echo "$pid" > "$PID_FILE"
    return 0
  fi
  return 1
}

start() {
  if is_running; then
    echo "网站已在运行，PID: $(cat "$PID_FILE")"
    exit 0
  fi
  nohup python3 "$APP" --host 0.0.0.0 --port "$PORT" --log-file "$LOG_FILE" --top "$TOP_N" >"$RUN_LOG" 2>&1 &
  echo $! > "$PID_FILE"
  sleep 1
  if is_running; then
    echo "启动成功"
    echo "访问地址: http://$(curl -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}'):$PORT"
    echo "日志文件: $RUN_LOG"
  else
    echo "启动失败，请检查日志: $RUN_LOG"
    exit 1
  fi
}

stop() {
  if ! is_running; then
    echo "网站未运行"
    rm -f "$PID_FILE"
    return 0
  fi
  pid="$(cat "$PID_FILE")"
  kill "$pid" || true
  sleep 1
  if kill -0 "$pid" 2>/dev/null; then
    kill -9 "$pid" || true
  fi
  rm -f "$PID_FILE"
  echo "已停止"
}

status() {
  if is_running; then
    pid="$(cat "$PID_FILE")"
    echo "运行中，PID: $pid"
    ss -lntp | grep ":$PORT" || true
  else
    echo "未运行"
  fi
}

case "$cmd" in
  start) start ;;
  stop) stop ;;
  restart) stop; start ;;
  status) status ;;
  *)
    echo "用法: bash cxc-web.sh {start|stop|restart|status}"
    exit 1
    ;;
esac
