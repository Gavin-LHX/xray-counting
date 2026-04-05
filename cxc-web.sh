#!/usr/bin/env bash
set -euo pipefail

APP="/root/xray_dashboard.py"
LOG_FILE="${LOG_FILE:-/var/log/xray/access.log}"
HTTPS_ENABLE="${HTTPS_ENABLE:-0}"
SSL_CERT="${SSL_CERT:-/root/fullchain.pem}"
SSL_KEY="${SSL_KEY:-/root/privkey.pem}"
PORT="${PORT:-}"
TOP_N="${TOP_N:-10}"
PID_FILE="/tmp/xray_dashboard.pid"
RUN_LOG="/root/xray_dashboard.log"

ACME_TOOL="${ACME_TOOL:-auto}"         # auto|acme.sh|certbot
ACME_DOMAIN="${ACME_DOMAIN:-}"         # 可通过环境变量传入
ACME_EMAIL="${ACME_EMAIL:-}"           # 可选
ACME_SERVER="${ACME_SERVER:-letsencrypt}"

cmd="${1:-start}"

if [[ -z "$PORT" ]]; then
  if [[ "$HTTPS_ENABLE" == "1" ]]; then
    PORT="443"
  else
    PORT="8080"
  fi
fi

public_ip() {
  curl -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}'
}

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

  extra_args=()
  scheme="http"
  if [[ "$HTTPS_ENABLE" == "1" ]]; then
    if [[ ! -f "$SSL_CERT" ]]; then
      echo "启动失败：证书文件不存在 -> $SSL_CERT"
      exit 1
    fi
    if [[ ! -f "$SSL_KEY" ]]; then
      echo "启动失败：私钥文件不存在 -> $SSL_KEY"
      exit 1
    fi
    extra_args+=(--ssl-cert "$SSL_CERT" --ssl-key "$SSL_KEY")
    scheme="https"
  fi

  nohup python3 "$APP" --host 0.0.0.0 --port "$PORT" --log-file "$LOG_FILE" --top "$TOP_N" "${extra_args[@]}" >"$RUN_LOG" 2>&1 &
  echo $! > "$PID_FILE"
  sleep 1

  if is_running; then
    echo "启动成功"
    echo "访问地址: ${scheme}://$(public_ip):$PORT"
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

acme_with_acmesh() {
  local domain="$1"
  local email="$2"
  local acme_bin=""

  if command -v acme.sh >/dev/null 2>&1; then
    acme_bin="$(command -v acme.sh)"
  elif [[ -x "$HOME/.acme.sh/acme.sh" ]]; then
    acme_bin="$HOME/.acme.sh/acme.sh"
  else
    echo "未检测到 acme.sh，开始安装..."
    curl -fsSL https://get.acme.sh | sh -s email="$email"
    acme_bin="$HOME/.acme.sh/acme.sh"
  fi

  if [[ ! -x "$acme_bin" ]]; then
    echo "acme.sh 安装失败"
    return 1
  fi

  if [[ -n "$email" ]]; then
    "$acme_bin" --register-account -m "$email" --server "$ACME_SERVER" || true
  fi

  "$acme_bin" --set-default-ca --server "$ACME_SERVER"
  "$acme_bin" --issue --standalone -d "$domain"
  "$acme_bin" --install-cert -d "$domain" \
    --key-file "$SSL_KEY" \
    --fullchain-file "$SSL_CERT"

  chmod 600 "$SSL_KEY" "$SSL_CERT"
  return 0
}

acme_with_certbot() {
  local domain="$1"
  local email="$2"
  local email_args=()

  if ! command -v certbot >/dev/null 2>&1; then
    echo "未检测到 certbot"
    return 1
  fi

  if [[ -n "$email" ]]; then
    email_args=(-m "$email")
  else
    email_args=(--register-unsafely-without-email)
  fi

  certbot certonly --standalone --non-interactive --agree-tos \
    "${email_args[@]}" -d "$domain" --keep-until-expiring

  install -m 600 "/etc/letsencrypt/live/$domain/fullchain.pem" "$SSL_CERT"
  install -m 600 "/etc/letsencrypt/live/$domain/privkey.pem" "$SSL_KEY"
  return 0
}

acme() {
  local domain="${ACME_DOMAIN:-${2:-}}"
  local email="${ACME_EMAIL:-${3:-}}"

  if [[ -z "$domain" ]]; then
    echo "用法: ACME_DOMAIN=example.com ACME_EMAIL=you@example.com bash cxc-web.sh acme"
    echo "或:   bash cxc-web.sh acme example.com you@example.com"
    return 1
  fi

  echo "开始申请 Let's Encrypt 证书，域名: $domain"
  echo "证书输出: $SSL_CERT"
  echo "私钥输出: $SSL_KEY"
  echo "注意：申请时会使用 standalone 模式，需要 80 端口可被外网访问。"

  case "$ACME_TOOL" in
    auto)
      if command -v acme.sh >/dev/null 2>&1 || [[ -x "$HOME/.acme.sh/acme.sh" ]]; then
        acme_with_acmesh "$domain" "$email"
      elif command -v certbot >/dev/null 2>&1; then
        acme_with_certbot "$domain" "$email"
      else
        acme_with_acmesh "$domain" "$email"
      fi
      ;;
    acme.sh)
      acme_with_acmesh "$domain" "$email"
      ;;
    certbot)
      acme_with_certbot "$domain" "$email"
      ;;
    *)
      echo "ACME_TOOL 仅支持: auto | acme.sh | certbot"
      return 1
      ;;
  esac

  echo "证书申请完成。"
  echo "现在可以启用 HTTPS："
  echo "HTTPS_ENABLE=1 PORT=443 SSL_CERT=$SSL_CERT SSL_KEY=$SSL_KEY bash cxc-web.sh restart"
}

usage() {
  echo "用法: bash cxc-web.sh {start|stop|restart|status|acme}"
  echo "HTTP 示例: PORT=8080 TOP_N=10 bash cxc-web.sh start"
  echo "HTTPS 示例: HTTPS_ENABLE=1 PORT=443 SSL_CERT=/root/fullchain.pem SSL_KEY=/root/privkey.pem bash cxc-web.sh start"
  echo "ACME 示例: ACME_DOMAIN=example.com ACME_EMAIL=you@example.com bash cxc-web.sh acme"
}

case "$cmd" in
  start) start ;;
  stop) stop ;;
  restart) stop; start ;;
  status) status ;;
  acme) acme "$@" ;;
  *)
    usage
    exit 1
    ;;
esac
