---
ref: [AGENTS.md](~/CLAUDE/AGENTS.md)
status: 已完成
created: 2025-12-24
updated: 2025-12-24
---

# JuanCash JC-Refactor Services 健康檢查工具

JC-Refactor 專案下所有服務（37個微服務）的健康檢查與日誌分析工具集。

## 概述

本 workflow 提供三個自動化檢查腳本，用於監控 `jc-prod` namespace 下所有 jc-refactor 服務的運行狀況。

**服務範圍**:
- **API Services**: 7 個（juanworld-api, juancash-open-api 等）
- **APP Services**: 30 個（admin, scheduler, app, open, socket, client 類別）

## 目錄結構

```
WF-20251224-2-juancash-service-check/
├── README.md                          # 本文件
├── scripts/                           # 檢查腳本
│   ├── check-services.sh             # 2.1 檢查服務是否啟動
│   ├── check-logs-exist.sh           # 2.2 檢查日誌是否產生
│   └── check-logs-errors.sh          # 2.3 檢查日誌報錯
├── docs/                             # 文檔
│   └── ERROR-LOG-CHECK-GUIDE.md      # 完整錯誤日誌檢查指南
├── data/                             # 執行結果存檔位置
└── worklogs/                         # 工作日誌
    └── WORKLOG-20251224-setup.md
```

## 快速開始

### 1. 檢查所有服務是否啟動

```bash
cd /Users/user/CLAUDE/workflows/WF-20251224-2-juancash-service-check/scripts
./check-services.sh
```

**輸出**:
- 每個服務的 Deployment 狀態
- Ready/Desired pod 數量
- Pod 運行狀態與重啟次數

### 2. 檢查日誌文件是否存在

```bash
./check-logs-exist.sh
```

**檢查項目**:
- NAS 日誌目錄是否存在（`/juancash/logs/<service-name>`）
- 日誌文件數量
- 最近 24 小時內的日誌更新

### 3. 檢查日誌中的錯誤

```bash
# 預設：檢查最近 1 小時、每個 pod 200 行日誌
./check-logs-errors.sh

# 自訂參數：檢查最近 3 小時、每個 pod 500 行日誌
./check-logs-errors.sh 500 3h

# 檢查最近 24 小時、每個 pod 2000 行日誌
./check-logs-errors.sh 2000 24h
```

**錯誤模式**:
- error, exception, fatal, fail, panic
- timeout, refused, cannot

## 使用場景

### 場景 1: 每日例行檢查

```bash
# 執行所有三個檢查，輸出到報告文件
cd /Users/user/CLAUDE/workflows/WF-20251224-2-juancash-service-check/scripts

./check-services.sh > ../data/service-status-$(date +%Y%m%d).txt
./check-logs-exist.sh > ../data/log-files-$(date +%Y%m%d).txt
./check-logs-errors.sh 500 24h > ../data/errors-$(date +%Y%m%d).txt
```

### 場景 2: 部署後驗證

```bash
# 部署新版本後，檢查所有服務狀態
./check-services.sh | grep -E "(DEGRADED|NO RUNNING PODS|NOT FOUND)"

# 檢查最近 30 分鐘的錯誤
./check-logs-errors.sh 200 30m
```

### 場景 3: 故障排查

```bash
# 深度檢查最近 3 小時的錯誤
./check-logs-errors.sh 1000 3h > ../data/troubleshoot-$(date +%Y%m%d_%H%M%S).txt

# 針對特定服務深入分析（使用原始 kubectl 命令）
kubectl logs -n jc-prod -l app=juancash-open-api --tail=5000 --since=3h > juancash-open-api-full.log
```

## 腳本說明

### check-services.sh

**功能**: 檢查所有 37 個服務的 Deployment 和 Pod 狀態

**檢查項目**:
- Deployment 是否存在
- Desired vs Ready replicas
- Pod 運行狀態（Running, Pending, CrashLoopBackOff）
- Pod 重啟次數

**輸出狀態**:
- `OK - X/X pods ready`: 所有 pod 正常
- `DEGRADED - X/Y pods ready`: 部分 pod 未就緒
- `NO RUNNING PODS`: 無運行中的 pod
- `DEPLOYMENT NOT FOUND`: Deployment 不存在

### check-logs-exist.sh

**功能**: 檢查 NAS 上的日誌文件是否正常產生

