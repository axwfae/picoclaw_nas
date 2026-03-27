---
name: cron-task-skill
version: "3.2.0"
description: 定时任务调度器 - 只有 2 个执行脚本，任务 CRUD 由 AI 直接操作 JSON
metadata: {"nanobot":{"emoji":"⏰","requires":{"bins":["bash","cron","jq"]}}}
---

# cron-task-skill - 定时任务调度器 (v3.2.0)

极简设计：只有 2 个系统脚本，任务 CRUD 由 AI 直接操作 JSON。

---

## 系统架构

```
┌─────────────────────────────────────────────────────────────┐
│  系统 cron (每分钟)                                          │
│       ↓                                                     │
│  cron_run.sh ←读取→ cron_task.json                         │
│       ↓                                                     │
│  执行到期任务 → 更新 next_run / 删除 once 任务              │
│       ↓                                                     │
│  每30分钟调用 cron_cleanup.sh 清理孤立脚本                  │
└─────────────────────────────────────────────────────────────┘
```

---

## 核心文件

### 系统脚本（只有 2 个）

| 文件 | 职责 |
|------|------|
| `cron_run.sh` | ⭐ 由系统 cron 每分钟调用，执行到期任务 |
| `cron_cleanup.sh` | 清理 run_sh/ 中孤立的 .sh 脚本 |

---

## 脚本命名规范（重要！）

> ⚠️ **Shell 模式必须遵守的命名规则**：脚本文件名必须与任务 ID 一致，以便 `cron_cleanup.sh` 能够正确识别并清理孤立脚本。
> ⚠️ **所有任务必须使用此格式**：任务 ID 格式为 `时间戳-任务简介`，例如 `1774624286-workspace_backup_0400.sh`

### 格式规则

```
任务ID = 时间戳 + "-" + 任务简介（不含.sh）
脚本名 = 任务ID + ".sh"

示例：
  时间戳: 1774624286（当前时间戳）
  任务简介: workspace_backup_0400
  任务ID: 1774624286-workspace_backup_0400
  脚本名: 1774624286-workspace_backup_0400.sh
```

### 正确示例

```json
{
  "id": "1774624286-workspace_backup_0400",
  "command": "bash /root/.picoclaw/workspace/cron_task/run_sh/1774624286-workspace_backup_0400.sh"
}
```

```
run_sh/
└── 1774624286-workspace_backup_0400.sh  ← 任务ID + ".sh"
```

### 错误示例（不符合规范）

```json
{
  "id": "workspace_backup_0400",  ❌ 缺少时间戳前缀
  "command": "bash /root/.picoclaw/workspace/cron_task/run_sh/workspace_backup_0400.sh"
}
```

```json
{
  "id": "1774624286-workspace_backup_0400.sh",  ❌ 包含了 .sh 后缀
  "command": "bash /root/.picoclaw/workspace/cron_task/run_sh/1774624286-workspace_backup_0400.sh"
}
```

### cron_cleanup.sh 工作原理

1. 从 `cron_task.json` 读取所有任务 ID
2. 检查 `run_sh/` 目录下每个 `.sh` 文件
3. 如果脚本名（去掉 .sh 后缀）不在任务 ID 列表中 → 删除


### 数据文件

```
/root/.picoclaw/workspace/cron_task/
├── cron_task.json    # 任务数据（AI 直接操作）
├── execution.log    # 执行日志
├── run.lock         # 运行锁（防止并发）
└── run_sh/          # 临时脚本目录（自动清理）
```

---

## 任务管理（AI 直接操作 JSON）

> ⚠️ **核心原则**：任务的新增、修改、删除、列表 全部由 AI 直接操作 `cron_task.json`

### 任务 JSON 格式

```json
{
  "tasks": [
    {
      "id": "时间戳-任务简介",
      "type": "interval",
      "name": "任务名称",
      "command": "ai:自然语言命令",
      "interval": 3600,
      "status": "active",
      "created": 1774624286,
      "next_run": 1773282000,
      "last_run": null,
      "run_count": 0,
      "mode": "ai"
    }
  ]
}
```

### 字段说明

