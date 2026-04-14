#!/bin/bash
# Discord 文件上传脚本
# 用法: ./discord_send_file.sh <channel_id> <file_path> [message]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.env"

source "$CONFIG_FILE"

if [ $# -lt 2 ]; then
    echo "用法: $0 <channel_id> <file_path> [message]"
    echo "範例: $0 123456789 /tmp/test.txt"
    exit 1
fi

CHANNEL_ID="$1"
FILE_PATH="$2"
MESSAGE="${3:-📎 文件上传}"

if [ ! -f "$FILE_PATH" ]; then
    echo "錯誤: 找不到文件 $FILE_PATH"
    exit 1
fi

RESPONSE=$(curl -s -X POST "https://discord.com/api/v10/channels/${CHANNEL_ID}/messages" \
    -H "Authorization: Bot ${DISCORD_BOT_TOKEN}" \
    -F "file=@${FILE_PATH}" \
    -F "content=${MESSAGE}")

if echo "$RESPONSE" | grep -q '"id"'; then
    echo "✅ 文件上传成功"
else
    echo "❌ 上传失败: $RESPONSE"
fi
