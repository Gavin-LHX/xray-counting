#!/usr/bin/env bash
set -euo pipefail

# Count connected Xray clients by unique source IP in access.log
# Examples:
#   ./count_xray_clients.sh
#   ./count_xray_clients.sh -f /var/log/xray/access.log -m 60
#   ./count_xray_clients.sh -f /var/log/xray/access.log -m 30 -t 20

LOG_FILE="/var/log/xray/access.log"
MINUTES=0
TOPN=10

usage() {
  cat <<'EOF'
Usage: count_xray_clients.sh [options]

Options:
  -f <path>   Path to access.log (default: /var/log/xray/access.log)
  -m <num>    Only count last <num> minutes, 0 means all logs (default: 0)
  -t <num>    Show Top N active client IPs (default: 10)
  -h          Show help

Notes:
  1) Client count is based on unique source IP in access.log.
  2) If many clients are behind the same NAT, result will be smaller than real users.
EOF
}

while getopts ":f:m:t:h" opt; do
  case "$opt" in
    f) LOG_FILE="$OPTARG" ;;
    m) MINUTES="$OPTARG" ;;
    t) TOPN="$OPTARG" ;;
    h)
      usage
      exit 0
      ;;
    \?)
      echo "Unknown option: -$OPTARG" >&2
      usage
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires a value" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ ! -f "$LOG_FILE" ]]; then
  echo "Log file not found: $LOG_FILE" >&2
  exit 1
fi

if ! [[ "$MINUTES" =~ ^[0-9]+$ ]]; then
  echo "-m must be a non-negative integer" >&2
  exit 1
fi

if ! [[ "$TOPN" =~ ^[0-9]+$ ]] || [[ "$TOPN" -eq 0 ]]; then
  echo "-t must be a positive integer" >&2
  exit 1
fi

NOW_EPOCH="$(date +%s)"
SINCE_EPOCH=0
if [[ "$MINUTES" -gt 0 ]]; then
  SINCE_EPOCH=$((NOW_EPOCH - MINUTES * 60))
fi

# Match source like: from 1.2.3.4:5678
# Time format expected at beginning: YYYY/MM/DD HH:MM:SS
RESULT="$(
awk -v since="$SINCE_EPOCH" '
function to_epoch(d, t,  cmd, e) {
  gsub(/\//, "-", d)
  cmd = "date -d \"" d " " t "\" +%s 2>/dev/null"
  cmd | getline e
  close(cmd)
  return e + 0
}
{
  d = $1
  t = $2
  if (since > 0) {
    ts = to_epoch(d, t)
    if (ts < since) next
  }

  if ($0 ~ /from [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:[0-9]+/) {
    line = $0
    sub(/^.*from /, "", line)
    sub(/:[0-9]+.*$/, "", line)
    if (line ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/) {
      cnt[line]++
    }
  }
}
END {
  total = 0
  for (ip in cnt) total++
  print total
  for (ip in cnt) print cnt[ip], ip
}
' "$LOG_FILE"
)"

CLIENT_COUNT="$(echo "$RESULT" | head -n1)"
DETAIL_LINES="$(echo "$RESULT" | tail -n +2)"

if [[ "$MINUTES" -gt 0 ]]; then
  echo "Range: last $MINUTES minute(s)"
else
  echo "Range: all logs"
fi
echo "Log: $LOG_FILE"
echo "Unique clients (by IP): $CLIENT_COUNT"

if [[ -n "$DETAIL_LINES" ]]; then
  echo
  echo "Top $TOPN active client IPs:"
  echo "$DETAIL_LINES" | sort -nr | head -n "$TOPN" | awk '{printf "%-8s %s\n", $1, $2}'
fi
