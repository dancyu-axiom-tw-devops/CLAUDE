# Waas2 Health Monitor 實施日誌

**日期**: 2025-12-25
**任務**: 建立 Waas2 Tenant 服務每日健康檢查系統

## 任務背景

用戶要求：
```
參照 @~/CLAUDE/AGENTS.md 工作規則
遵行 @CLAUDE/docs/k8s-service-monitor.md 針對/Users/user/Waas2-project/gitlab.axiom-infra.com/waas2-tenant-k8s-deploy 部署的服務製作每日監控放在k8s裡面排程。

監控結果 發到 slack webhook https://hooks.slack.com/services/YOUR_WEBHOOK_URLoIcwzw1I4l8yOb9VILrSZNhA

排程工作k8s腳本放到 /Users/user/Waas2-project/gitlab.axiom-infra.com/waas2-tenant-k8s-deploy/infra 目錄下 入版控，k8s yaml 生成比照 其他k8s 服務yaml格式
```

## 實施步驟

### 1. 服務發現 ✅

掃描 waas2-tenant-k8s-deploy 目錄，發現：

**業務服務** (11個):
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

**基礎設施** (不監控):
- nacos
- xxl-job
- nginx
- kafka-ui
- waas2-log-sls

### 2. 參考現有 yaml 格式 ✅

檢查了以下文件作為參考：
- `/Users/user/Waas2-project/gitlab.axiom-infra.com/waas2-tenant-k8s-deploy/infra/nas-fixer/nas-fixer-pod.yml`
- `/Users/user/Waas2-project/gitlab.axiom-infra.com/waas2-tenant-k8s-deploy/service-admin/service-admin.yml`
- `/Users/user/Waas2-project/gitlab.axiom-infra.com/waas2-tenant-k8s-deploy/service-admin/kustomization.yml`

**發現的模式**:
- Namespace: waas2-prod
- NodeSelector: role: apps
- ImagePullSecrets: gcp-pull-secret
- PVC: alibabacloud-cnfs-nas storage class
- SecurityContext: runAsUser: 1000, runAsNonRoot: true

### 3. 實作健康檢查腳本 ✅

**文件**: `scripts/health-check.py`

**功能**:
- 8 項巡檢（按照 k8s-service-monitor.md）
- 整體狀態判定規則
- Slack 通知整合
- Markdown 報告生成

**技術決策**:
- 語言: Python 3.11（便於數據處理）
- 依賴: 僅使用標準庫（kubectl, urllib, json）
- 報告格式: Markdown（Slack 友好）

**限制**:
- 無 Prometheus → 記憶體/CPU metrics 標示為"資料不足"（⚪）
- 無應用 metrics → 錯誤率/延遲 標示為"資料不足"（⚪）
- 僅檢查：可用性、穩定性、Pod 數量

### 4. 建立 Kubernetes 資源 ✅

**文件**: `deployment/cronjob.yml`

**包含資源**:
```yaml
- ServiceAccount: waas2-health-monitor
- Role: 讀取 pods, events, services, deployments
- RoleBinding
- PVC: waas2-health-reports (1Gi, NAS)
- CronJob: 每日 01:00 UTC (09:00 UTC+8)
```

**Docker 鏡像**:
- 名稱: asia-east2-docker.pkg.dev/uu-prod/waas-prod/waas2-health-monitor:latest
- 基礎: python:3.11-slim
- 工具: kubectl

**資源配置**:
```yaml
requests:
  cpu: 100m
  memory: 128Mi
limits:
  cpu: 200m
  memory: 256Mi
```

### 5. Slack 整合 ✅

**Webhook URL**: https://hooks.slack.com/services/YOUR_WEBHOOK_URLoIcwzw1I4l8yOb9VILrSZNhA

**通知格式** (按照 k8s-service-monitor.md 第七節):
- 🔴 服務清單（詳細）
- 🟡 服務數量
- Top 3 問題

**實作**:
- 使用 Secret 存儲 webhook URL
- Python urllib 發送 POST 請求
- 錯誤處理與重試

### 6. 工作流程結構 ✅

按照 AGENTS.md 規範：