| 字段 | 说明 | 示例 |
|------|------|------|
| `id` | 唯一标识，格式：`时间戳-任务简介` | `1774624286-workspace_backup_0400` |
| `type` | 类型 | `interval`(间隔) / `once`(一次性) / `cron`(Cron表达式) |
| `name` | 任务名称 | `喝水提醒` |
| `command` | 命令 | `ai:提醒我喝水` 或 `bash /path/to/script.sh` |
| `interval` | 间隔秒数 | `3600`(1小时) / `60`(1分钟) |
| `status` | 状态 | `active` / `paused` |
| `mode` | 执行模式 | `ai`(自然语言) / `shell`(命令) |
| `cron_expr` | Cron 表达式 | `*/12 5-6 * * 3,5` (仅 type=cron 时) |

### 操作示例

#### 添加任务

```
用户: 添加一个每小时提醒我喝水的任务
```

AI 直接编辑 `cron_task.json`：
```bash
# 读取当前 JSON
tasks=$(jq '.tasks' cron_task.json)

# 构建新任务
new_task='{
  "id": "'$(date +%s)-drink_water_reminder'",
  "type": "interval",
  "name": "喝水提醒",
  "command": "ai:提醒我喝水",
  "interval": 3600,
  "status": "active",
  "created": '$(date +%s)',
  "next_run": '$(($(date +%s) + 3600))',
  "last_run": null,
  "run_count": 0,
  "mode": "ai"
}'

# 追加并写回
echo "{\"tasks\": $tasks + [$new_task]}" | jq . > cron_task.json
```

#### 列出任务

```
用户: 列出所有任务
```

AI 读取并格式化显示：
```bash
jq -r '.tasks[] | "[\(.status)] \(.name) | \(.type) | 下次: \(.next_run | strftime("%m-%d %H:%M"))"' cron_task.json
```

#### 删除任务

```
用户: 删除任务 1774624286-drink_water_reminder
```

AI 直接操作：
```bash
jq --arg id "1774624286-drink_water_reminder" 'del(.tasks[] | select(.id == $id))' cron_task.json > tmp.json && mv tmp.json cron_task.json
```

#### 暂停/恢复任务

```
用户: 暂停任务 1774624286-drink_water_reminder
```

AI 直接操作：
```bash
# 暂停
jq --arg id "1774624286-drink_water_reminder" '.tasks[] |= if .id == $id then .status = "paused" else . end' cron_task.json > tmp.json && mv tmp.json cron_task.json

# 恢复
jq --arg id "1774624286-drink_water_reminder" '.tasks[] |= if .id == $id then .status = "active" else . end' cron_task.json > tmp.json && mv tmp.json cron_task.json
```

---

## 任务模式

| 模式 | command 格式 | 说明 |
|------|-------------|------|
| AI | `ai:提醒我喝水` | 自然语言，交给 picoclaw 处理 |
| Shell | `bash /path/to/script.sh` | 执行系统命令 |

### AI 模式示例

```
"每小时提醒我喝水" → command: "ai:提醒我喝水"
"每天早上8点播报天气" → command: "ai:用中文播报今天天气"
"每周五下午5点总结" → command: "ai:总结本周工作"
```

### Shell 模式示例

```
"每小时清理日志" → command: "bash find /tmp -name '*.log' -delete"
"每天备份数据库" → command: "bash /root/backup.sh"
```

---

## 任务类型

| 类型 | 说明 | 任务结束后的行为 |
|------|------|-----------------|
| `interval` | 间隔任务 | 更新 next_run，继续执行 |
| `once` | 一次性任务 | 自动从 JSON 中删除 |
| `cron` | Cron 表达式任务 | 根据 cron_expr 计算下次执行时间 |

---

## Cron 表达式

```
┌───────────── 分钟 (0-59)
│ ┌─────────── 小时 (0-23)
│ │ ┌───────── 日 (1-31)
│ │ │ ┌─────── 月 (1-12)
│ │ │ │ ┌───── 星期 (0-7, 0和7=周日)
│ │ │ │ │
* * * * *

常用示例：
*/12 * * * *       - 每 12 分钟
*/5 9-17 * * *     - 工作时间每 5 分钟
0 9 * * 1-5        - 工作日 9 点
*/30 5-6 * * 3,5   - 每周三、五 5-6 点每 30 分钟
0 0 1 * *          - 每月 1 日午夜
```

