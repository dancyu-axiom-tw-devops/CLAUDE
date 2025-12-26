---
ref: [AGENTS.md](~/CLAUDE/AGENTS.md)
status: 進行中
created: 2025-12-26
updated: 2025-12-26
---

# PIGO-DEV Kubernetes 每日資源健康巡檢

## Mission

建立 pigo-dev 環境的每日自動巡檢機制，取代 DevOps 人工檢查。
完成驗證後，複製模式至 pigo-stg, pigo-rel。

**原則：只觀察、不干預**

---

## 環境資訊 (pigo-dev)

| 項目 | 值 |
|------|-----|
| 叢集登入 | `tp-hkidc` |
| Namespace | `pigo-dev` |
| 專案目錄 | `/Users/user/PIGO-project/hkidc-k8s-gitlab/pigo-dev-k8s-deploy/` |
| Monitor 目錄 | `/Users/user/PIGO-project/hkidc-k8s-gitlab/pigo-dev-k8s-deploy/monitor/` |
| Git 版控 | gitlab.axiom-infra.com (使用 `git-tp`) |
| 報告上傳 | https://github.com/dancyu-axiom-tw-devops/k8s-daily-monitor.git |

若是創建 排程服務 假設名稱是monitor-cronjob 服務, 那就在 /Users/user/PIGO-project/hkidc-k8s-gitlab/pigo-dev-k8s-deploy/monitor/ 創建monitor-cronjob 目錄, 腳本架構請比照 /Users/user/PIGO-project/hkidc-k8s-gitlab/pigo-dev-k8s-deploy 其他服務的k8s腳本

### Slack

- Channel: `pigo-dev-devops-alert`
- Webhook: `https://hooks.slack.com/services/YOUR_WEBHOOK_URLavULzD12iKRjGbuMOiSmdb`

### 排程

- 執行時間：每日 09:00 (台灣時間)
- Cron 表達式：(待用戶補充)

### GitHub App

```
App ID: 2539631
Client ID: Iv23libLdZu21fUN9HzO
Secret: /Users/user/CLAUDE/credentials/gcr-juancash-prod.json
```

---

## 檢查範圍

### 對象
- 所有 Running 狀態 Pods
- 排除 system namespaces

### 檢查項目

| 類別 | 檢查內容 | 判斷標準 |
|------|----------|----------|
| Memory | Avg/Peak vs request/limit | >80% limit → 高風險, <50% limit → 過度配置 |
| CPU | Avg/Peak vs request/limit | <20% request → 可優化 |
| OOM/Restart | 24h restart 次數, OOMKilled | 有 OOM → 不適合下修 |
| 設定異常 | 無 limit, 無 request | 標註需修正 |

---

## 輸出規格

### 格式規範

- **禁用 Emoji** - 不使用任何 emoji 符號
- **語氣** - 工程分析風格，避免「高風險」「嚴重」「緊急」等情緒用語
- **建議** - 方向性為主（如「consider」「review」），不給具體指令
- **健康項目** - 僅列數量，不逐一列出

### 1. Markdown 報告 (GitHub)

檔名：`pigo-k8s-resource-optimization-YYYYMMDD.md`

結構：
1. Summary - 數量統計表
2. Pod Status Issues - 僅列異常 Pod
3. Resource Utilization Review - CPU/Memory 分析（核心）
4. Configuration Issues - 缺 limit/request
5. Recommendations - 方向性建議
6. Healthy Services - 僅列數量

範本：`templates/report-template.md`

### 2. Slack 通知 (條列式，無表格無 emoji)

```
[PIGO] Daily K8s Health Check

Summary
- Namespaces: pigo-dev / pigo-stg / pigo-rel
- Pods checked: N
- Unhealthy pods: N
- Pods with restarts: N

Resource Review Required
- service-name
  - CPU avg X cores (Y% of Z request)
  - Status: Running / Ready
  - Note: observation

Healthy Services
- service-a
- service-b
```

