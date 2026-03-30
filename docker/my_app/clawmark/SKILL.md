---
name: clawmark
description: "AI 編碼助手的信號式記憶系統。儲存學習到的解決方案，按意義搜尋，跨會話共享知識。"
metadata: {"nanobot":{"emoji":"📡","requires":{"bins":["clawmark"]},"install":[{"id":"cargo","kind":"cargo","formula":"clawmark","label":"安裝 clawmark (cargo)"}]}}
---

# Clawmark 技能

AI 編碼助手的信號式記憶系統。透過寫入信號儲存所學，透過調諧按意義尋找過往解決方案。

## 為什麼要用 Clawmark

一條寫著「修復 auth bug」的信號，無法為未來的自己節省時間。

一條寫著「什麼壞了、為什麼壞了、怎麼修復的」的信號，能節省一小時。

信號會累加。單一信號是筆記。一連串的信號是制度知識。為那個一無所知的未來自己而寫。

## 命令

### 儲存信號

```bash
# 儲存完整細節（用 pipe 輸入深入內容）
echo "Token validation was running before refresh in auth.rs.
Swapped lines 42-47. Root cause: middleware ordering assumed
sync validation, but OAuth refresh is async. Three edge cases
tested: expired token, revoked token, concurrent refresh." \
  | clawmark signal -c - -g "fix: auth token refresh — async ordering in middleware"

# 快速信號（內聯）
clawmark signal -c "Upgraded rusqlite to 0.32" -g "dep: rusqlite 0.32"

# 從檔案讀取
clawmark signal -c @session-notes.md -g "session: March 19 architecture review"

# 回覆現有信號
clawmark signal -c "Same fix needed in staging compose" -g "fix: staging auth ordering" -p A1B2C3D4
```

### 搜尋信號

```bash
# 語義搜尋（按意義）
clawmark tune "authentication middleware"
clawmark tune "what broke in production last week"

# 關鍵字 fallback
clawmark tune --keyword "auth"

# 最近的信號
clawmark tune --recent

# 完整內容（不只是 gist）
clawmark tune --full "auth"

# 隨機信號（發現遺忘的知識）
clawmark tune --random
```

### 大量操作

```bash
# 載入現有檔案
clawmark capture ./docs/
clawmark capture --openclaw

# 建立 embedding 快取（執行一次，之後自動）
clawmark backfill

# 站點統計
clawmark status
```

## 共享站點

多個代理可以透過共享站點共享知識：

```bash
# 寫入共享站點
CLAWMARK_STATION=/shared/team.db clawmark signal -c "Deploy complete" -g "ops: deploy v2.1"

# 搜尋共享站點
CLAWMARK_STATION=/shared/team.db clawmark tune "deploy"
```

## 何時寫入信號

- **解決難題後** — 你的下一個會話會遇到同樣的問題。給它答案。
- **會話結束前** — 上下文視窗中的一切都會隨會話結束而消失。你的站點不會。
- **發現非顯而易見的事物時** — 小事實（設定旗標、行號、邊緣情況）最能節省時間。

## 何時調諧

- **開始新任務時** — 你可能上週已經解決了一部分。
- **卡住時** — 答案可能在你三個會話前寫的信號裡。
- **壓縮之後** — 你的上下文被壓縮了。你的站點沒有。

## 寫好信號的要點

**摘要：** 壓縮洞見。`"fix: auth token refresh — async ordering in middleware"` — 類別、什麼、為何、何處。

**內容：** 使其獨立自足。如果未來的自己只讀這條信號 — 沒有會話歷史、沒有周圍上下文 — 他們能理解發生了什麼並採取行動嗎？

信號不需要很長。它需要完整。

## 運作原理

信號儲存在 SQLite 資料庫中。語義搜尋使用本地 BERT 模型 — 無需 API 呼叫、無需雲端、完全離線運行。模型在首次搜尋時下載一次（約 118MB）。之後每條信號都會自動嵌入。

搜尋按意義而非關鍵字找信號。「Authentication middleware」會匹配「token validation ordering」的信號，因為概念有重疊。