---

## 系统集成

### 设置系统 cron（每分钟执行）

```bash
(crontab -l 2>/dev/null | grep -v "cron_run.sh"; \
  echo "* * * * * cd /root/.picoclaw/workspace/skills/cron-task-skill/scripts && ./cron_run.sh >> /root/.picoclaw/workspace/cron_task/execution.log 2>&1") | crontab -
```

### 手动触发

```bash
# 执行任务检查（每30分钟自动清理一次）
./cron_run.sh

# 手动立即清理
./cron_cleanup.sh
```

---

## 验证操作

> ⚠️ **重要**：每次修改 `cron_task.json` 后必须验证

```bash
# 验证 JSON 格式
cat cron_task.json | jq .

# 查看任务列表
jq -r '.tasks[] | .id + " | " + .name + " | " + .status + " | " + (.next_run | tostring)' cron_task.json
```

---

## 示例对话

```
用户: 添加一个每小时提醒我喝水的任务
 Pico: ✓ 已添加任务
       ID: 1774624286-drink_water_reminder
       类型: interval
       间隔: 3600秒
       模式: AI
       命令: ai:提醒我喝水
       
       验证: jq 通过 ✓

用户: 添加一个每周三周五早上5-6点每12分钟的任务
 Pico: ✓ 已添加任务
       ID: 1774624287-morning_task_5_6
       类型: cron
       表达式: */12 5-6 * * 3,5
       
       验证: jq 通过 ✓

用户: 列出所有任务
 Pico: 
 1. [active] 喝水提醒 | interval | 下次: 03-26 23:00
 2. [active] 晨间任务 | cron | 下次: 03-26 05:00

用户: 删除任务 1774624286-drink_water_reminder
 Pico: ✓ 已删除任务 1774624286-drink_water_reminder
       
       验证: jq 通过 ✓

用户: 暂停任务 1774624287-morning_task_5_6
 Pico: ✓ 已暂停任务 1774624287-morning_task_5_6
       
       验证: jq 通过 ✓
```

---

## ⚠️ 注意事项（必须遵守）

### 1. Shell 脚本必须设置执行权限

> 创建任何 `.sh` 脚本后，**必须立即执行 `chmod +x`**，否则任务无法执行！

```bash
# 错误示例：文件无执行权限
-rw------- 1 root root  168 Mar 27 10:39 send_user_md.sh  ❌

# 正确示例：文件有执行权限
-rwx--x--x 1 root root  168 Mar 27 10:39 send_user_md.sh  ✅
```

### 2. 脚本命名必须与任务 ID 一致

```
脚本名 = 任务ID + ".sh"
```

### 3. 完整创建流程

```bash
# 1. 创建脚本
cat > /root/.picoclaw/workspace/cron_task/run_sh/任务ID.sh << 'EOF'
#!/bin/bash
# 你的命令
EOF

# 2. ⚠️ 必须立即设置执行权限！
chmod +x /root/.picoclaw/workspace/cron_task/run_sh/任务ID.sh

# 3. 添加任务到 JSON
jq --argjson task '{...}' '.tasks += [$task]' cron_task.json > tmp.json && mv tmp.json cron_task.json
```

---

## 版本历史

### v3.2.0 (2026-03-27)
- 📋 新增：任务 ID 格式规范 `时间戳-任务简介`
- ✏️ 更新：示例对话中的任务 ID 格式

### v3.1.0 (2026-03-27)
- ⏱️ 优化：cron_cleanup.sh 改为每整点(:00)或半点(:30)执行一次

### v3.0.0 (2026-03-26)
- ✨ 极简设计：只有 2 个系统脚本
- 🤖 任务 CRUD 完全由 AI 直接操作 JSON
- 🧹 cron_cleanup.sh 清理孤立脚本

### v2.0.0 (2026-03-25)
- 初始版本
