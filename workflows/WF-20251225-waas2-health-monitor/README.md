---
ref: [AGENTS.md](~/CLAUDE/AGENTS.md)
ref: [k8s-service-monitor.md](~/CLAUDE/docs/k8s-service-monitor.md)
status: 已完成
created: 2025-12-25
updated: 2025-12-25
---

# Waas2 Tenant 服務健康監控系統

基於 k8s-service-monitor.md 規範實作的 Waas2 Tenant 服務每日健康檢查系統。

## 功能特性

- ✅ 每日自動執行（09:00 UTC+8）
- ✅ 8 項巡檢規則（按照 k8s-service-monitor.md）
- ✅ Slack 通知整合
- ✅ 歷史報告存檔
- ✅ Kubernetes CronJob 部署

## 監控範圍

**命名空間**: `waas2-prod`

**服務清單** (11 個):
- service-admin
- service-api
- service-eth
- service-exchange
- service-gateway
- service-notice
- service-pol
- service-search
- service-setting
- service-tron
- service-user

**不監控的基礎設施服務**:
- nacos
- xxl-job
- nginx
- kafka-ui
- waas2-log-sls

## 8 項巡檢規則

| # | 檢查項目 | 🟢 健康 | 🟡 注意 | 🔴 風險 |
|---|---------|---------|---------|---------|
| 1 | 可用性 | ready == desired | - | ready < desired |
| 2 | 穩定性 | restart == 0 | restart > 0 | OOMKilled |
| 3 | 記憶體使用 | - | - | ⚪ 無 Prometheus |
| 4 | 記憶體趨勢 | - | - | ⚪ 無 Prometheus |
| 5 | CPU 使用 | - | - | ⚪ 無 Prometheus |
| 6 | 錯誤率 | - | - | ⚪ 無 App Metrics |
| 7 | 延遲 | - | - | ⚪ 無 App Metrics |
| 8 | Pod 數量合理性 | pods > 0 | - | pods == 0 |

**整體狀態判定**:
- 任一 🔴 → 整體 🔴
- 無 🔴 但有 🟡 → 整體 🟡
- 全部 🟢 → 整體 🟢
- 關鍵項目資料不足 → 整體 🟡

## Slack 通知格式

按照 k8s-service-monitor.md 第七節規範：

- 🔴 服務清單（詳細顯示）
- 🟡 服務數量
- Top 3 問題原因

## 目錄結構

```
WF-20251225-waas2-health-monitor/
├── README.md                    # 本文件
├── scripts/
│   └── health-check.py         # 主要檢查腳本（Python 3.11）
├── deployment/
│   ├── Dockerfile              # Docker 鏡像定義
│   ├── cronjob.yml             # CronJob + RBAC + PVC
│   ├── secret-template.yml     # Slack webhook secret
│   ├── build-image.sh          # 構建 Docker 鏡像
│   └── deploy.sh               # 部署到 K8s
├── config/
│   └── (保留，未來可擴展)
├── docs/
│   └── (保留，未來可擴展)
├── data/
│   ├── services.txt            # 服務清單
│   └── reports/                # 報告輸出目錄
└── worklogs/
    └── WORKLOG-20251225-setup.md
```

## 快速開始

### 1. 構建 Docker 鏡像

```bash
cd deployment
./build-image.sh latest

# 推送到 GCR
docker push asia-east2-docker.pkg.dev/uu-prod/waas-prod/waas2-health-monitor:latest
```

### 2. 部署到 Kubernetes

```bash
cd deployment
./deploy.sh
```

這會自動：
- 創建 ServiceAccount 和 RBAC
- 創建 PVC 用於存儲報告
- 創建 Secret（Slack webhook）
- 部署 CronJob

### 3. 手動觸發測試

```bash
kubectl create job --from=cronjob/waas2-health-monitor manual-test-$(date +%s) -n waas2-prod

# 查看日誌
kubectl logs -f job/manual-test-xxx -n waas2-prod
```

### 4. 查看報告

報告存儲在 PVC `waas2-health-reports` 的 `/reports` 目錄下。

```bash
# 列出所有報告
kubectl exec -it -n waas2-prod <任一 pod> -- ls -la /path/to/reports/

# 查看最新報告
kubectl exec -it -n waas2-prod <任一 pod> -- cat /path/to/reports/health-check-latest.md
```

## 運維指南

### 檢查 CronJob 狀態

```bash
kubectl get cronjob waas2-health-monitor -n waas2-prod
kubectl get pods -n waas2-prod -l app=waas2-health-monitor
```

### 查看執行歷史

```bash
kubectl get jobs -n waas2-prod -l app=waas2-health-monitor
```

### 更新 Slack Webhook

```bash
kubectl delete secret waas2-health-monitor-secret -n waas2-prod
kubectl create secret generic waas2-health-monitor-secret \
  --from-literal=slack-webhook-url='https://hooks.slack.com/services/YOUR_WEBHOOK_URL...' \
  -n waas2-prod
```

### 修改執行時間

編輯 `deployment/cronjob.yml` 中的 `schedule` 欄位：

```yaml
spec:
  schedule: "0 1 * * *"  # 每天 01:00 UTC (09:00 UTC+8)
```

## 技術細節

### Docker 鏡像

- **基礎鏡像**: python:3.11-slim
- **工具**: kubectl, python3
- **腳本**: health-check.py

### Kubernetes 資源

- **ServiceAccount**: waas2-health-monitor
- **Role**: 讀取 pods, deployments, events, services
- **PVC**: waas2-health-reports (1Gi, alibabacloud-cnfs-nas)
- **CronJob**: 每日 09:00 UTC+8 執行

### 資源限制

```yaml
requests:
  cpu: 100m
  memory: 128Mi
limits:
  cpu: 200m
  memory: 256Mi
```

## 限制與未來改進

### 當前限制

1. **無 Prometheus 整合**:
   - 記憶體使用（3️⃣）、記憶體趨勢（4️⃣）、CPU 使用（5️⃣）檢查標示為"資料不足"
   - 僅能檢查可用性、穩定性、Pod 數量

2. **無應用層 Metrics**:
   - 錯誤率（6️⃣）、延遲（7️⃣）檢查標示為"資料不足"

### 未來改進方向

1. **整合 Prometheus**:
   - 添加 container_memory_working_set_bytes 查詢
   - 實現記憶體洩漏檢測（線性回歸）
   - CPU 使用率分析

2. **應用層 Metrics**:
   - 透過 Service Mesh 或應用自帶 metrics 獲取錯誤率
   - P95/P99 延遲統計

3. **智能告警**:
   - 建立 baseline
   - 異常檢測算法

4. **多集群支持**:
   - 支持檢查多個命名空間
   - 跨集群健康檢查

## 部署到 infra 目錄

按照用戶要求，K8s yaml 文件將複製到：

```
/Users/user/Waas2-project/gitlab.axiom-infra.com/waas2-tenant-k8s-deploy/infra/health-monitor/
```

並加入版控。

## 參考文檔

- [AGENTS.md](~/CLAUDE/AGENTS.md) - 工作流程規範
- [k8s-service-monitor.md](~/CLAUDE/docs/k8s-service-monitor.md) - 巡檢規則

## 工作日誌

詳見 [worklogs/WORKLOG-20251225-setup.md](worklogs/WORKLOG-20251225-setup.md)

---

**建立時間**: 2025-12-25
**維護者**: SRE Team
**Slack 通知頻道**: #sre-alerts
