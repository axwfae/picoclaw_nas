


# ⚠️ AGENT.md 修改即時生效規範（最高優先級・強制執行）

## 核心規則

**當前對話中任何修改 `AGENT.md`（包含 SOUL.md、USER.md）的操作，必須立即生效，無需重啟對話、無需重新開啟對話、無需等待。**

### 具體要求

1. **每次接收訊息時**，主動檢查 `AGENT.md` 是否已更新
2. **若檢測到變動**，立即重新讀取並套用新規範
3. **不依賴對話歷史**，以磁碟上的最新檔案內容為準
4. **不等待新對話**，當前對話立即反映變更

### 違反處理

若懷疑當前對話未反映最新規範，**立即主動重新讀取** `AGENT.md`。

---

# 預設目錄

**預設目錄為 `workspace`**。所有提及的檔案及目錄路徑，皆以 `workspace` 為起源，除非特別指定完整路徑或外部路徑。

- `user.md` → `/root/.picoclaw/workspace/user.md`
- `skills/` → `/root/.picoclaw/workspace/skills/`
- `memory/` → `/root/.picoclaw/workspace/memory/`
- 若特別指定如 `/root/.picoclaw/...` 或 `~/...`，則使用該完整路徑。

---

# 檔案管理規範（強制）

## 1. 暫時性資料 → `tmp/` 目錄

所有產生的暫時性資料（如待處理的 txt 文件、臨時計算結果、過渡性檔案等），**必須**先放置在 `tmp` 目錄中。

```bash
# 使用前先確保目錄存在
[ ! -d "tmp" ] && mkdir -p "tmp"
```

- 若無特殊需求，處理完畢後應考慮刪除
- 不要將 tmp 目錄的檔案視為永久保存

## 2. 下載資料 → `download/` 目錄

所有要求下載的資料（網頁、音樂、文件等），**必須**放置在 `download` 目錄中。

> ⚠️ **下載時務必遵守下方「頻道/軟件來源分類」規範**！

```bash
# 使用前先確保目錄存在
[ ! -d "download" ] && mkdir -p "download"
```

### 3. 頻道/軟件來源分類 → `download/{頻道名}/`

| 頻道/軟件 | 目錄 |
|-----------|------|
| Discord | `download/discord/` |
| WeChat/微信 | `download/weixin/` |
| Telegram | `download/telegram/` |
| Email | `download/email/` |
| 其他 | `download/others/` |

**例外：** 若該頻道或軟件本身有指定的儲存位置要求，則遵照其要求執行。

---

# Skill 使用規範（強制）

使用任何 skill 前，**必須先閱讀其 SKILL.md**，並嚴格遵守其中所有要求。

## 核心原則

1. **先讀取 SKILL.md**
   - 使用任何 skill 前，必須先 `read_file` 讀取該 skill 的 `SKILL.md`
   - 理解其設計理念、架構、限制、命名規範

2. **嚴格遵守命名規範**
   - 每個 skill 都有其獨特的命名/ID 規則，**必須遵守**
   - 例：cron-task-skill 要求腳本名 = 任務 ID + ".sh"

3. **完整流程**
   - 建立腳本 → 設定執行權限 (`chmod +x`) → 新增任務到 JSON

4. **驗證操作**
   - 修改 JSON 後必須用 `jq .` 驗證格式

---


