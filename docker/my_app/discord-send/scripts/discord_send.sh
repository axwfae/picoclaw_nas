#!/bin/bash
# Discord 智能發送腳本
# 自動根據內容選擇最佳發送方式
#
# 用法:
#   discord_send.sh <channel_id> "<message>" [title] [options]
#   discord_send.sh <channel_id> <file_path> [title] [options]
#
# 選項:
#   --file     強制使用檔案上傳
#   --embed    強制使用單一 Embed
#   --multi    強制使用多欄位 Embed
#   --color    指定顏色 (預設根據內容類型自動選擇)
#
# 版本: v2.0.0

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.env"

# 載入配置
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    echo "❌ 找不到配置文件: $CONFIG_FILE"
    exit 1
fi

# 預設值
CHANNEL_ID=""
INPUT=""
TITLE=""
FORCE_MODE=""
COLOR=""

# 文字檔副檔名
TEXT_EXTENSIONS="txt log json md sh bash py js ts css html xml yaml yml csv ini conf cfg"

# 解析參數
parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --file)
                FORCE_MODE="file"
                shift
                ;;
            --embed)
                FORCE_MODE="embed"
                shift
                ;;
            --multi)
                FORCE_MODE="multi"
                shift
                ;;
            --color)
                COLOR="$2"
                shift 2
                ;;
            *)
                if [ -z "$CHANNEL_ID" ]; then
                    CHANNEL_ID="$1"
                elif [ -z "$INPUT" ]; then
                    INPUT="$1"
                elif [ -z "$TITLE" ]; then
                    TITLE="$1"
                else
                    echo "❌ 未知參數: $1"
                    exit 1
                fi
                shift
                ;;
        esac
    done
}

# 檢查是否為檔案路徑
is_file() {
    local path="$1"
    [ -f "$path" ] && echo "yes" || echo "no"
}

# 檢查是否為文字檔
is_text_file() {
    local path="$1"
    local ext="${path##*.}"
    ext=$(echo "$ext" | tr '[:upper:]' '[:lower:]')
    
    for e in $TEXT_EXTENSIONS; do
        [ "$ext" = "$e" ] && echo "yes" && return
    done
    
    # 嘗試用 file 命令檢測
    if command -v file &> /dev/null; then
        file --mime-type "$path" 2>/dev/null | grep -q "text/" && echo "yes" && return
    fi
    
    echo "no"
}

# 計算檔案行數
count_lines() {
    local path="$1"
    if [ -f "$path" ]; then
        wc -l < "$path" 2>/dev/null || echo "0"
    else
        echo "$path" | awk '{print NR}'
    fi
}

# 檢查是否為結構化資料 (key:value 格式)
is_structured_data() {
    local content="$1"
    local key_count=$(echo "$content" | grep -cE "^[^:]+:.*$" || true)
    local total_lines=$(echo "$content" | wc -l)
    
    # 如果有超過 30% 的行符合 key:value 格式，視為結構化資料
    [ "$total_lines" -gt 0 ] && [ "$key_count" -gt 0 ] && \
        [ $((key_count * 100 / total_lines)) -ge 30 ] && echo "yes" || echo "no"
}

# 分析內容並選擇發送方式
analyze_and_send() {
    local channel="$1"
    local content="$2"
    local title="$3"
    local mode="$4"
    local color="$5"
    
    local line_count=$(echo "$content" | wc -l)
    local has_structure=$(is_structured_data "$content")
    
    # 預設標題
    if [ -z "$title" ]; then
        if [ "$mode" = "file" ]; then
            title="📎 檔案內容"
        elif [ "$has_structure" = "yes" ]; then
            title="📊 資料統計"
        else
            title="📝 訊息"
        fi
    fi
    
    # 預設顏色
    if [ -z "$color" ]; then
        case "$mode" in
            "multi")  color="00D4AA" ;;
            "embed")  color="3498DB" ;;
            "file")   color="9B59B6" ;;
            *)        color="3498DB" ;;
        esac
    fi
    
    # 決定發送方式
    local final_mode="$mode"
    if [ -z "$final_mode" ]; then
        if [ "$has_structure" = "yes" ] && [ "$line_count" -le 25 ]; then
            final_mode="multi"
        elif [ "$line_count" -ge 100 ]; then
            final_mode="file"
        else
            final_mode="embed"
        fi
    fi
    
    echo "📤 分析內容: $line_count 行, 模式: $final_mode"
    
    case "$final_mode" in
        "multi")
            send_multi_field "$channel" "$title" "$color" "$content"
            ;;
        "embed")
            send_embed "$channel" "$title" "$content" "$color"
            ;;
        "file")
            # 將內容寫入臨時檔案並上傳
            local temp_file=$(mktemp)
            echo "$content" > "$temp_file"
            send_file "$channel" "$temp_file" "$title"
            rm -f "$temp_file"
            ;;
    esac
}

