---
ref: [AGENTS.md](~/CLAUDE/AGENTS.md)
status: 已完成部署 (Production)
created: 2025-12-24
updated: 2025-12-24
deployed: 2025-12-24
version: v7
repository: gitlab.axiom-infra.com/forex/forex-prod/forex-prod-k8s-infra-deploy
deployment_path: /health-check/exchange-health-check
---

# Exchange Service 每日自動化健康檢視系統

自動化監控 exchange-service 的健康狀況，每日執行檢視並發送報告至 Slack。

## 功能概述

- **每日自動執行**：09:00 UTC+8 自動觸發檢視流程
- **記憶體洩漏檢測**：使用線性回歸分析記憶體趨勢，及早發現潛在問題
- **資源配置分析**：評估 requests/limits 設定的合理性
- **HPA 行為分析**：檢測過度擴展或擴容不足的情況
- **異常事件監控**：檢測 OOMKilled、Pod Restart 等異常事件
- **Slack 通知**：自動發送技術報告至運維團隊

## 快速開始

### 前置條件

- Kubernetes cluster with access to `forex-prod` namespace
- Prometheus server accessible at `http://prometheus-operated.monitoring.svc.cluster.local:9090`
- Metrics Server enabled (`kubectl top` available)
- Slack Bot Token or Webhook URL

### 部署步驟

1. **創建 Secret**（Slack credentials）:
   ```bash
   kubectl create secret generic slack-credentials \
     --from-literal=bot-token=xoxb-your-token-here \
     -n forex-prod
   ```

2. **部署 RBAC**:
   ```bash
   kubectl apply -f deployment/rbac.yml
   ```

3. **部署 ConfigMap**:
   ```bash
   kubectl apply -f deployment/configmap.yml
   ```

4. **部署 CronJob**:
   ```bash
   kubectl apply -f deployment/cronjob.yml
   ```

5. **手動測試**（可選）:
   ```bash
   kubectl create job --from=cronjob/exchange-health-check manual-test-$(date +%s) -n forex-prod
   kubectl logs -f job/manual-test-xxx -n forex-prod
   ```

詳細部署指南請參考 [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md)

## 架構設計

### 核心組件

```
┌─────────────────────────────────────────────────────────┐
│                   CronJob (09:00 UTC+8)                 │
│                  exchange-health-check                  │
└─────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────┐
│                   healthcheck.py (主程式)                │
│         collect → analyze → report → notify             │
└─────────────────────────────────────────────────────────┘
           │            │            │            │
           ▼            ▼            ▼            ▼
    ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐
    │Prometheus│  │K8s API  │ │Reporter │  │ Slack   │
    │ Client  │  │ Client  │ │(MD/JSON)│  │Notifier │
    └─────────┘  └─────────┘  └─────────┘  └─────────┘
           │            │            │            │
           ▼            ▼            ▼            ▼
    ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐
    │PromQL   │  │Pod/HPA/ │  │PVC      │  │Slack API│
    │ Queries │  │Events   │  │Storage  │  │         │
    └─────────┘  └─────────┘  └─────────┘  └─────────┘
```

### 數據來源

- **Prometheus Metrics**:
  - `container_memory_working_set_bytes` - 記憶體使用量
  - `container_cpu_usage_seconds_total` - CPU 使用量
  - `kube_pod_container_status_restarts_total` - Pod 重啟次數

- **Kubernetes API**:
  - Deployment resources (requests/limits)
  - HPA status (current/desired replicas)
  - Events (OOMKilling, BackOff)

### 分析算法

#### 1. 記憶體洩漏檢測

使用 **線性回歸** 分析過去 24 小時的記憶體趨勢：

```python
# 判定條件（需同時滿足）:
- Slope > 10 MB/hour        # 增長速度
- R² > 0.7                  # 強相關性
- p-value < 0.05            # 統計顯著性
```

#### 2. 資源配置分析

- **過度配置**: 平均使用量 < 50% request → 建議降低 request
- **OOM 風險**: P95 使用量 > 85% limit → 建議提升 limit
- **QoS 警告**: limit / request > 2 → 可能影響 QoS 等級

#### 3. HPA 行為分析

- **過度擴展**: replicas ≥ 5 但 avg CPU < 0.5 cores
- **擴容不足**: replicas ≤ 2 但 avg memory > 5000Mi

## 報告格式

### Markdown 報告（發送至 Slack）

```markdown
# 🟢 Exchange Service 健康檢視報告

**檢視時間**: 2025-12-24 09:00:00
**檢視期間**: 過去 24 小時
**整體狀態**: HEALTHY | WARNING | CRITICAL

## 📊 數據摘要
...

## 🚨 問題與風險
...

## 💡 優化建議
...
```

