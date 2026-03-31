---
name: clawmark
version: "0.2.1"
description: AI 记忆信号系统 - 跨会话知识管理，让 AI 记住修复了什么、为什么坏掉、如何修复
metadata: {"picoclaw":{"emoji":"📡","requires":{"bins":["bash","sqlite3","curl"]}}}
---

# clawmark - AI 记忆信号系统

> 你的下一个会话是冷启动。没有记忆你构建了什么、什么坏了、你决定了什么。每一个你写的信号都是给未来会话的礼物。信号越丰富，重新学习的时间就越少。

支持任何框架 — OpenClaw、Claude Code、Aider、Cursor 或任何有 shell 访问的框架。

## 为什么这很重要

一条写着"修好了 auth bug"的信号对你的未来毫无帮助。

一条写着什么坏了、为什么坏、怎么修好的信号能节省一小时。

信号会累积。一个信号是笔记，一整站信号是制度性知识。为那个一无所知的未来的你而写。

## 命令

```bash
# 保存你学到的东西 — 管道输入详细内容，内联输入快速笔记
echo "Token validation was running before refresh in auth.rs.
Swapped lines 42-47. Root cause: middleware ordering assumed
sync validation, but OAuth refresh is async. Three edge cases
tested: expired token, revoked token, concurrent refresh." \
  | clawmark signal -c - -g "fix: auth token refresh — async ordering in middleware"

# 快速信号（不需要深度时）
clawmark signal -c "Upgraded rusqlite to 0.32" -g "dep: rusqlite 0.32"

# 从文件创建信号
clawmark signal -c @session-notes.md -g "session: March 19 architecture review"

# 线程化后续信号
clawmark signal -c "Same fix needed in staging compose" -g "fix: staging auth ordering" -p A1B2C3D4

# 按语义搜索 — 不是关键词
clawmark tune "authentication middleware"
clawmark tune "what broke in production last week"

# 关键词回退
clawmark tune --keyword "auth"

# 最近信号
clawmark tune --recent

# 完整内容（不只是 gist）
clawmark tune --full "auth"

# 发现你遗忘的东西
clawmark tune --random

# 批量加载现有文件
clawmark capture ./docs/

# 从 OpenClaw 工作区导入
clawmark capture --openclaw

# 从 PicoClaw 工作区导入
clawmark capture --picoclaw

# 构建嵌入缓存（一次，之后自动）
clawmark backfill

# 站点统计
clawmark status
```

## 共享站点

多个 agent 可以写入同一个站点。一个 agent 学到的，每个 agent 都能找到。

```bash
CLAWMARK_STATION=/shared/team.db clawmark signal -c "Deploy complete" -g "ops: deploy v2.1"
CLAWMARK_STATION=/shared/team.db clawmark tune "deploy"
```

## 何时发信号

- **解决难题之后。** 你的下一个会话会遇到同样的问题。给它答案。
- **会话结束之前。** 你上下文窗口中的所有内容都随着会话消亡。你的站点不会。
- **发现非显而易见的东西时。** 小事实 — 哪个配置标志、哪行代码、哪个边缘情况 — 是节省最多时间的。

## 何时调谐 (tune)

- **开始新任务时。** 你可能上周已经解决了部分。
- **卡住时。** 答案可能在你三个会话前写的信号里。
- **压缩之后。** 你的上下文被压缩了。你的站点没有。

## 写好信号

概要是你未来的自己如何找到这个信号。内容是找到后让它有用的东西。

**概要：** 压缩洞察。`"fix: auth token refresh — async ordering in middleware"` — 类别、什么、为什么、在哪里。

**内容：** 让它自包含。如果你未来的自己只读这个信号 — 没有会话历史、没有周围上下文 — 他们能理解发生了什么并采取行动吗？

信号不需要长。它需要完整。

## 工作原理

信号生活在 SQLite 数据库中。语义搜索使用本地 BERT 模型 — 无 API 调用、无云、完全离线运行。模型在首次搜索时下载一次（~118MB）。之后的每个信号自动嵌入。

搜索按含义而非关键词查找信号。"Authentication middleware" 匹配一个关于 "token validation ordering" 的信号，因为概念重叠。

## 工作区适配器

clawmark 支持从不同工作区格式导入：

### OpenClaw

路径：`~/.openclaw/workspace/`

```
workspace/
├── MEMORY.md              # 长期记忆
├── memory/                # 每日日志
│   ├── 2024-01-01.md
│   └── 2024-01-02.md
└── AGENTS.md              # Agent 定义（可选）
```

### PicoClaw

路径：`~/.picoclaw/workspace/memory/`

```
.picoclaw/
└── workspace/
    └── memory/            # 所有 .md 文件
        ├── notes.md
        ├── 2024-01-01.md
        └── ...
```

两个适配器都会扫描各自的目录并导入所有 markdown 文件作为信号。使用 `--openclaw` 或 `--picoclaw` 指定要导入的工作区。

---

## 版本历史 / Changelog

### v0.2.1 (2026-03-31)
- 🔧 转换为 picoclaw 格式，添加 frontmatter

### v0.2.0
- 初始发布
