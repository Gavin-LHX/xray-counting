#!/usr/bin/env bash
set -euo pipefail

# Xray 客户端统计脚本（按来源 IP 去重）
# 直接运行：
#   bash cxc.sh
# 指定日志：
#   bash cxc.sh /var/log/xray/access.log
# 指定 TOP 数量：
#   bash cxc.sh /var/log/xray/access.log 30

LOG_FILE="${1:-/var/log/xray/access.log}"
TOP_N="${2:-10}"

if [[ ! -f "$LOG_FILE" ]]; then
  echo "错误：日志文件不存在 -> $LOG_FILE"
  echo "可用方法：bash cxc.sh /你的/access.log 路径 [TOP数量]"
  exit 1
fi

if ! [[ "$TOP_N" =~ ^[0-9]+$ ]] || [[ "$TOP_N" -le 0 ]]; then
  echo "错误：TOP 数量必须是正整数"
  echo "示例：bash cxc.sh /var/log/xray/access.log 10"
  exit 1
fi

if [[ ! -s "$LOG_FILE" ]]; then
  echo "统计结果：0 个客户端（按来源 IP 去重）"
  echo "原因：日志文件为空 -> $LOG_FILE"
  exit 0
fi

# 兼容常见 Xray access.log 格式中的来源字段：
# from 1.2.3.4:12345
# from [2408:xxxx::1]:12345
tmp_file="$(mktemp)"
trap 'rm -f "$tmp_file"' EXIT

awk '
{
  if (match($0, /from [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:[0-9]+/)) {
    s = substr($0, RSTART, RLENGTH)
    sub(/^from /, "", s)
    sub(/:[0-9]+$/, "", s)
    print s
  } else if (match($0, /from \[[0-9a-fA-F:]+\]:[0-9]+/)) {
    s = substr($0, RSTART, RLENGTH)
    sub(/^from \[/, "", s)
    sub(/\]:[0-9]+$/, "", s)
    print s
  }
}
' "$LOG_FILE" > "$tmp_file"

if [[ ! -s "$tmp_file" ]]; then
  echo "统计结果：0 个客户端（按来源 IP 去重）"
  echo "说明：日志里未匹配到 'from IP:端口' 格式。"
  exit 0
fi

UNIQUE_COUNT="$(sort -u "$tmp_file" | wc -l | tr -d ' ')"

echo "日志文件：$LOG_FILE"
echo "统计结果：$UNIQUE_COUNT 个客户端（按来源 IP 去重）"
echo
echo "活跃来源 IP TOP ${TOP_N}："
sort "$tmp_file" | uniq -c | sort -nr | head -n "$TOP_N" | awk '{printf "  %-6s %s\n", $1, $2}'
