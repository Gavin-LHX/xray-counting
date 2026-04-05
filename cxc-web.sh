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

ACME_TOOL="${ACME_TOOL:-auto}"               # auto|acme.sh|certbot
ACME_DOMAIN="${ACME_DOMAIN:-}"
ACME_EMAIL="${ACME_EMAIL:-}"
ACME_SERVER="${ACME_SERVER:-letsencrypt}"
ACME_DNS_PROVIDER="${ACME_DNS_PROVIDER:-}"   # e.g. dns_cf, dns_dp
ACME_DNS_SLEEP="${ACME_DNS_SLEEP:-120}"      # DNS propagation seconds
ACME_WILDCARD="${ACME_WILDCARD:-0}"          # 1 = issue *.domain

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

ensure_acme_sh() {
  local email="$1"
  local acme_bin=""

  if command -v acme.sh >/dev/null 2>&1; then
    acme_bin="$(command -v acme.sh)"
  elif [[ -x "$HOME/.acme.sh/acme.sh" ]]; then
    acme_bin="$HOME/.acme.sh/acme.sh"
  else
    echo "???? acme.sh?????..."
    curl -fsSL https://get.acme.sh | sh -s email="$email"
    acme_bin="$HOME/.acme.sh/acme.sh"
  fi

  if [[ ! -x "$acme_bin" ]]; then
    echo "acme.sh ????"
    return 1
  fi

  echo "$acme_bin"
}

start() {
  if is_running; then
    echo "???????PID: $(cat "$PID_FILE")"
    exit 0
  fi

  extra_args=()
  scheme="http"
  if [[ "$HTTPS_ENABLE" == "1" ]]; then
    if [[ ! -f "$SSL_CERT" ]]; then
      echo "???????????? -> $SSL_CERT"
      exit 1
    fi
    if [[ ! -f "$SSL_KEY" ]]; then
      echo "???????????? -> $SSL_KEY"
      exit 1
    fi
    extra_args+=(--ssl-cert "$SSL_CERT" --ssl-key "$SSL_KEY")
    scheme="https"
  fi

  nohup python3 "$APP" --host 0.0.0.0 --port "$PORT" --log-file "$LOG_FILE" --top "$TOP_N" "${extra_args[@]}" >"$RUN_LOG" 2>&1 &
  echo $! > "$PID_FILE"
  sleep 1

  if is_running; then
    echo "????"
    echo "????: ${scheme}://$(public_ip):$PORT"
    echo "????: $RUN_LOG"
  else
    echo "??????????: $RUN_LOG"
    exit 1
  fi
}

stop() {
  if ! is_running; then
    echo "?????"
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
  echo "???"
}

status() {
  if is_running; then
    pid="$(cat "$PID_FILE")"
    echo "????PID: $pid"
    ss -lntp | grep ":$PORT" || true
  else
    echo "???"
  fi
}

acme_with_acmesh_standalone() {
  local domain="$1"
  local email="$2"
  local acme_bin
  acme_bin="$(ensure_acme_sh "$email")"

  if [[ -n "$email" ]]; then
    "$acme_bin" --register-account -m "$email" --server "$ACME_SERVER" || true
  fi

  "$acme_bin" --set-default-ca --server "$ACME_SERVER"
  "$acme_bin" --issue --standalone -d "$domain"
  "$acme_bin" --install-cert -d "$domain" \
    --key-file "$SSL_KEY" \
    --fullchain-file "$SSL_CERT"

  chmod 600 "$SSL_KEY" "$SSL_CERT"
}

acme_with_acmesh_dns() {
  local domain="$1"
  local email="$2"
  local acme_bin
  acme_bin="$(ensure_acme_sh "$email")"

  if [[ -n "$email" ]]; then
    "$acme_bin" --register-account -m "$email" --server "$ACME_SERVER" || true
  fi

  "$acme_bin" --set-default-ca --server "$ACME_SERVER"

  local dns_args=()
  if [[ -n "$ACME_DNS_PROVIDER" ]]; then
    dns_args=(--dns "$ACME_DNS_PROVIDER")
  else
    dns_args=(--dns --yes-I-know-dns-manual-mode-enough-go-ahead-please)
  fi

  if [[ "$ACME_WILDCARD" == "1" ]]; then
    "$acme_bin" --issue "${dns_args[@]}" --dnssleep "$ACME_DNS_SLEEP" -d "$domain" -d "*.$domain"
    "$acme_bin" --install-cert -d "$domain" \
      --key-file "$SSL_KEY" \
      --fullchain-file "$SSL_CERT"
  else
    "$acme_bin" --issue "${dns_args[@]}" --dnssleep "$ACME_DNS_SLEEP" -d "$domain"
    "$acme_bin" --install-cert -d "$domain" \
      --key-file "$SSL_KEY" \
      --fullchain-file "$SSL_CERT"
  fi

  chmod 600 "$SSL_KEY" "$SSL_CERT"
}