```
WF-20251225-waas2-health-monitor/
├── README.md
├── scripts/
│   └── health-check.py
├── deployment/
│   ├── Dockerfile
│   ├── cronjob.yml
│   ├── secret-template.yml
│   ├── build-image.sh
│   └── deploy.sh
├── data/
│   ├── services.txt
│   └── reports/
├── worklogs/
│   └── WORKLOG-20251225-setup.md
```

## 技術挑戰與解決

### 挑戰 1: 無 Prometheus 可用

**問題**: k8s-service-monitor.md 要求檢查記憶體/CPU 使用，但 waas2-prod 可能沒有 Prometheus。

**解決**:
- 按照規則第 4 條："無資料時標示為 Insufficient Data，不得猜測"
- 使用 ⚪ 符號標示
- 整體狀態判定時，若關鍵項目資料不足 → 整體 🟡

### 挑戰 2: 匹配現有 yaml 格式

**問題**: 需要比照其他 K8s 服務 yaml 格式。

**解決**:
- 參考 service-admin.yml 和 nas-fixer-pod.yml
- 使用相同的 securityContext 設定
- 使用相同的 nodeSelector (role: apps)
- 使用相同的 imagePullSecrets

### 挑戰 3: 報告存儲

**問題**: 報告要存在哪裡？

**解決**:
- 創建專用 PVC: waas2-health-reports
- StorageClass: alibabacloud-cnfs-nas (NAS，支持 ReadWriteMany)
- 大小: 1Gi（足夠存儲數月報告）

## 部署計畫

### 階段 1: 測試環境驗證 (待執行)

```bash
# 1. 構建鏡像
cd deployment
./build-image.sh latest
docker push asia-east2-docker.pkg.dev/uu-prod/waas-prod/waas2-health-monitor:latest

# 2. 部署
./deploy.sh

# 3. 手動觸發測試
kubectl create job --from=cronjob/waas2-health-monitor manual-test-$(date +%s) -n waas2-prod

# 4. 查看日誌
kubectl logs -f job/manual-test-xxx -n waas2-prod
```

### 階段 2: 複製到 infra 目錄 (待執行)

```bash
# 複製 K8s yaml 到 infra 目錄
cp -r deployment /Users/user/Waas2-project/gitlab.axiom-infra.com/waas2-tenant-k8s-deploy/infra/health-monitor

# 加入版控
cd /Users/user/Waas2-project/gitlab.axiom-infra.com/waas2-tenant-k8s-deploy
git-tp add infra/health-monitor
git-tp commit -m "Add Waas2 tenant health monitoring CronJob"
git-tp push
```

### 階段 3: 正式執行 (待執行)

- 驗證每日 09:00 UTC+8 自動執行
- 確認 Slack 通知正常
- 檢查報告存檔

## 成功標準

- [x] 健康檢查腳本實作完成
- [x] CronJob yaml 建立
- [x] Slack 通知整合
- [x] Docker 鏡像定義
- [x] 部署腳本建立
- [ ] 鏡像構建並推送
- [ ] 部署到 waas2-prod 測試
- [ ] 手動觸發驗證
- [ ] 複製到 infra 目錄
- [ ] 加入版控

## 下一步

1. **構建與推送 Docker 鏡像**
2. **部署到 waas2-prod 測試**
3. **手動觸發驗證功能**
4. **確認 Slack 通知**
5. **複製到 infra 目錄並入版控**

## 備註

### Prometheus 整合（未來改進）

如果未來有 Prometheus 可用，可以擴展以下檢查：

**3️⃣ 記憶體使用**:
```python
container_memory_working_set_bytes{namespace="waas2-prod"}
```

**4️⃣ 記憶體趨勢**:
```python
# 線性回歸檢測記憶體洩漏
from scipy import stats
slope, intercept, r_value, p_value, std_err = stats.linregress(timestamps, memory_values)
```

**5️⃣ CPU 使用**:
```python
rate(container_cpu_usage_seconds_total{namespace="waas2-prod"}[5m])
```

### 應用層 Metrics（未來改進）

需要應用暴露 metrics endpoint：

**6️⃣ 錯誤率**:
```
http_requests_total{status=~"5.."}
```

**7️⃣ 延遲**:
```
histogram_quantile(0.95, http_request_duration_seconds)
```

---

**完成時間**: 2025-12-25
**耗時**: 約 1 小時
**狀態**: 開發完成，待部署測試