**檢查方式**:
- 透過 juanworld-api pod exec 檢查 NAS
- 驗證日誌目錄存在性
- 統計日誌文件數量
- 顯示最新日誌文件修改時間

**注意**: 僅檢查部分代表性服務（可修改腳本增加更多）

### check-logs-errors.sh

**功能**: 從 Kubernetes 日誌中掃描錯誤訊息

**搜尋模式**:
- 包含: error, exception, fatal, fail, panic, timeout, refused, cannot
- 排除: debug, trace, info 級別的誤報

**參數**:
1. `LINES`: 每個 pod 檢查的日誌行數（預設 200）
2. `SINCE`: 時間窗口（預設 1h，可用 30m, 3h, 24h）

**輸出**:
- 每個服務的錯誤數量
- 前 20 行錯誤訊息（如超過則顯示 "and X more..."）

## 詳細文檔

完整的錯誤日誌分析指南請參考：
- [ERROR-LOG-CHECK-GUIDE.md](docs/ERROR-LOG-CHECK-GUIDE.md)

包含內容:
- 37 個服務清單
- 手動檢查方法
- 常見錯誤模式（Connection, Database, NPE, OOM, Timeout, HTTP）
- 錯誤分析工作流程
- 故障排查指南

## 服務清單

### API Services (7)

| Service | Deployment Name |
|---------|----------------|
| JuanWorld API | juanworld-api |
| JuanWorld Admin API | juanworld-admin-api |
| JuanCash Open API | juancash-open-api |
| JuanCash Bank API | juancash-bank-api |
| JuanCash Applet API | juancash-applet-api |
| JuanCash Client API | juancash-clicent-api |
| JuanWord Shop Manager API | juanword-api-shopmanager |

### APP Services (30)

**分類**:
- Admin (9): juanworld-admin-settlement, juancash-admin-bank, ...
- Scheduler (4): juancash-scheduler-bank, juancash-scheduler-pay, ...
- App (10): juancash-app-bank, juancash-app-pay, juanworld-app-merchant, ...
- Open (4): juancash-open-bank, juancash-open-pay, ...
- Socket (2): juancash-socket-app, juancash-socket-merchant
- Client (4): juancash-client-finance, juancash-client-merchant, ...

完整清單請參考 [ERROR-LOG-CHECK-GUIDE.md](docs/ERROR-LOG-CHECK-GUIDE.md)

## 注意事項

### Shell 規範

依據 [AGENTS.md](~/CLAUDE/AGENTS.md) 規範:
- ✅ 禁用 ANSI color codes（所有腳本均無色碼輸出）
- ✅ 使用 POSIX 相容語法
- ✅ 腳本與文檔分離存放

### 權限要求

執行腳本需要:
- Kubernetes 集群訪問權限（kubectl configured）
- `jc-prod` namespace 的 read 權限
- Pod exec 權限（用於 check-logs-exist.sh）

### 資料存放

建議將檢查結果存放於：
```bash
/Users/user/CLAUDE/workflows/WF-20251224-2-juancash-service-check/data/
```

可依日期分類歸檔：
```
data/
├── 2025-12-24/
│   ├── service-status-20251224.txt
│   ├── log-files-20251224.txt
│   └── errors-20251224.txt
└── 2025-12-25/
    └── ...
```

## 維護

### 更新服務清單

當新增或移除服務時：
1. 修改 `scripts/check-*.sh` 中的服務列表
2. 更新 `docs/ERROR-LOG-CHECK-GUIDE.md` 的服務清單
3. 更新本 README.md 的服務數量

### 調整錯誤模式

如需調整錯誤檢測的敏感度：
- 編輯 `scripts/check-logs-errors.sh`
- 修改變數: `ERROR_PATTERNS`, `EXCLUDE_PATTERNS`

## 相關文檔

- [AGENTS.md](~/CLAUDE/AGENTS.md) - AI 協作規範
- [TEMPLATE.md](/Users/user/JUANCASH-project/github/juancash-prod-k8s-deploy/jc-refactor/TEMPLATE.md) - JC-Refactor 服務部署模板

## 修改歷史

| 日期 | 修改內容 | 作者 |
|------|---------|------|
| 2025-12-24 | 初始化 workflow，創建三個檢查腳本 | Claude |
| 2025-12-24 | 移動 ERROR-LOG-CHECK-GUIDE.md 到 workflow | Claude |

---

**Last Updated**: 2025-12-24
**Author**: Claude Sonnet 4.5 (via Claude Code)
