---
name: discord-send
version: "2.0.1"
description: 發送訊息到 Discord 頻道。使用 curl 呼叫 Discord Webhook API。觸發時機：(1) 用戶要求發送 Discord 訊息，(2) 定時任務需要推播通知到 Discord，(3) 監控/報警需要發送到 Discord。需先配置 bot_token 和 channel_ids。
---

# Discord 訊息發送 (v2.0.0)

使用 Discord Bot Token 發送訊息到指定頻道。支援智能判斷訊息內容自動選擇最佳發送方式。

## 配置

配置文件位於 `scripts/config.env`，格式：
```
DISCORD_BOT_TOKEN=your_bot_token_here
DISCORD_CHANNEL_GENERAL=channel_id_for_general
DISCORD_CHANNEL_ALERTS=channel_id_for_alerts
# 可自行添加更多頻道別名...
```

> 💡 變數名可自訂，建議使用 `DISCORD_CHANNEL_<名稱>` 格式，方便識別。

**取得 Bot Token**：在 [Discord Developer Portal](https://discord.com/developers/applications) 建立應用程式 -> Bot -> Reset Token

**取得 Channel ID**：在 Discord 開啟開發者模式，右鍵頻道 -> Copy Channel ID

---

## 智能發送腳本

### `discord_send.sh` - 自動判斷最佳發送方式

**推薦使用！** 會自動根據內容選擇最適合的發送方式：

| 內容類型 | 發送方式 |
|---------|---------|
| 短文字 (< 100行，純文字) | 內嵌訊息 (embed) |
| 長文字 (>= 100行) | 檔案上傳 |
| 非文字檔案 | 檔案上傳 |
| 結構化資料 (key-value) | 多欄位 Embed |

```bash
# 基本用法
bash scripts/discord_send.sh <channel_id> "<message>"

# 發送檔案
bash scripts/discord_send.sh <channel_id> /path/to/file.txt

# 指定標題
bash scripts/discord_send.sh <channel_id> "<message>" "自訂標題"

# 強制使用檔案上傳
bash scripts/discord_send.sh <channel_id> "<message>" "" --file

# 強制使用單一 Embed
bash scripts/discord_send.sh <channel_id> "<message>" "" --embed
```

### 智能判斷邏輯

```
開始
  │
  ├─ 是檔案路徑？
  │    ├─ 是 → 檢查副檔名
  │    │    ├─ 文字檔 (.txt, .log, .json, .md, .sh...) → 分析內容行數
  │    │    └─ 非文字檔 → 直接上傳檔案
  │    └─ 否 → 視為純文字訊息
  │
  ├─ 文字訊息分析
  │    ├─ 行數 >= 100 → 檔案上傳
  │    ├─ 包含 key:value 或 表格格式 → 多欄位 Embed
  │    └─ 其他短文字 → 單一 Embed
  │
  └─ 選擇發送方式
```

---

## 底層腳本

### `discord_embed.sh` - 單一 Embed

適用於：簡短訊息、狀態更新、單一描述

```bash
bash scripts/discord_embed.sh <channel_id> "<title>" "<description>" [color_hex]
```

**範例：**
```bash
bash scripts/discord_embed.sh 123456 "⚠️ 警告" "伺服器 CPU 使用率達 95%" "FF6B6B"
```

### `discord_multi_field.sh` - 多欄位 Embed

適用於：結構化資料、統計數據、儀表板資訊

```bash
bash scripts/discord_multi_field.sh <channel_id> "<title>" [color_hex] << 'EOF'
欄位名|欄位值|inline
名稱|資料|true
狀態|正常|true
說明|這是描述|false
EOF
```

**範例：**
```bash
bash scripts/discord_multi_field.sh 123456 "📊 系統狀態" "2ECC71" << 'EOF'
CPU|45%|true
記憶體|2.3GB/8GB|true
磁碟|156GB/500GB|true
運行時間|15天 3小時|false
最後備份|2026-03-25 18:00|true
EOF
```

### `discord_send_file.sh` - 檔案上傳

適用於：長日誌、原始資料、程式碼、非文字檔案

```bash
bash scripts/discord_send_file.sh <channel_id> <file_path> [message]
```

**範例：**
```bash
bash scripts/discord_send_file.sh 123456 /var/log/syslog "📋 系統日誌"
```

---

## 腳本列表

| 腳本 | 用途 | 適用場景 |
|-----|------|---------|
| `discord_send.sh` | 🏆 **智能發送** | 通用，推薦使用 |
| `discord_embed.sh` | 單一 Embed | 簡短訊息、狀態通知 |
| `discord_multi_field.sh` | 多欄位 Embed | 結構化數據、儀表板 |
| `discord_send_file.sh` | 檔案上傳 | 長日誌、程式碼、附件 |

---

## 顏色參考

| 顏色 | HEX | 用途 |
|-----|-----|------|
| 🟢 綠色 | `2ECC71` | 成功、正常 |
| 🔵 藍色 | `3498DB` | 資訊、一般 |
| 🟡 黃色 | `F1C40F` | 警告、注意 |
| 🟠 橙色 | `E67E22` | 警示、即將出錯 |
| 🔴 紅色 | `E74C3C` | 錯誤、嚴重問題 |
| 🟣 紫色 | `9B59B6` | 特殊、系統訊息 |
| ⚫ 深灰 | `34495E` | 預設、次要訊息 |

---

## 錯誤處理

如果發送失敗，檢查：
1. Bot Token 是否正確且有效
2. Bot 是否已加入伺服器且有該頻道的發訊權限
3. Channel ID 是否正確

### 常見錯誤

| 錯誤訊息 | 原因 | 解決方式 |
|---------|------|---------|
| `invalid JSON` | 訊息內容包含特殊字元未正確轉義 | 使用 `jq -n --arg msg "$MESSAGE"` 處理 |
| `Missing Access` | Bot 未加入伺服器或無權限 | 確認 Bot 已邀请到頻道所在伺服器 |
| `{"message": "", "code": 50006}` | 訊息內容為空 | 確保訊息不為空 |

---

## 版本歷史

### v2.0.1 (2026-03-26)
- 📝 修正 config.env 格式說明，使用統一的變數命名規範
- 💡 說明變數名可自訂 (DISCORD_CHANNEL_<NAME>)

### v2.0.0 (2026-03-26)
- ✨ 新增 `discord_send.sh` 智能發送腳本
- 🧠 自動判斷訊息內容選擇最佳發送方式
- 📊 支援結構化資料偵測，自動使用多欄位 Embed
- 📁 長文字 (>100行) 自動改用檔案上傳

### v1.0.0 (2026-03-25)
- 初始版本
- 基本 Embed 發送功能
- 檔案上傳功能
