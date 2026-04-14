#!/bin/bash
# cron_run.sh - 定时任务执行器（由系统 cron 每分钟调用）
# 核心职责：读取 cron_task.json，执行到期的任务

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
WORKSPACE_DIR="${SKILL_DIR}/../../cron_task"
JSON_FILE="${WORKSPACE_DIR}/cron_task.json"
LOG_FILE="${WORKSPACE_DIR}/execution.log"
RUN_SH_DIR="${WORKSPACE_DIR}/run_sh"
LOCK_FILE="${WORKSPACE_DIR}/run.lock"

# ============ 锁机制（防止并发）============
if [ -f "$LOCK_FILE" ]; then
    LOCK_AGE=$(($(date +%s) - $(stat -c %Y "$LOCK_FILE" 2>/dev/null || echo 0)))
    if [ "$LOCK_AGE" -lt 120 ]; then
        exit 0  # 2 分钟内不重复执行
    fi
fi
echo "$(date +%s)" > "$LOCK_FILE"

# ============ 初始化 ============
[ ! -d "$WORKSPACE_DIR" ] && mkdir -p "$WORKSPACE_DIR"
[ ! -d "$RUN_SH_DIR" ] && mkdir -p "$RUN_SH_DIR"
[ ! -f "$JSON_FILE" ] && echo '{"tasks":[]}' > "$JSON_FILE"

# ============ 函数定义（必须放在前面）============

# Cron 表达式计算（纯 Bash）
calculate_next_cron_run() {
    local cron_expr="$1"
    local from_time="${2:-$(date +%s)}"
    
    read minute hour day month dow <<< "$cron_expr"
    
    local current="$from_time"
    for ((i=0; i<525600; i++)); do  # 最多查一年
        local min h d mo w
        min=$(date -d "@$current" +%M)
        h=$(date -d "@$current" +%H)
        d=$(date -d "@$current" +%d)
        mo=$(date -d "@$current" +%m)
        w=$(date -d "@$current" +%w)
        
        matches "$minute" "$min" && matches "$hour" "$h" && \
        matches "$day" "$d" && matches "$month" "$mo" && matches "$dow" "$w" && echo "$current" && return 0
        
        current=$((current + 60))
    done
    
    echo $((from_time + 3600))
}

matches() {
    local expr="$1" val="$2"
    [ "$expr" = "*" ] && return 0
    [[ "$expr" == */* ]] && [ $(($val % ${expr#*/})) -eq 0 ] && return 0
    [[ "$expr" == *-* ]] && [[ "$expr" == ${expr%-*}-${expr#*-} ]] && {
        local s="${expr%-*}"; local e="${expr#*-}"
        [ "$val" -ge "$s" ] && [ "$val" -le "$e" ] && return 0
        return 1
    }
    [[ "$expr" == *,* ]] && {
        local IFS=','; for v in $expr; do [ "$val" -eq "$v" ] && return 0; done; return 1
    }
    [ "$val" -eq "$expr" ] && return 0
    return 1
}

# 任务执行
execute_task() {
    local task_id="$1" command="$2" mode="$3"
    
    if [ "$mode" = "ai" ]; then
        local prompt="${command#ai:}"
        echo "[AI] $prompt" >> "$LOG_FILE"
        /usr/local/bin/picoclaw agent -m "$prompt" >> "$LOG_FILE" 2>&1
    else
        local actual_cmd="${command#shell:}"
        actual_cmd="${actual_cmd#bash }"
        bash -c "$actual_cmd" >> "$LOG_FILE" 2>&1
        [ $? -ne 0 ] && echo "[ERROR] exit: $?" >> "$LOG_FILE"
    fi
}

# ============ 主逻辑 ============
CURRENT_TIME=$(date +%s)

# ============ 查找到期任务 ============
# 状态为 active/pending，且 next_run <= 当前时间
DUE_TASKS=$(jq -r --argjson ct "$CURRENT_TIME" \
    '.tasks[] | select(.status == "active" or .status == "pending") | select(.next_run <= $ct) | @json' \
    "$JSON_FILE" 2>/dev/null)

if [ -z "$DUE_TASKS" ]; then
    rm -f "$LOCK_FILE"
    exit 0
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] 检查到期任务..." >> "$LOG_FILE"

