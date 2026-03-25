#!/bin/bash
# cron_del.sh - 删除定时任务
# 用法: ./cron_del.sh <id> 或 ./cron_del.sh --name <名称>

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/cron_lib.sh"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

usage() {
    echo -e "${YELLOW}用法:${NC} $0 <id> 或 $0 --name <任务名称>"
    exit 1
}

if [ $# -eq 0 ]; then
    usage
fi

if [ "$1" = "--name" ]; then
    if [ -z "$2" ]; then
        echo -e "${RED}错误: 请提供任务名称${NC}"
        usage
    fi
    TARGET_ID=$(jq -r --arg name "$2" '.tasks[] | select(.name == $name) | .id' "$JSON_FILE" | head -1)
    if [ -z "$TARGET_ID" ] || [ "$TARGET_ID" = "null" ]; then
        echo -e "${RED}未找到名称为 '$2' 的任务${NC}"
        exit 1
    fi
else
    TARGET_ID="$1"
    # 验证 ID 存在
    if ! jq -e --arg tid "$TARGET_ID" '.tasks[] | select(.id == $tid)' "$JSON_FILE" > /dev/null 2>&1; then
        echo -e "${RED}未找到 ID 为 '$TARGET_ID' 的任务${NC}"
        exit 1
    fi
fi

del_task "$TARGET_ID"
echo -e "${GREEN}✓ 任务已删除 (ID: $TARGET_ID)${NC}"
