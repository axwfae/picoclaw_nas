#!/bin/bash
# cron_add.sh - 添加定时任务
# 用法: ./cron_add.sh <名称> <命令> <间隔> [类型] [模式]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/cron_lib.sh"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

show_help() {
    cat << EOF
${GREEN}添加定时任务${NC}

${YELLOW}用法:${NC}
  $0 <名称> <命令> <间隔> [类型] [模式]

${YELLOW}参数:${NC}
  名称    任务描述（必填）
  命令    Shell 命令 或 AI 提示词（必填）
  间隔    间隔秒数（必填）
  类型    once|interval（默认: once）
  模式    shell|ai（默认: shell）

${YELLOW}示例:${NC}
  $0 "备份数据库" "tar -czf backup.tar /data" 3600
  $0 "健康提醒" "ai:提醒我站起来活动一下" 1800 interval ai
  $0 "天气播报" "ai:用中文播报今天的天气" 43200 interval ai
EOF
}

# 默认值
NAME=""
COMMAND=""
INTERVAL=""
TYPE="once"
MODE="shell"

if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    show_help
    exit 0
fi

if [ $# -lt 3 ]; then
    echo -e "${RED}错误: 参数不足${NC}"
    show_help
    exit 1
fi

NAME="$1"
COMMAND="$2"
INTERVAL="$3"

if [ "$4" = "ai" ]; then
    MODE="ai"
    TYPE="interval"
elif [ -n "$4" ]; then
    TYPE="$4"
fi

if [ -n "$5" ]; then
    MODE="$5"
fi

# 验证间隔
if ! [[ "$INTERVAL" =~ ^[0-9]+$ ]] || [ "$INTERVAL" -lt 1 ]; then
    echo -e "${RED}错误: 间隔必须是正整数${NC}"
    exit 1
fi

# 添加任务
TASK_ID=$(add_task "$NAME" "$COMMAND" "$INTERVAL" "$TYPE" "$MODE")

if [ -n "$TASK_ID" ]; then
    echo -e "${GREEN}✓ 任务已添加${NC}"
    echo "  ID:     $TASK_ID"
    echo "  名称:   $NAME"
    echo "  模式:   $MODE"
    echo "  类型:   $TYPE"
    echo "  间隔:   ${INTERVAL}秒"
else
    echo -e "${RED}✗ 添加失败${NC}"
    exit 1
fi
