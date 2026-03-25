---
name: cron-task-skill
version: "2.1.0"
description: 定时任务调度器 - 使用 JSON 存储任务，支持 Shell 命令和 AI 模式，由系统 cron 每分钟触发执行
metadata: {"nanobot":{"emoji":"⏰","requires":{"bins":["bash","cron","jq"]}}}
---

# ⚠️ 核心原則：操作後必須驗證

**嚴禁虛假回報！** 每次執行增加、刪除、修改 JSON 的操作後，**必須立即驗證**：

1. `cat cron_task.json | jq .` → 確保 JSON 格式正確
2. `cron_list.sh` → 確認任務狀態正確

如果驗證失敗，必須：
- 報告錯誤
- 回滾變更
- 不可假裝操作成功

---

# cron-task-skill - 定时任务调度器 (v2.1.0)

持久化 Cron 任务调度器。使用 JSON 文件存储任务，支持 Shell 命令和 **AI 模式（自然语言任务）**，由系统 cron **每分钟**触发执行。

## 特性

- ✅ **纯 Bash 实现** - 无 Python/JavaScript 依赖
- ✅ **AI 模式** - 用自然语言定义任务，交给 picoclaw agent 处理
- ✅ **轻量高效** - 资源占用极低，适合嵌入式设备
- ✅ **持久化存储** - JSON 格式，任务不丢失
- ✅ **自动清理** - 一次性任务完成后自动移除
- ✅ **并发保护** - 锁文件机制防止重复执行
- ✅ **Discord 集成** - 可定时发送 Discord 通知（需搭配 discord-send skill）

---

## 📢 Discord 通知集成

> ⚠️ **依赖**：需先安装 `discord-send` skill

本调度器支持通过 **discord-send skill (v2.0.0)** 发送 Discord 通知，适合：
- 定时报告/摘要
- 系统监控报警
- 定时状态推送

### 配置

> ⚠️ **注意**：直接使用 `discord-send` skill 的配置，无需重复创建！

确保 `discord-send` 已配置好：

```bash
# 檢查 discord-send 配置
cat /root/.picoclaw/workspace/skills/discord-send/scripts/config.env
# 確認有內容：
# DISCORD_BOT_TOKEN=your_token
# DISCORD_CHANNEL_GENERAL=123456789
# 可依需求添加更多頻道別名
```

> 📌 如需单独配置 cron 专用的频道，可在任务脚本中直接指定，或在 `cron_task/` 创建 `discord_custom.env` 存放任务特定的频道 ID。

### 智能發送腳本

使用 `discord_send.sh` 自動選擇最佳發送方式：

```bash
# 格式: discord_send.sh <channel_id> "<訊息|檔案路徑>" [標題] [options]

# 短文字 → 自動使用 Embed
./discord_send.sh "123456789" "✅ 系統正常運行中"

# 長訊息 (>=100行) → 自動使用檔案上傳
./discord_send.sh "123456789" "$(cat /var/log/syslog)" "📋 系統日誌"

# 結構化資料 (key:value) → 自動使用多欄位 Embed
./discord_send.sh "123456789" "CPU: 45%|記憶體: 8GB|磁碟: 50%" "📊 系統狀態"

# 發送檔案
./discord_send.sh "123456789" /path/to/file.txt "📎 日誌檔案"

# 強制模式
./discord_send.sh "123456789" "<訊息>" "" --embed   # 強制 Embed
./discord_send.sh "123456789" "<訊息>" "" --multi   # 強制多欄位
./discord_send.sh "123456789" "<訊息>" "" --file    # 強制檔案上傳
```

### 底層發送腳本

| 腳本 | 用途 | 適用場景 |
|-----|------|---------|
| `discord_send.sh` | 🏆 **智能發送** (v2.0.0) | 通用，推薦使用 |
| `discord_embed.sh` | 單一 Embed | 簡短訊息、狀態通知 |
| `discord_multi_field.sh` | 多欄位 Embed | 結構化數據、儀表板 |
| `discord_send_file.sh` | 檔案上傳 | 長日誌、程式碼、附件 |

### 顏色參考

| 顏色 | HEX | 用途 |
|-----|-----|------|
| 🟢 綠色 | `2ECC71` | 成功、正常 |
| 🔵 藍色 | `3498DB` | 資訊、一般 |
| 🟡 黃色 | `F1C40F` | 警告、注意 |
| 🟠 橙色 | `E67E22` | 警示、即將出錯 |
| 🔴 紅色 | `E74C3C` | 錯誤、嚴重問題 |

### 使用範例

#### Shell 模式 + Discord 通知