acme_with_certbot() {
  local domain="$1"
  local email="$2"
  local email_args=()

  if ! command -v certbot >/dev/null 2>&1; then
    echo "???? certbot"
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
}

acme() {
  local domain="${ACME_DOMAIN:-${2:-}}"
  local email="${ACME_EMAIL:-${3:-}}"

  if [[ -z "$domain" ]]; then
    echo "??: ACME_DOMAIN=example.com ACME_EMAIL=you@example.com bash cxc-web.sh acme"
    echo "?:   bash cxc-web.sh acme example.com you@example.com"
    return 1
  fi

  echo "???? Let's Encrypt ???standalone????: $domain"
  echo "????: $SSL_CERT"
  echo "????: $SSL_KEY"
  echo "???standalone ???? 80 ?????????"

  case "$ACME_TOOL" in
    auto)
      if command -v acme.sh >/dev/null 2>&1 || [[ -x "$HOME/.acme.sh/acme.sh" ]]; then
        acme_with_acmesh_standalone "$domain" "$email"
      elif command -v certbot >/dev/null 2>&1; then
        acme_with_certbot "$domain" "$email"
      else
        acme_with_acmesh_standalone "$domain" "$email"
      fi
      ;;
    acme.sh)
      acme_with_acmesh_standalone "$domain" "$email"
      ;;
    certbot)
      acme_with_certbot "$domain" "$email"
      ;;
    *)
      echo "ACME_TOOL ???: auto | acme.sh | certbot"
      return 1
      ;;
  esac

  echo "???????"
  echo "?????? HTTPS?"
  echo "HTTPS_ENABLE=1 PORT=443 SSL_CERT=$SSL_CERT SSL_KEY=$SSL_KEY bash cxc-web.sh restart"
}

acme_dns() {
  local domain="${ACME_DOMAIN:-${2:-}}"
  local email="${ACME_EMAIL:-${3:-}}"

  if [[ -z "$domain" ]]; then
    echo "??: ACME_DOMAIN=example.com ACME_EMAIL=you@example.com ACME_DNS_PROVIDER=dns_cf bash cxc-web.sh acme-dns"
    echo "?:   bash cxc-web.sh acme-dns example.com you@example.com"
    return 1
  fi

  echo "???? Let's Encrypt ???DNS ??????: $domain"
  echo "????: $SSL_CERT"
  echo "????: $SSL_KEY"
  if [[ -n "$ACME_DNS_PROVIDER" ]]; then
    echo "DNS Provider: $ACME_DNS_PROVIDER"
  else
    echo "DNS Provider: ???????? ACME_DNS_PROVIDER?"
  fi
  if [[ "$ACME_WILDCARD" == "1" ]]; then
    echo "??????: *.$domain"
  fi

  acme_with_acmesh_dns "$domain" "$email"

  echo "DNS ?????????"
  echo "?????? HTTPS?"
  echo "HTTPS_ENABLE=1 PORT=443 SSL_CERT=$SSL_CERT SSL_KEY=$SSL_KEY bash cxc-web.sh restart"
}

usage() {
  echo "??: bash cxc-web.sh {start|stop|restart|status|acme|acme-dns}"
  echo "HTTP ??: PORT=8080 TOP_N=10 bash cxc-web.sh start"
  echo "HTTPS ??: HTTPS_ENABLE=1 PORT=443 SSL_CERT=/root/fullchain.pem SSL_KEY=/root/privkey.pem bash cxc-web.sh start"
  echo "ACME(80??) ??: ACME_DOMAIN=example.com ACME_EMAIL=you@example.com bash cxc-web.sh acme"
  echo "ACME(DNS) ??: ACME_DOMAIN=example.com ACME_EMAIL=you@example.com ACME_DNS_PROVIDER=dns_cf bash cxc-web.sh acme-dns"
}

case "$cmd" in
  start) start ;;
  stop) stop ;;
  restart) stop; start ;;
  status) status ;;
  acme) acme "$@" ;;
  acme-dns) acme_dns "$@" ;;
  *)
    usage
    exit 1
    ;;
esac
