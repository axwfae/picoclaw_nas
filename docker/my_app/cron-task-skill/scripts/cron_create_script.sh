#!/bin/bash
# cron_create_script.sh - 創建可執行的臨時腳本（自動清理）
# 用法: ./cron_create_script.sh <任務ID> [腳本內容]
# 輸出: 腳本路徑（成功）或空（失敗）
# 特性: 
#   1. 腳本名稱必須為任務ID（不可隨意命名）
#   2. 自動在腳本末尾添加 self-cleanup 命令
#   3. 支持 STDIN 讀取腳本內容

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
WORKSPACE_DIR="${SKILL_DIR}/../../cron_task"
RUN_SH_DIR="${WORKSPACE_DIR}/run_sh"
JSON_FILE="${WORKSPACE_DIR}/cron_task.json"

# 確保目錄存在
mkdir -p "$RUN_SH_DIR"

# 參數檢查
if [ $# -lt 1 ]; then
    echo "用法: $0 <任務ID> [腳本內容]" >&2
    echo "或: cat script.sh | $0 <任務ID>" >&2
    exit 1
fi

TASK_ID="$1"

# ============ 驗證：任務ID必須存在於 JSON 中 ============
if [ -f "$JSON_FILE" ]; then
    if ! jq -e --arg tid "$TASK_ID" '.tasks[] | select(.id == $tid)' "$JSON_FILE" > /dev/null 2>&1; then
        echo "錯誤: 任務 ID '$TASK_ID' 不存在於 cron_task.json 中" >&2
        exit 1
    fi
else
    echo "警告: cron_task.json 不存在，無法驗證任務 ID" >&2
fi

# 腳本路徑（必須使用任務ID命名，不可隨意命名）
SCRIPT_NAME="${TASK_ID}.sh"
SCRIPT_PATH="${RUN_SH_DIR}/${SCRIPT_NAME}"

# ============ 讀取腳本內容 ============
if [ -t 0 ]; then
    # 終端模式：從命令行參數讀取內容
    if [ $# -lt 2 ]; then
        echo "用法: $0 <任務ID> <腳本內容>" >&2
        echo "或: cat script.sh | $0 <任務ID>" >&2
        exit 1
    fi
    CONTENT="$2"
else
    # 管道模式：從 STDIN 讀取
    CONTENT=$(cat)
fi

# ============ 創建腳本 ============
cat > "$SCRIPT_PATH" << 'HEADER_EOF'
#!/bin/bash
# 自動生成腳本 - 由任務執行後自動刪除
# ⚠️ 請勿手動修改此文件！
SCRIPT_SOURCE="${BASH_SOURCE[0]}"
HEADER_EOF

# 注入用戶內容（需要處理換行）
echo "" >> "$SCRIPT_PATH"
echo "# ========== 任務內容開始 ==========" >> "$SCRIPT_PATH"
echo "$CONTENT" >> "$SCRIPT_PATH"
echo "# ========== 任務內容結束 ==========" >> "$SCRIPT_PATH"

# 添加自動清理命令
cat >> "$SCRIPT_PATH" << 'CLEANUP_EOF'

# 自動清理：任務完成後刪除自身
rm -f "$SCRIPT_SOURCE"
CLEANUP_EOF

# ============ 設置執行權限 ============
chmod 755 "$SCRIPT_PATH"

# ============ 驗證 ============
if [ -x "$SCRIPT_PATH" ]; then
    echo "$SCRIPT_PATH"
    exit 0
else
    echo "錯誤: 無法設置腳本執行權限" >&2
    exit 1
fi
