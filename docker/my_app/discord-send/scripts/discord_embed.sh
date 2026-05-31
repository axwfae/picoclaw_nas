#!/bin/bash
# Discord Rich Embed 訊息發送腳本
# 用法: ./discord_embed.sh <channel_id> "<title>" "<description>" "<color_hex>"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.env"

source "$CONFIG_FILE"

if [ $# -lt 3 ]; then
    echo "用法: $0 <channel_id> <title> <description> [color_hex]"
    echo "範例: $0 123456789 '錯誤報告' '伺服器離線' 'FF0000'"
    exit 1
fi

CHANNEL_ID="$1"
TITLE="$2"
DESCRIPTION="$3"
COLOR="${4:-00AAFF}"

COLOR_INT=$((16#${COLOR}))

JSON_BODY=$(jq -n \
    --arg title "$TITLE" \
    --arg desc "$DESCRIPTION" \
    --argjson color "$COLOR_INT" \
    '{"embeds": [{"title": $title, "description": $desc, "color": $color}]}')

RESPONSE=$(curl -s -X POST "https://discord.com/api/v10/channels/${CHANNEL_ID}/messages" \
    -H "Authorization: Bot ${DISCORD_BOT_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "$JSON_BODY")

if echo "$RESPONSE" | grep -q '"id"'; then
    echo "✅ Embed 訊息發送成功"
    exit 0
else
    echo "❌ 發送失敗: $RESPONSE"
    exit 1
fi