### JSON 報告（存檔於 PVC）

完整的結構化數據，包含所有指標、問題詳情及建議動作。

## 配置調整

### 閾值配置

編輯 [config/thresholds.yaml](config/thresholds.yaml) 調整各項閾值：

```yaml
memory:
  usage_warning: 75         # % vs limit
  usage_critical: 85
  leak_slope_threshold: 10  # MB/hour

hpa:
  min_replicas_cpu_threshold: 0.5
  max_replicas_memory_threshold: 5000
```

修改後重新部署 ConfigMap:
```bash
kubectl apply -f deployment/configmap.yml
kubectl rollout restart cronjob/exchange-health-check -n forex-prod
```

詳細說明請參考 [docs/THRESHOLDS.md](docs/THRESHOLDS.md)

## 運維手冊

### 檢視 CronJob 狀態

```bash
# 檢視 CronJob
kubectl get cronjob exchange-health-check -n forex-prod

# 檢視最近的 Job
kubectl get jobs -n forex-prod -l job-name=exchange-health-check

# 檢視 Job 日誌
kubectl logs -f job/exchange-health-check-xxx -n forex-prod
```

### 手動觸發檢查

```bash
kubectl create job --from=cronjob/exchange-health-check manual-check-$(date +%s) -n forex-prod
```

### 調整執行時間

編輯 [deployment/cronjob.yml](deployment/cronjob.yml):

```yaml
spec:
  schedule: "0 1 * * *"  # 修改為所需的 cron 表達式
```

更多運維指南請參考 [docs/RUNBOOK.md](docs/RUNBOOK.md)

## 文檔

- [DESIGN.md](docs/DESIGN.md) - 詳細架構設計
- [DEPLOYMENT.md](docs/DEPLOYMENT.md) - 部署指南
- [RUNBOOK.md](docs/RUNBOOK.md) - 運維手冊
- [THRESHOLDS.md](docs/THRESHOLDS.md) - 閾值調整指南

## 目錄結構

```
WF-20251224-exchange-health-monitoring/
├── README.md                          # 本文件
├── deployment/                        # Kubernetes 部署文件
│   ├── cronjob.yml                   # CronJob 定義
│   ├── configmap.yml                 # 配置（Prometheus URL, 閾值）
│   ├── rbac.yml                      # ServiceAccount + RBAC
│   ├── secret-template.yml           # Slack credentials 範本
│   └── docker/
│       ├── Dockerfile                # Python 3.11 runtime
│       └── requirements.txt          # 依賴套件
├── scripts/                          # 核心腳本
│   ├── healthcheck.py                # 主程式
│   ├── prometheus_client.py          # Prometheus API 封裝
│   ├── k8s_client.py                 # Kubernetes API 封裝
│   ├── analyzer.py                   # 數據分析邏輯
│   ├── reporter.py                   # 報告生成
│   ├── slack_notifier.py             # Slack 通知
│   └── config_loader.py              # 配置載入
├── config/                           # 配置文件
│   ├── thresholds.yaml               # 閾值配置
│   └── promql_queries.yaml           # PromQL 查詢模板
├── data/                             # 工作產生的資料
│   ├── example-reports/              # 示例報告
│   └── reports/                      # 實際報告存檔位置
├── docs/                             # 文檔
├── worklogs/                         # 工作日誌
└── tests/                            # 單元測試（可選）
```

## Phase 2 擴展計畫（未來）

Phase 1 穩定運行 1-2 週後，可考慮擴展功能：

- **JMX Exporter**: 獲取詳細 JVM 指標（heap, GC, threads）
- **ServiceMonitor**: 整合 Prometheus Operator
- **GC 日誌分析**: 深度分析 GC 效率
- **自定義告警**: PrometheusRule 整合

## 技術棧

- **語言**: Python 3.11
- **數據分析**: pandas, scipy
- **Kubernetes**: kubernetes-python-client
- **監控**: Prometheus API
- **通知**: Slack API / Webhook

## 授權

Internal use only - Axiom Infrastructure Team

## 聯絡

- **維護者**: SRE Team
- **Slack Channel**: #sre-alerts
- **文檔位置**: `/Users/user/CLAUDE/workflows/WF-20251224-exchange-health-monitoring/`

# 實際部署 要納入版控 
/Users/user/FOREX-project/gitlab.axiom-infra.com/forex-prod-k8s-infra-deploy/health-check
使用git-tp 操作git指令