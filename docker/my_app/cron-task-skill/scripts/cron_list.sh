#!/bin/bash
# cron_list.sh - 列出所有定时任务

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/cron_lib.sh"

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${CYAN}╭─────────────────────────────────────────────────────────────────────────╮${NC}"
echo -e "${CYAN}│${NC}                    🕐 定时任务列表                              ${CYAN}│${NC}"
echo -e "${CYAN}╰─────────────────────────────────────────────────────────────────────────╯${NC}"
echo ""

init_json

# 统计
total=$(jq '.tasks | length' "$JSON_FILE")
active=$(jq '[.tasks[] | select(.status == "active")] | length' "$JSON_FILE")
pending=$(jq '[.tasks[] | select(.status == "pending")] | length' "$JSON_FILE")

if [ "$total" -eq 0 ]; then
    echo -e "  ${YELLOW}暂无任务${NC}"
    echo "  运行 './cron_add.sh --help' 查看如何添加"
else
    # 使用 jq 格式化输出
    jq -r '.tasks[] | 
        "│ ID: " + .id + "\n" +
        "│ ✎ 名称: " + .name + "\n" +
        "│ ⏱ 类型: " + .type + " | ⌚ 模式: " + .mode + " | ● 状态: " + .status + "\n" +
        "│ ▶ 命令: " + (if startswith("ai:") then "🤖 " + .[4:] else . end) + "\n" +
        "│ ⏳ 间隔: " + (.interval | tostring) + "秒" + "\n" +
        "│ ⏰ 下次: " + (.next_run | if . != null then (todate | .[0:19]) else "N/A" end) + "\n│"
    ' "$JSON_FILE" | sed 's/│$//' | sed 's/$/│/'
fi

echo ""
echo -e "  ${CYAN}统计: 总计 $total | 活跃 $active | 待定 $pending${NC}"
echo ""

# 检查 cron 配置
CRON_LINE=$(crontab -l 2>/dev/null | grep "cron_task/scripts/cron_run.sh" | head -1)
if [ -z "$CRON_LINE" ]; then
    echo -e "  ${YELLOW}⚠ cron 未配置！${NC} 运行以下命令启用:"
    echo "    (crontab -l 2>/dev/null | grep -v 'cron_task'; echo '* * * * * cd $SCRIPT_DIR && ./cron_run.sh') | crontab -"
fi