# 發送單一 Embed
send_embed() {
    local channel="$1"
    local title="$2"
    local description="$3"
    local color="$4"
    
    bash "$SCRIPT_DIR/discord_embed.sh" "$channel" "$title" "$description" "$color"
}

# 發送多欄位 Embed
send_multi_field() {
    local channel="$1"
    local title="$2"
    local color="$3"
    local content="$4"
    
    # 轉換內容為 key|value|inline 格式
    local fields=$(echo "$content" | while IFS='|' read -r k v i; do
        # 處理 key: value 格式
        if echo "$k" | grep -q ":"; then
            key=$(echo "$k" | cut -d':' -f1 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            val=$(echo "$k" | cut -d':' -f2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            if [ -n "$v" ]; then
                val="$val: $v"
            fi
            echo "$key|$val|true"
        else
            key=$(echo "$k" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            val=$(echo "$v" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            i="${i:-true}"
            [ -n "$key" ] && echo "$key|$val|$i"
        fi
    done)
    
    # 使用 discord_multi_field.sh 發送
    echo "$fields" | bash "$SCRIPT_DIR/discord_multi_field.sh" "$channel" "$title" "$color"
}

# 發送檔案
send_file() {
    local channel="$1"
    local file_path="$2"
    local message="$3"
    
    bash "$SCRIPT_DIR/discord_send_file.sh" "$channel" "$file_path" "$message"
}

# 主程式
main() {
    parse_args "$@"
    
    # 檢查必要參數
    if [ -z "$CHANNEL_ID" ] || [ -z "$INPUT" ]; then
        echo "❌ 用法: $0 <channel_id> <message|file_path> [title] [options]"
        echo ""
        echo "範例:"
        echo "  $0 123456789 \"短訊息\""
        echo "  $0 123456789 \"短訊息\" \"標題\""
        echo "  $0 123456789 /path/to/file.txt"
        echo "  $0 123456789 /path/to/file.txt \"日誌檔案\""
        echo ""
        echo "選項:"
        echo "  --file     強制使用檔案上傳"
        echo "  --embed    強制使用單一 Embed"
        echo "  --multi    強制使用多欄位 Embed"
        echo "  --color    指定顏色 (如: FFFFFF)"
        exit 1
    fi
    
    # 判斷輸入類型
    if [ "$(is_file "$INPUT")" = "yes" ]; then
        # 是檔案
        if [ "$(is_text_file "$INPUT")" = "yes" ]; then
            # 文字檔：分析內容
            local content=$(cat "$INPUT")
            local line_count=$(count_lines "$INPUT")
            
            echo "📄 檔案: $INPUT ($line_count 行)"
            analyze_and_send "$CHANNEL_ID" "$content" "$TITLE" "$FORCE_MODE" "$COLOR"
        else
            # 非文字檔：直接上傳
            echo "📎 檔案: $INPUT (二進制檔案，上傳中...)"
            send_file "$CHANNEL_ID" "$INPUT" "$TITLE"
        fi
    else
        # 是文字訊息
        local line_count=$(count_lines "$INPUT")
        
        echo "💬 訊息: $line_count 行"
        analyze_and_send "$CHANNEL_ID" "$INPUT" "$TITLE" "$FORCE_MODE" "$COLOR"
    fi
}

main "$@"
