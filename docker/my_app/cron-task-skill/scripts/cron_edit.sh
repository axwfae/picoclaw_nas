#!/bin/bash
# cron_edit.sh - 修改任务属性
# 用法: ./cron_edit.sh <id> <field> <value>
# 字段: status, interval, command, name, next_run

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/cron_lib.sh"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

usage() {
    echo -e "${YELLOW}用法:${NC} $0 <id> <field> <value>"
    echo "  可修改字段: status, interval, command, name, next_run"
    echo "  状态值: pending, active, paused, completed"
    exit 1
}

if [ $# -lt 3 ]; then
    usage
fi

TARGET_ID="$1"
FIELD="$2"
VALUE="$3"

# 验证任务存在
if ! jq -e --arg tid "$TARGET_ID" '.tasks[] | select(.id == $tid)' "$JSON_FILE" > /dev/null 2>&1; then
    echo -e "${RED}未找到 ID 为 '$TARGET_ID' 的任务${NC}"
    exit 1
fi

# 数值字段
case "$FIELD" in
    interval|run_count|next_run|last_run)
        if [[ "$VALUE" =~ ^[0-9]+$ ]]; then
            update_task "$TARGET_ID" "$FIELD" "$VALUE"
        else
            echo -e "${RED}错误: $FIELD 必须是数字${NC}"
            exit 1
        fi
        ;;
    *)
        update_task "$TARGET_ID" "$FIELD" "$VALUE"
        ;;
esac

echo -e "${GREEN}✓ 已更新 $TARGET_ID 的 $FIELD = $VALUE${NC}"
