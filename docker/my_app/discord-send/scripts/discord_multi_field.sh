#!/bin/bash
# Discord 多字段 Embed 发送脚本
# 用法: ./discord_multi_field.sh <channel_id> "<title>" <color_hex>
#
# 字段格式 (每行): name|value|inline
# 示例:
#   ./discord_multi_field.sh 123456 "标题" "00D4AA" << 'EOF'
#   名称|测试|true
#   状态|在线|true
#   描述|这是描述|false
#   EOF

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.env"

source "$CONFIG_FILE"

CHANNEL_ID="$1"
TITLE="$2"
COLOR="${3:-00D4AA}"

# 读取 stdin，每行格式: name|value|inline
# 使用文件来避免复杂变量处理
FIELDS_FILE=$(mktemp)

cat > "$FIELDS_FILE"

if [ ! -s "$FIELDS_FILE" ]; then
    echo "❌ 没有提供字段数据"
    rm -f "$FIELDS_FILE"
    exit 1
fi

# 构建字段数组 - 直接用 jq 处理
FIELDS_ARRAY=$(cat "$FIELDS_FILE" | jq -R -s '
    split("\n") | 
    map(select(length > 0)) |
    map(split("|")) |
    map({
        "name": (.[0] // "") | gsub("[ \t]+$"; "") | gsub("^[ \t]+"; ""),
        "value": (.[1] // "") | gsub("[ \t]+$"; "") | gsub("^[ \t]+"; ""),
        "inline": ((.[2] // "true") | gsub("[ \t]+$"; "") | gsub("^[ \t]+"; "") | test("false"; "i")) | not
    })
')

rm -f "$FIELDS_FILE"

COLOR_INT=$((16#${COLOR}))

JSON_BODY=$(jq -n \
    --arg title "$TITLE" \
    --argjson color "$COLOR_INT" \
    --argjson fields "$FIELDS_ARRAY" \
    '{"embeds": [{"title": $title, "color": $color, "fields": $fields}]}')

RESPONSE=$(curl -s -X POST "https://discord.com/api/v10/channels/${CHANNEL_ID}/messages" \
    -H "Authorization: Bot ${DISCORD_BOT_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "$JSON_BODY")

if echo "$RESPONSE" | grep -q '"id"'; then
    echo "✅ 多字段 Embed 发送成功"
else
    echo "❌ 发送失败: $RESPONSE"
fi