```bash
# 添加任務：每小時發送系統狀態到 Discord
./cron_add.sh "系統狀態報告" 'bash /root/.picoclaw/workspace/cron_task/send_status.sh' 3600 interval shell

# 其中 send_status.sh 內容：
#!/bin/bash
source /root/.picoclaw/workspace/skills/discord-send/scripts/config.env
bash /root/.picoclaw/workspace/skills/discord-send/scripts/discord_send.sh \
  "$DISCORD_CHANNEL_GENERAL" \
  "CPU: \$(top -bn1 | grep "Cpu(s)" | awk "{print \$2}")%|記憶體: \$(free -h | awk "/Mem:/ {print \$3}")" \
  "📊 系統狀態" --multi
```

> 💡 可在 `config.env` 中定義 `DISCORD_CHANNEL_STATUS=123456789` 作為常用頻道。

#### AI 模式 + Discord 通知

```bash
# 添加任務：AI 分析後發送到 Discord
./cron_add.sh "每日 AI 摘要" "分析系統日誌並發送摘要到 Discord 頻道" 86400 interval ai
```

#### 報警監控範例

```bash
# 添加任務：檢查服務狀態，異常時發送 Discord 報警
./cron_add.sh "服務監控" 'if ! systemctl is-active nginx; then bash /root/.picoclaw/workspace/skills/discord-send/scripts/discord_send.sh "123456789" "🔴 Nginx 服務已停止！" "錯誤" --color E74C3C; fi' 300 interval shell
```

---

## 目錄結構

```
workspace/skills/cron-task-skill/       ← Skill 目錄（只放腳本）
├── SKILL.md                            # 本文档
└── scripts/
    ├── cron_lib.sh                     # 公共函数库
    ├── cron_add.sh                     # 添加任务
    ├── cron_del.sh                     # 删除任务
    ├── cron_edit.sh                    # 修改任务
    ├── cron_list.sh                    # 列出任务
    ├── cron_run.sh                     # 执行任务（由 cron 调用）
    ├── cron_log.sh                     # 查看日志
    ├── cron_create_script.sh           # 创建可执行脚本（使用任务ID命名）
    └── cron_cleanup.sh                 # 审查清理孤立脚本（新）

workspace/cron_task/                    ← 数据目录（任务存储）
├── cron_task.json                      # 任务数据（JSON）
├── execution.log                       # 执行日志
├── cleanup.log                         # 清理日志
├── cleanup.counter                     # 审查计数器（自动管理）
├── run.lock                            # 运行锁（防止并发）
└── run_sh/                             # 自动生成脚本目录
    └── <任务ID>.sh                     # 脚本名必须与任务ID一致
```

> 📌 **重要**：数据与脚本分离，升级 skill 不会丢失任务数据！

---

## 自動生成腳本管理規範

> ⚠️ **重要**：為確保系統整潔和安全，所有自動生成的執行腳本必須遵循以下規範！

### 📁 目錄位置

當 cron-task-skill 需要執行特定功能而自動生成 `.sh` 腳本時，**必須**將其放置在 `cron_task/run_sh/` 目錄下：

```
workspace/cron_task/run_sh/            ← 自動生成腳本目錄
├── 1714426080-1234.sh                 # 腳本名 = 任務ID
└── 1714427000-5678.sh                 # 每個任務對應一個腳本
```

### 📝 腳本命名規範（強制）

> ⚠️ **核心規則**：腳本名稱必須與 `cron_task.json` 中的任務 ID 完全一致！

```bash
# ✅ 正確：使用任務ID命名
1743011234-5678.sh

# ❌ 錯誤：禁止隨意命名
my_task.sh
send_notification.sh
custom_script.sh
```

**驗證方式**：
```bash
# 檢查腳本是否對應有效任務
ls cron_task/run_sh/*.sh | xargs -I{} basename {} .sh | \
  while read id; do
    if ! jq -e ".tasks[] | select(.id == \"$id\")" cron_task.json > /dev/null 2>&1; then
      echo "孤立腳本: $id.sh"
    fi
  done
```

### 🔧 權限要求

所有放置在 `run_sh/` 目錄下的腳本，**必須**設置正確的權限：

```bash
chmod 755 /root/.picoclaw/workspace/cron_task/run_sh/<任務ID>.sh
```

### 🧹 任務完成後清理

> ⚠️ **強制要求**：任務執行完成後，**必須**刪除對應的 `.sh` 腳本！

清理時機：
- ✅ **一次性任務（once）**：執行完畢後立即刪除
- ✅ **定時任務（interval）**：可選保留（建議清理避免積累）

