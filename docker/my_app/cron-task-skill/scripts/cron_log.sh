#!/bin/bash
# cron_log.sh - 查看任务执行日志
# 用法: ./cron_log.sh [行数]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/cron_lib.sh"

LINES="${1:-50}"

echo "════════════════════════════════════════════════════════════"
echo "                  任务执行日志 (最后 $LINES 条)"
echo "════════════════════════════════════════════════════════════"
echo ""

if [ ! -f "$LOG_FILE" ]; then
    echo "暂无日志记录"
else
    tail -n "$LINES" "$LOG_FILE"
fi

echo ""
echo "════════════════════════════════════════════════════════════"