---

## 實作架構

### 專案目錄結構

```
/Users/user/PIGO-project/hkidc-k8s-gitlab/pigo-dev-k8s-deploy/
└── monitor/
    ├── scripts/
    │   └── health-check.sh          # 主腳本
    ├── k8s/
    │   ├── secret-slack-webhook.yaml
    │   ├── secret-github-token.yaml
    │   ├── rbac.yaml
    │   └── cronjob.yaml
    └── README.md
```

### 報告上傳目錄 (GitHub)

```
https://github.com/dancyu-axiom-tw-devops/k8s-daily-monitor.git
└── reports/
    └── pigo-dev/
        └── YYYY-MM/
            └── pigo-dev-k8s-health-YYYYMMDD.md
```

### 環境變數

| 變數 | 說明 | 值 |
|------|------|-----|
| `TARGET_NAMESPACE` | 檢查目標 | `pigo-dev` |
| `SLACK_WEBHOOK_URL` | 通知 URL | 從 Secret 注入 |
| `GITHUB_TOKEN` | 上傳用 | 從 Secret 注入 |

## 實作模組

| # | 模組 | 說明 |
|---|------|------|
| 1 | Pod resource collector | kubectl 取得 CPU/Memory usage + request/limit |
| 2 | Resource analyzer | 計算使用率，判斷是否偏低或貼近上限 |
| 3 | Candidate identifier | 標記可優化 Pod |
| 4 | Report generator | 產出 Markdown 報告 |
| 5 | Slack notifier | 發送 Slack 通知 |
| 6 | GitHub uploader | 上傳報告至 repo |

## CronJob 規格

```yaml
metadata:
  name: k8s-health-check
  namespace: pigo-dev

spec:
  schedule: "(待補充)"  # 09:00 台灣時間
  concurrencyPolicy: Forbid
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 3
```

---

## MVP 執行順序 (pigo-dev)

```
Phase 1: 驗證環境
├── [ ] 確認 kubectl 可存取 tp-hkidc
├── [ ] 確認 metrics-server 可用 (kubectl top pods -n pigo-dev)
├── [ ] 測試 Slack webhook 可發送
└── [ ] 驗證結果：三項皆通過

Phase 2: 核心腳本
├── [ ] 建立 monitor/ 目錄結構
├── [ ] 實作 health-check.sh
│   ├── Pod resource collector
│   ├── Resource analyzer (Memory + OOM)
│   ├── Markdown renderer
│   └── Slack renderer
├── [ ] 本地測試腳本執行
└── [ ] 驗證結果：產出正確格式報告 + Slack 通知

Phase 3: K8s 部署元件
├── [ ] 建立 secret-slack-webhook.yaml
├── [ ] 建立 secret-github-token.yaml
├── [ ] 建立 rbac.yaml
├── [ ] 建立 cronjob.yaml
├── [ ] 手動觸發 Job 測試
└── [ ] 驗證結果：Job 執行成功、Slack 收到通知

Phase 4: 整合與上傳
├── [ ] 實作 GitHub 報告上傳
├── [ ] 完整流程測試
├── [ ] 部署 CronJob 至叢集
├── [ ] 等待排程執行驗證
└── [ ] 驗證結果：自動執行、報告上傳、Slack 通知

完成後：複製模式至 pigo-stg, pigo-rel
```

---

## 注意事項

1. **語氣**：工程分析風格，避免「高風險」「嚴重問題」等情緒用語
2. **建議**：方向性為主，不給具體數值
3. **Secret**：僅從環境變數或 K8s Secret 讀取，禁止 hardcode
4. **Git 版控**：
   - 專案目錄 (gitlab.axiom-infra.com)：使用 `git-tp` 指令
   - 報告 Repo (github.com)：使用標準 `git` 指令
5. **禁用 Emoji**：報告與通知皆不使用 emoji