清理命令示例：
```bash
rm -f /root/.picoclaw/workspace/cron_task/run_sh/<任務ID>.sh
```

### ⚡ 完整工作流程

> ⚠️ **重要**：創建腳本後**必須**設置執行權限，否則任務會失敗！

```bash
# 1. 創建腳本（放在 run_sh 目錄）- 方式 A：使用輔助腳本（推薦）
echo "echo '執行特定功能...'" | ./cron_create_script.sh "1714426080-1234"
# ✓ 自動驗證任務ID存在、自動設置權限、返回腳本路徑

# 1. 創建腳本（放在 run_sh 目錄）- 方式 B：命令列參數
./cron_create_script.sh "1714426080-1234" "echo '執行特定功能...'"
# ✓ 自動驗證任務ID存在

# 2. 執行任務（腳本執行後會自動刪除自身）
bash /root/.picoclaw/workspace/cron_task/run_sh/1714426080-1234.sh

# 3. 任務完成後清理（如腳本未自動清理）
rm -f /root/.picoclaw/workspace/cron_task/run_sh/1714426080-1234.sh
```

> 📌 **常見錯誤**：`Permission denied` → 忘記執行 `chmod 755`

### ✅ 驗證清單

創建自動生成腳本時，請確認：

- [ ] 腳本名稱與 cron_task.json 中的任務 ID 完全一致
- [ ] 腳本路徑在 `cron_task/run_sh/` 目錄下
- [ ] 文件權限為 `755`（`chmod 755`）- **⚠️ 極易遺漏**
- [ ] 腳本執行完畢後已刪除
- [ ] JSON 任務數據中的 `command` 指向正確的腳本路徑

> 📌 **違規後果**：未遵循規範的腳本可能導致：
> - 安全風險（權限過大）
> - 磁盤空間浪費（腳本堆積）
> - 任務執行失敗（路徑錯誤或 Permission denied）

### 🧹 定期審查腳本

#### 🤖 自動審查機制（推薦）

> ⚠️ **重要**：系統會自動執行審查，無需手動干預！

**工作原理**：
- `cron_run.sh` 每次執行到期任務時遞增計數器
- 每 60 次任務執行（約每小時）自動調用 `cron_cleanup.sh` 審查腳本
- 審查結果追加到 `execution.log`

**審查流程**：
```
cron_run.sh 執行流程：
  1. 執行所有到期任務
  2. 計數器 +1
  3. 如果計數器 ≥ 60
     → 調用 cron_cleanup.sh 審查孤立腳本
     → 重置計數器為 0
```

**計數器文件**：`cron_task/cleanup.counter`

#### 🔧 手動審查

```bash
# 預覽模式（僅顯示孤立腳本，不刪除）
./cron_cleanup.sh --dry-run

# 正式執行清理
./cron_cleanup.sh

# 強制觸發立即審查（重置計數器為 60）
echo "60" > /root/.picoclaw/workspace/cron_task/cleanup.counter
# 下次 cron_run.sh 執行時將立即觸發審查
```

#### 📋 審查內容

| 檢查項 | 說明 |
|--------|------|
| 孤立腳本 | `run_sh/` 中無對應任務ID的腳本 |
| 腳本命名 | 驗證腳本名是否與 `cron_task.json` 中的任務ID一致 |
| 清理操作 | 刪除孤立腳本，保持目錄整潔 |

#### 📝 審查日誌示例

```
========================================
  Cron Task 腳本審查報告
  時間: 2026-03-25 22:06:00
========================================
  掃描目錄: /root/.picoclaw/workspace/cron_task/run_sh/

  發現孤立腳本: 1
    - 1714426080-1234.sh  (無對應任務，已刪除)

  審查完成 ✓
```

---

## 使用方法

### 添加任務

> ⚠️ **重要**：添加任務後必須驗證 JSON 文件完整性！

```bash
# Shell 模式 - 執行系統命令
./cron_add.sh "清理日誌" "find /tmp -name '*.log' -delete" 3600 interval shell

# AI 模式 - 自然語言任務（交給 picoclaw agent 處理）
./cron_add.sh "健康提醒" "提醒我站起來活動一下" 1800 interval ai
./cron_add.sh "每日天氣" "用中文播報今天的天氣" 43200 interval ai

# 添加後必須驗證
./cron_list.sh  # 確認任務已添加
cat /root/.picoclaw/workspace/cron_task/cron_task.json | jq .  # 驗證 JSON 格式
```

> ✅ **驗證標準**：執行 `jq .` 後無報錯，且 `cron_list.sh` 能正確顯示任務。

