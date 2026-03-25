#!/bin/bash
# cron_run.sh - 执行到期的定时任务（每分钟由 cron 调用）

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/cron_lib.sh"

LOCK_FILE="${WORKSPACE_DIR}/run.lock"

# ============ 锁机制 ============
if [ -f "$LOCK_FILE" ]; then
    LOCK_AGE=$(($(date +%s) - $(stat -c %Y "$LOCK_FILE" 2>/dev/null || echo 0)))
    if [ "$LOCK_AGE" -lt 300 ]; then
        exit 0  # 5 分钟内不重复执行
    fi
fi
echo "$(date +%s)" > "$LOCK_FILE"

# ============ 初始化 ============
init_json
CURRENT_TIME=$(get_timestamp)

echo "[$(date '+%Y-%m-%d %H:%M:%S')] 检查到期任务..." >> "$LOG_FILE"

executed=0
cleanup_counter="${WORKSPACE_DIR}/cleanup.counter"

# 计数器初始化
if [ ! -f "$cleanup_counter" ]; then
    echo "0" > "$cleanup_counter"
fi

# ============ 执行任务 ============
while IFS= read -r TASK_ID; do
    if [ -z "$TASK_ID" ]; then
        continue
    fi
    
    # 获取任务数据
    TASK_DATA=$(get_task "$TASK_ID")
    TASK_NAME=$(echo "$TASK_DATA" | jq -r '.name')
    TASK_CMD=$(echo "$TASK_DATA" | jq -r '.command')
    TASK_TYPE=$(echo "$TASK_DATA" | jq -r '.type')
    TASK_INTERVAL=$(echo "$TASK_DATA" | jq -r '.interval')
    TASK_MODE=$(echo "$TASK_DATA" | jq -r '.mode')
    TASK_RUN_COUNT=$(echo "$TASK_DATA" | jq -r '.run_count')
    
    echo ">>> 执行任务: $TASK_NAME (ID: $TASK_ID, 模式: $TASK_MODE)"
    
    # 执行任务
    execute_task "$TASK_ID" "$TASK_CMD" "$TASK_MODE"
    NEW_RUN_COUNT=$((TASK_RUN_COUNT + 1))
    
    # 更新任务状态
    if [ "$TASK_TYPE" = "once" ]; then
        del_task "$TASK_ID"
        echo "    [完成] 已移除（一次性任务）"
    else
        NEW_NEXT_RUN=$((CURRENT_TIME + TASK_INTERVAL))
        update_task "$TASK_ID" "last_run" "$CURRENT_TIME"
        update_task "$TASK_ID" "next_run" "$NEW_NEXT_RUN"
        update_task "$TASK_ID" "run_count" "$NEW_RUN_COUNT"
        echo "    [更新] 下次执行: $(format_time $NEW_NEXT_RUN)"
    fi
    
    executed=$((executed + 1))
done < <(list_due_tasks "$CURRENT_TIME")

# ============ 定期审查脚本（每小时一次）============
current_count=$(cat "$cleanup_counter" 2>/dev/null || echo "0")
next_count=$((current_count + 1))

# 每 60 次执行（约每小时）进行一次审查
if [ "$next_count" -ge 60 ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ⏰ 执行定期脚本审查..." >> "$LOG_FILE"
    bash "${SCRIPT_DIR}/cron_cleanup.sh" >> "$LOG_FILE" 2>&1
    echo "0" > "$cleanup_counter"
else
    echo "$next_count" > "$cleanup_counter"
fi

# ============ 清理 ============
if [ -f "$LOG_FILE" ]; then
    tail -n 500 "$LOG_FILE" > "${LOG_FILE}.tmp" && mv "${LOG_FILE}.tmp" "$LOG_FILE"
fi
rm -f "$LOCK_FILE"

if [ "$executed" -gt 0 ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✓ 本次执行了 $executed 个任务"
fi