# ============ 执行每个到期任务 ============
echo "$DUE_TASKS" | jq -r '.id' | while read TASK_ID; do
    [ -z "$TASK_ID" ] && continue
    
    # 重新获取任务数据（确保最新）
    TASK=$(jq --arg id "$TASK_ID" -r '.tasks[] | select(.id == $id)' "$JSON_FILE")
    [ -z "$TASK" ] && continue
    
    NAME=$(echo "$TASK" | jq -r '.name')
    CMD=$(echo "$TASK" | jq -r '.command')
    MODE=$(echo "$TASK" | jq -r '.mode')
    TYPE=$(echo "$TASK" | jq -r '.type')
    INTERVAL=$(echo "$TASK" | jq -r '.interval')
    CRON_EXPR=$(echo "$TASK" | jq -r '.cron_expr // empty')
    RUN_COUNT=$(echo "$TASK" | jq -r '.run_count')
    
    echo ">>> 执行: $NAME (ID: $TASK_ID, 模式: $MODE)"
    
    # 执行任务
    execute_task "$TASK_ID" "$CMD" "$MODE"
    
    # 计算下次执行时间
    if [ "$TYPE" = "once" ]; then
        # 一次性任务：删除
        jq --arg id "$TASK_ID" 'del(.tasks[] | select(.id == $id))' "$JSON_FILE" > "${JSON_FILE}.tmp" && mv "${JSON_FILE}.tmp" "$JSON_FILE"
        echo "    ✓ 已完成（一次性任务已移除）"
    elif [ "$TYPE" = "cron" ] && [ -n "$CRON_EXPR" ]; then
        # Cron 任务：计算下次时间
        NEXT_RUN=$(calculate_next_cron_run "$CRON_EXPR" "$CURRENT_TIME")
        jq --arg id "$TASK_ID" --argjson next "$NEXT_RUN" --argjson last "$CURRENT_TIME" --argjson rc "$((RUN_COUNT + 1))" \
            '.tasks[] |= if .id == $id then .next_run = $next | .last_run = $last | .run_count = $rc else . end' \
            "$JSON_FILE" > "${JSON_FILE}.tmp" && mv "${JSON_FILE}.tmp" "$JSON_FILE"
        echo "    ✓ 下次: $(date -d "@$NEXT_RUN" '+%m-%d %H:%M')"
    else
        # 间隔任务
        NEXT_RUN=$((CURRENT_TIME + INTERVAL))
        jq --arg id "$TASK_ID" --argjson next "$NEXT_RUN" --argjson last "$CURRENT_TIME" --argjson rc "$((RUN_COUNT + 1))" \
            '.tasks[] |= if .id == $id then .next_run = $next | .last_run = $last | .run_count = $rc else . end' \
            "$JSON_FILE" > "${JSON_FILE}.tmp" && mv "${JSON_FILE}.tmp" "$JSON_FILE"
        echo "    ✓ 下次: $(date -d "@$NEXT_RUN" '+%m-%d %H:%M')"
    fi
done

# ============ 清理 ============
rm -f "$LOCK_FILE"

# 每整点或半点清理一次
CLEANUP_SCRIPT="${SCRIPT_DIR}/cron_cleanup.sh"
CURRENT_MIN=$(date +%M)
if [ -x "$CLEANUP_SCRIPT" ] && [ "$CURRENT_MIN" = "00" -o "$CURRENT_MIN" = "30" ]; then
    bash "$CLEANUP_SCRIPT"
fi

# 限制日志行数
[ -f "$LOG_FILE" ] && tail -n 200 "$LOG_FILE" > "${LOG_FILE}.tmp" && mv "${LOG_FILE}.tmp" "$LOG_FILE"