# 參數說明
#   $1: 名稱 - 任務描述
#   $2: 命令 - Shell 命令 或 AI 提示詞
#   $3: 間隔 - 秒數（60=1分鐘, 3600=1小時, 86400=1天）
#   $4: 類型 - once(一次性) 或 interval(間隔)
#   $5: 模式 - shell(命令) 或 ai(自然語言)
```

### 列出任務

```bash
./cron_list.sh
```

### 刪除任務

> ⚠️ **重要**：刪除任務後必須驗證 JSON 文件完整性！

```bash
./cron_del.sh <id>

# 刪除後必須驗證
./cron_list.sh  # 確認任務已刪除
cat /root/.picoclaw/workspace/cron_task/cron_task.json | jq .  # 驗證 JSON 格式
```

> ✅ **驗證標準**：執行 `jq .` 後無報錯，且 `cron_list.sh` 顯示任務列表正確（目標任務已不存在）。

### 修改任務

> ⚠️ **重要**：修改任務後必須驗證 JSON 文件完整性！

```bash
./cron_edit.sh <id> status paused     # 暫停
./cron_edit.sh <id> interval 7200     # 修改間隔

# 修改後必須驗證
./cron_list.sh  # 確認修改已生效
cat /root/.picoclaw/workspace/cron_task/cron_task.json | jq .  # 驗證 JSON 格式
```

> ✅ **驗證標準**：執行 `jq .` 後無報錯，且 `cron_list.sh` 顯示任務狀態/參數已正確更新。

### 查看日誌

```bash
./cron_log.sh           # 最近 50 條
./cron_log.sh 100       # 最近 100 條
```

---

## 系統集成

### 設置系統 Cron（每分鐘檢查）

```bash
(crontab -l 2>/dev/null | grep -v "cron-task-skill/scripts/cron_run.sh"; \
  echo "* * * * * cd /root/.picoclaw/workspace/skills/cron-task-skill/scripts && ./cron_run.sh >> /tmp/cron_task.log 2>&1") | crontab -

# 驗證
crontab -l
```

### 手動觸發

```bash
./cron_run.sh
```

---

## AI 模式

使用 AI 模式時，任務命令會作為自然語言提示詞傳遞給 `picoclaw agent -m` 處理：

| 命令示例           |        說明 |
|-------------------|------------|
| `提醒我喝水`        | 設置喝水提醒 |
| `每小時播報天氣`    | 天氣播報任務  |
| `整理今天的筆記摘要` | 定時整理     |
| `檢查系統狀態並報告` | 系統監控     |

**AI 模式優勢**：
- 不需要寫複雜的 Shell 命令
- 支援多步驟複雜任務
- 可訪問 picoclaw 所有能力

**添加示例**：
```bash
./cron_add.sh "健康提醒" "提醒我站起來活動一下" 1800 interval ai
./cron_add.sh "每日天氣" "用中文播報今天的天氣" 43200 interval ai
```

---

## 任務狀態

| 狀態       | 說明            |
|-----------|-----------------|
| pending   | 待執行           |
| active    | 運行中           |
| paused    | 已暫停           |
| completed | 已完成（自動清理） |

---

## 數據格式

```json
{
  "tasks": [
    {
      "id": "1711316400-1234",
      "type": "interval",
      "name": "AI問候助手",
      "command": "ai:用中文說hello",
      "interval": 60,
      "status": "active",
      "created": 1711316400,
      "next_run": 1711316460,
      "last_run": null,
      "run_count": 0,
      "mode": "ai"
    }
  ]
}
```

---

## 與 picoclaw 集成

可通過自然語言讓 picoclaw 操作任務：

```
"添加一個每小時提醒我喝水的任務，使用 AI 模式"
"列出所有定時任務"
"刪除喝水提醒任務"
```

picoclaw 會調用相應的腳本完成任務操作。

---

## 版本歷史

### v2.1.0 (2026-03-26)
- ✨ 新增 Discord 通知集成說明
- 📢 詳細介紹 discord-send skill (v2.0.0) 的使用方式
- 🔗 添加 Shell 模式和 AI 模式 + Discord 通知的範例
- 📊 補充顏色參考表

### v2.0.0 (2026-03-25)
- ✨ 新增自動審查腳本功能 (cron_cleanup.sh)
- 🧹 實現孤立腳本自動清理機制
- 📝 更新文檔結構和驗證清單

### v1.0.0 (2026-03-24)
- 初始版本
- 基本定時任務功能

---

## 故障排除

```bash
# 檢查任務
./cron_list.sh

# 查看日誌
./cron_log.sh

# 手動執行
./cron_run.sh

# 檢查 cron
crontab -l
systemctl status cron
```
