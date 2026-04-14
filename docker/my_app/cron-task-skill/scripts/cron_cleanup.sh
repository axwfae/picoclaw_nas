#!/bin/bash
# cron_cleanup.sh - 清理孤立脚本（检查 run_sh 中是否有对应的任务）
# 核心职责：检查 run_sh 目录下的 .sh 文件是否在 cron_task.json 中有对应任务

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
WORKSPACE_DIR="${SKILL_DIR}/../../cron_task"
JSON_FILE="${WORKSPACE_DIR}/cron_task.json"
RUN_SH_DIR="${WORKSPACE_DIR}/run_sh"
LOG_FILE="${WORKSPACE_DIR}/execution.log"

[ ! -d "$RUN_SH_DIR" ] && exit 0

echo "[$(date '+%Y-%m-%d %H:%M:%S')] 🔍 检查孤立脚本..." >> "$LOG_FILE"

# 获取所有任务ID
TASK_IDS=$(jq -r '.tasks[].id' "$JSON_FILE" 2>/dev/null)

# 检查 run_sh 下的每个脚本
removed=0
for script in "$RUN_SH_DIR"/*.sh; do
    [ -f "$script" ] || continue
    
    script_name=$(basename "$script" .sh)
    
    # 检查是否在任务列表中
    if ! echo "$TASK_IDS" | grep -q "^${script_name}$"; then
        rm -f "$script"
        echo "    🗑️ 删除孤立脚本: ${script_name}.sh" >> "$LOG_FILE"
        removed=$((removed + 1))
    fi
done

if [ $removed -gt 0 ]; then
    echo "    ✓ 已清理 $removed 个孤立脚本" >> "$LOG_FILE"
else
    echo "    ✓ 无孤立脚本" >> "$LOG_FILE"
fi