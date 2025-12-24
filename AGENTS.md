# AGENTS.md

## AI Agent Preferences

- **Language**: 繁體中文 (Traditional Chinese)
- **Response Style**: 精簡、技術導向
- **Code Comments**: English
- **Error Messages / Logs**: English

## Work Session Management

### Session Continuity Strategy

為避免 token 限制中斷工作：

1. 規劃時，分割為小型可完成的工作單元
2. 先寫規劃檔，記錄完整前情提要
3. 每完成一個動作即更新工作進度

### Documentation Structure

所有 AI 協作相關文檔統一存放於 `~/CLAUDE/` 目錄：

```
~/CLAUDE/
├── AGENTS.md                    # 本文件 - AI 協作規範
├── README.md                    # 文檔目錄說明
├── workflows/                   # 可重複使用的 SOP 或獨立工作
│   └── WF-YYYYMMDD-n-description/ # 以日期+英文簡述命名,同一天有多個任務時,n 為1~9
│       ├── *.md                 # 計劃、文件
│       ├── script/              # 工作產生的腳本
│       ├── data/                # 工作產生的資料檔
│       └── worklogs/            # 工作日誌
│           ├── WORKLOG-YYYYMMDD-*.md
│           └── completed/YYYY-MM/  # 已完成歸檔
└── templates/                   # 文檔範本
```

個別git 的專案目錄下的docs 以顯示精簡的文件說明，不需顯示變更歷程。

### Document Header

每個 workflow md 檔開頭需包含：

```markdown
---
ref: [AGENTS.md](~/CLAUDE/AGENTS.md)
status: 進行中 | 已完成 | 暫停
created: YYYY-MM-DD
updated: YYYY-MM-DD
---
```

## Shell 規範

- 禁用 ANSI color codes（輸出不帶顏色）
- 所有輸出不要出現色碼
- 優先使用 POSIX 相容語法

## Git 規範

做任何推送前先 pull 
針對以下目錄的專案，使用 `git-tp` 取代 `git` 指令
- 其他版控：使用標準 `git` 指令

## 權限規範

- 允許 `/Users/user/` 目錄下的操作，無需額外確認