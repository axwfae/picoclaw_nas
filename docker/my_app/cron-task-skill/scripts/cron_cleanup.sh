#!/bin/bash
# cron_cleanup.sh - 審查並清理孤立的執行腳本
# 用法: ./cron_cleanup.sh [--dry-run]
# 
# 功能：
#   1. 檢查 cron_task/run_sh/ 目錄中的所有 .sh 文件
#   2. 驗證每個腳本是否對應 cron_task.json 中的有效任務
#   3. 刪除不再存在於 JSON 中的孤立腳本
#   4. 生成審查報告

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
WORKSPACE_DIR="${SKILL_DIR}/../../cron_task"
RUN_SH_DIR="${WORKSPACE_DIR}/run_sh"
JSON_FILE="${WORKSPACE_DIR}/cron_task.json"
LOG_FILE="${WORKSPACE_DIR}/cleanup.log"

# 參數解析
DRY_RUN=false
if [ "$1" = "--dry-run" ]; then
    DRY_RUN=true
fi

# 確保目錄存在
if [ ! -d "$RUN_SH_DIR" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✓ run_sh 目錄不存在，無需清理"
    exit 0
fi

# 初始化計數器
total_scripts=0
valid_scripts=0
orphan_scripts=0
deleted_count=0

echo "========================================"
echo "  Cron Task 腳本審查報告"
echo "  時間: $(date '+%Y-%m-%d %H:%M:%S')"
echo "========================================"
echo ""

# ============ 獲取所有有效的任務ID ============
if [ -f "$JSON_FILE" ]; then
    valid_ids=$(jq -r '.tasks[].id' "$JSON_FILE" 2>/dev/null)
else
    valid_ids=""
fi

# ============ 檢查每個 .sh 腳本 ============
echo ">>> 正在審查 run_sh 目錄..."
echo ""

for script in "${RUN_SH_DIR}"/*.sh; do
    # 檢查是否匹配任何文件
    [ -e "$script" ] || continue
    
    total_scripts=$((total_scripts + 1))
    script_name=$(basename "$script")
    script_id="${script_name%.sh}"
    
    # 檢查腳本ID是否在有效任務列表中
    if echo "$valid_ids" | grep -qx "$script_id"; then
        valid_scripts=$((valid_scripts + 1))
        echo "  [✓] $script_name -> 任務存在"
    else
        orphan_scripts=$((orphan_scripts + 1))
        echo "  [✗] $script_name -> 孤立腳本（任務不存在）"
        
        if [ "$DRY_RUN" = true ]; then
            echo "       [DRY-RUN] 將刪除此腳本"
        else
            rm -f "$script"
            if [ $? -eq 0 ]; then
                deleted_count=$((deleted_count + 1))
                echo "       [已刪除]"
            else
                echo "       [刪除失敗]"
            fi
        fi
    fi
done

# ============ 統計結果 ============
echo ""
echo "========================================"
echo "  審查統計"
echo "========================================"
echo "  總腳本數:   $total_scripts"
echo "  有效腳本:   $valid_scripts"
echo "  孤立腳本:   $orphan_scripts"
if [ "$DRY_RUN" = true ]; then
    echo "  [DRY-RUN] 將刪除: $orphan_scripts 個腳本"
else
    echo "  已刪除:     $deleted_count 個腳本"
fi
echo "========================================"

# ============ 寫入日誌 ============
log_entry="[$(date '+%Y-%m-%d %H:%M:%S')] 審查完成: 總=$total_scripts, 有效=$valid_scripts, 孤立=$orphan_scripts, 刪除=$deleted_count"
echo "$log_entry" >> "$LOG_FILE"

# 保持日誌不超過 100 行
if [ -f "$LOG_FILE" ]; then
    tail -n 100 "$LOG_FILE" > "${LOG_FILE}.tmp" && mv "${LOG_FILE}.tmp" "$LOG_FILE"
fi

exit 0
