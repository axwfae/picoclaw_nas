#!/bin/bash
# cron_lib.sh - 定时任务管理公共函数
# 依赖: jq, date

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
WORKSPACE_DIR="${SKILL_DIR}/../../cron_task"
JSON_FILE="${WORKSPACE_DIR}/cron_task.json"
LOG_FILE="${WORKSPACE_DIR}/execution.log"

# 检查 jq
if ! command -v jq &> /dev/null; then
    echo "错误: 需要 jq 但未安装" >&2
    exit 1
fi

# 初始化 JSON 文件
init_json() {
    if [ ! -d "$WORKSPACE_DIR" ]; then
        mkdir -p "$WORKSPACE_DIR"
    fi
    if [ ! -f "$JSON_FILE" ]; then
        echo '{"tasks":[],"version":"1.0","created":"'"$(date -Iseconds)"'"}' > "$JSON_FILE"
    fi
}

# 生成唯一 ID
generate_id() {
    echo "$(date +%s)-$((RANDOM % 10000))"
}

# 获取当前时间戳
get_timestamp() {
    date +%s
}

# 格式化时间戳
format_time() {
    local ts="$1"
    if [ "$ts" = "null" ] || [ -z "$ts" ]; then
        echo "N/A"
    else
        date -d "@$ts" '+%Y-%m-%d %H:%M:%S'
    fi
}

# 相对时间
format_relative() {
    local ts="$1"
    if [ "$ts" = "null" ] || [ -z "$ts" ]; then
        echo "N/A"
    else
        local diff=$((ts - $(date +%s)))
        if [ $diff -lt 0 ]; then
            echo "已到期"
        elif [ $diff -lt 60 ]; then
            echo "${diff}秒后"
        elif [ $diff -lt 3600 ]; then
            echo "$((diff / 60))分钟后"
        elif [ $diff -lt 86400 ]; then
            echo "$((diff / 3600))小时后"
        else
            echo "$((diff / 86400))天后"
        fi
    fi
}

# 添加任务
add_task() {
    local name="$1"
    local command="$2"
    local interval="$3"
    local task_type="$4"
    local mode="$5"
    
    init_json
    
    local id=$(generate_id)
    local created=$(get_timestamp)
    
    local full_cmd="$command"
    if [ "$mode" = "ai" ]; then
        full_cmd="ai:${command}"
    fi
    
    local next_run=$((created + interval))
    
    jq --arg id "$id" \
       --arg type "$task_type" \
       --arg name "$name" \
       --arg cmd "$full_cmd" \
       --argjson interval "$interval" \
       --arg status "active" \
       --argjson created "$created" \
       --argjson next_run "$next_run" \
       --argjson last_run 0 \
       --argjson run_count 0 \
       --arg mode "$mode" \
       '.tasks += [{
           "id": $id,
           "type": $type,
           "name": $name,
           "command": $cmd,
           "interval": $interval,
           "status": $status,
           "created": $created,
           "next_run": $next_run,
           "last_run": $last_run,
           "run_count": $run_count,
           "mode": $mode
       }]' "$JSON_FILE" > "${JSON_FILE}.tmp" && mv "${JSON_FILE}.tmp" "$JSON_FILE"
    
    echo "$id"
}

# 删除任务
del_task() {
    local task_id="$1"
    init_json
    jq --arg tid "$task_id" 'del(.tasks[] | select(.id == $tid))' "$JSON_FILE" > "${JSON_FILE}.tmp" && mv "${JSON_FILE}.tmp" "$JSON_FILE"
}

# 更新任务
update_task() {
    local task_id="$1"
    local field="$2"
    local value="$3"
    init_json
    
    if [ "$field" = "interval" ] || [ "$field" = "run_count" ] || [ "$field" = "last_run" ] || [ "$field" = "next_run" ]; then
        jq --arg tid "$task_id" --arg field "$field" --argjson val "$value" \
           '.tasks[] |= if .id == $tid then .[$field] = $val else . end' \
           "$JSON_FILE" > "${JSON_FILE}.tmp" && mv "${JSON_FILE}.tmp" "$JSON_FILE"
    else
        jq --arg tid "$task_id" --arg field "$field" --arg val "$value" \
           '.tasks[] |= if .id == $tid then .[$field] = $val else . end' \
           "$JSON_FILE" > "${JSON_FILE}.tmp" && mv "${JSON_FILE}.tmp" "$JSON_FILE"
    fi
}

# 执行任务
execute_task() {
    local task_id="$1"
    local command="$2"
    local mode="$3"
    
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 执行任务: $task_id" >> "$LOG_FILE"
    
    if [ "$mode" = "ai" ]; then
        local prompt="${command#ai:}"
        echo "  模式: AI" >> "$LOG_FILE"
        echo "  提示词: $prompt" >> "$LOG_FILE"
        
        local result=$(/usr/local/bin/picoclaw agent -m "$prompt" 2>&1)
        local exit_code=$?
        
        if [ $exit_code -eq 0 ]; then
            echo "  状态: ✓ 成功" >> "$LOG_FILE"
        else
            echo "  状态: ✗ 失败 (退出码: $exit_code)" >> "$LOG_FILE"
        fi
        if [ -n "$result" ]; then
            echo "  输出: $result" >> "$LOG_FILE"
        fi
    else
        echo "  模式: Shell" >> "$LOG_FILE"
        echo "  命令: $command" >> "$LOG_FILE"
        
        # 提取實際命令（去掉 shell:bash 前綴）
        local actual_cmd="${command#shell:bash }"
        if [ "$actual_cmd" = "$command" ]; then
            # 沒有前綴，嘗試去掉 shell: 前綴
            actual_cmd="${command#shell:}"
        fi
        
        # 使用 cron_create_script.sh 創建可執行腳本（強制使用任務ID命名）
        local script_path=$(echo "$actual_cmd" | bash "${SCRIPT_DIR}/cron_create_script.sh" "$task_id")
        
        if [ -z "$script_path" ] || [ ! -f "$script_path" ]; then
            echo "  状态: ✗ 失败 (无法创建脚本)" >> "$LOG_FILE"
            return 1
        fi
        
        # 執行腳本
        local output=$(bash "$script_path" 2>&1)
        local exit_code=$?
        
        if [ $exit_code -eq 0 ]; then
            echo "  状态: ✓ 成功" >> "$LOG_FILE"
        else
            echo "  状态: ✗ 失败 (退出码: $exit_code)" >> "$LOG_FILE"
        fi
        if [ -n "$output" ]; then
            echo "  输出: $output" >> "$LOG_FILE"
        fi
    fi
    echo "---" >> "$LOG_FILE"
}

# 获取任务数据
get_task() {
    local task_id="$1"
    jq -r --arg tid "$task_id" '.tasks[] | select(.id == $tid)' "$JSON_FILE"
}

# 列出到期任务
list_due_tasks() {
    local current_time="$1"
    jq -r --argjson ct "$current_time" \
       '.tasks[] | select(.status == "active" or .status == "pending") | select(.next_run <= $ct) | .id' \
       "$JSON_FILE" 2>/dev/null
}
