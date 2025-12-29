---
ref: [AGENTS.md](~/CLAUDE/AGENTS.md)
status: ✅ v15 三環境已部署
created: 2025-12-26
updated: 2025-12-29
---

# WF-20251226 - PIGO K8s Health Monitor 自動化巡檢系統

## 任務目標

為 PIGO 環境建立自動化 Kubernetes 健康巡檢系統，每日定時檢查資源使用狀況並自動通知。

## 當前工作狀態

### v15 Image Version Display + Multi-Environment ✅ 已完成

**目標**:
1. 在 Deployment 狀態表格中顯示鏡像版本
2. 部署至所有三個環境 (pigo-dev, pigo-stg, pigo-rel)

**完成項目**:
- [x] 增加鏡像版本欄位到 Deployment 狀態表格
- [x] 建置 Docker image v15 並推送至 Harbor
- [x] 更新 GitHub 報告路徑格式 (使用 namespace 名稱)
- [x] 部署 pigo-dev 環境
- [x] 部署 pigo-stg 環境 (新增)
- [x] 部署 pigo-rel 環境 (新增)
- [x] 三環境測試驗證成功
- [x] 版控推送至各 GitLab repo

**v15 新功能**:
- Deployment 表格新增「鏡像版本」欄位
- 路徑格式: `pigo/{namespace}/YYYY/YYMMDD-k8s-health.md`

**部署狀態**:

| Environment | Namespace | GitHub Path | Status |
|-------------|-----------|-------------|--------|
| pigo-dev | pigo-dev | `pigo/pigo-dev` | ✅ 已部署 |
| pigo-stg | pigo-stg | `pigo/pigo-stg` | ✅ 已部署 |
| pigo-rel | pigo-rel | `pigo/pigo-rel` | ✅ 已部署 |

---

### v14 Path Format Update ✅ 已完成

**目標**: 更新 GitHub 報告路徑格式，使用 namespace 名稱而非編號代碼

**變更內容**:
- 舊格式: `pigo/1-dev/YYYY/YYMMDD-k8s-health.md`
- 新格式: `pigo/pigo-dev/YYYY/YYMMDD-k8s-health.md`

---

### v12 Enhanced Recommendations ✅ 已完成

**目標**: 改進異常報告的建議說明，提供更詳細的問題說明、影響分析與處理方式

**v12 建議說明格式**:
```
**問題說明**: CPU Throttling X% 表示該 Pod 有 X% 的時間因達到 CPU limit 而被限流

**影響**: 應用程式回應時間變長，CI/CD job 執行時間增加約 X%

**建議處理方式**:
1. 增加 CPU limits
2. 調整 requests/limits 比例
3. 評估 HPA
4. 效能分析
```

---

### v11 Prometheus Integration ✅ 已完成

**目標**: 整合 Prometheus 趨勢資料，完整實現 v10 Anti-False-Positive Decision Tree

**完成項目**:
- [x] 實作 prometheus_client.py
- [x] 更新 health-check-full.py (Prometheus 查詢整合)
- [x] 更新 report_generator.py (趨勢表格)
- [x] 更新 CronJob 配置 (PROMETHEUS_URL 環境變數)

**測試結果**:
- Prometheus 連接成功: 14 pods 取得趨勢資料
- 條件組 B (Throttling) 正確識別: `pigo-dev-gitlab-runner` throttling 39.2%
- 趨勢表格正確顯示: CPU 10m Avg, P95, Memory P95, Throttling

**關鍵資訊**:
- Prometheus: `http://monitoring-prometheus.monitoring.svc.cluster.local:9090`
- Docker Image: `pigo-harbor.axiom-gaming.tech/infra-devops/pigo-health-monitor:v12`
- 詳細規劃: [K8S-SERVICE-HEALTH-CHECK-2.md](K8S-SERVICE-HEALTH-CHECK-2.md) - v11 章節

---

## 專案位置

**主要部署目錄**: `/Users/user/PIGO-project/hkidc-k8s-gitlab/pigo-dev-k8s-deploy/monitor/monitor-cronjob/`

**參考規格文檔**: `/Users/user/CLAUDE/docs/k8s-service-monitor.md`

## 工作內容

### 1. 系統架構

#### 核心組件

- **CronJob**: 每日 09:00 (Asia/Taipei) 自動執行
- **健康檢查腳本**: Python 實作 (health-check.py)
- **報告生成器**: Markdown 格式報告 (report_generator.py)
- **Slack 通知**: 發送至 `pigo-dev-devops-alert` 頻道
- **GitHub 上傳**: 自動提交報告至 `dancyu-axiom-tw-devops/k8s-daily-monitor`

#### 檢查項目

1. **資源使用率分析**
   - Memory: 使用量 vs Request vs Limit
   - CPU: 使用量 vs Request vs Limit

2. **穩定性監控**
   - Pod 重啟次數
   - OOM (Out of Memory) 偵測

3. **配置驗證**
   - Resource Request/Limit 合理性
   - 使用率異常檢測

4. **健康閾值**
   - Memory High: > 80% of limit
   - Memory Low: < 50% of limit
   - CPU Low: < 20% of request
   - Restarts: > 0

### 2. 部署架構

#### 文件結構

```
monitor-cronjob/
├── README.md                          # 完整使用說明
├── deploy.sh                          # 部署腳本
├── destroy.sh                         # 刪除腳本
├── get-pods.sh                        # 查看 Pod 狀態
├── kustomization.yml                  # Kustomize 配置
├── cronjob.yml                        # CronJob 定義 (bash 版本)
├── cronjob-docker.yml                 # CronJob 定義 (Docker 版本)
├── cronjob-test.yml                   # 測試 Job
├── secret-slack-webhook.yaml          # Slack webhook secret
├── secret-github-app.yaml             # GitHub App 認證
├── secret-slack-webhook.yaml.template # Secret 模板
├── scripts/
│   └── health-check.sh                # Bash 健康檢查腳本
└── docker/
    ├── Dockerfile                     # Docker 映像定義
    ├── build-image.sh                 # 映像構建腳本
    ├── health-check.py                # Python 健康檢查分析器
    └── report_generator.py            # 報告生成模組
```

#### RBAC 權限

ServiceAccount: `k8s-health-check`
- `pods`: get, list
- `pods/log`: get
- `metrics.k8s.io/pods`: get, list

### 3. Slack 通知格式

```
[PIGO-DEV] Daily K8s Health Check

Summary
- Namespace: pigo-dev
- Pods checked: N
- Pods with issues: N
- Pods with restarts: N

Resource Review Required
- pod-name
  Status: Running/True
  Note: [工程化觀察]

Report: [GitHub URL]
```

**設計原則**:
- 工程分析風格，無 emoji
- 純文字格式，無表格
- 直接性建議

### 4. GitHub 報告結構

**Repository**: `dancyu-axiom-tw-devops/k8s-daily-monitor`

**路徑格式**: ~~`pigo/1-dev/YYYY/MM/DD/k8s-health.md`~~ (舊格式)

**新路徑格式** (2025-12-29 更新):
- `pigo/{namespace}/YYYY/YYMMDD-k8s-health.md`
- 範例: `pigo/pigo-dev/2025/251229-k8s-health.md`
- 變更: 使用 namespace 名稱，移除 MM/DD 子目錄，日期前綴加入檔名

**認證方式**: GitHub App (k8s-inspector)
- App ID: 2539631
- Private Key: 存於 `secret-github-app`
- Commit User: "PIGO K8s Health Check" <devops@axiom-gaming.tech>

**報告格式**: 參考 `/Users/user/MONITOR/k8s-daily-monitor/report-template.md`
- YAML frontmatter (metadata)
- 結構化章節: Summary, Metrics, Recommendations
- Raw data section (供自動化分析使用)

**⚠️ 注意**: 路徑格式變更需更新 Python 腳本和 Docker image (詳見 CHANGELOG.md)

### 5. 環境配置

#### 目標環境

| Environment | Namespace | GitHub Path | Cluster | Status |
|-------------|-----------|-------------|---------|--------|
| pigo-dev | pigo-dev | `pigo/pigo-dev` | tp-hkidc | ✅ 已部署 |
| pigo-stg | pigo-stg | `pigo/pigo-stg` | tp-hkidc | ✅ 已部署 |
| pigo-rel | pigo-rel | `pigo/pigo-rel` | tp-hkidc | ✅ 已部署 |

#### CronJob 配置

- **Schedule**: `0 1 * * *` (01:00 UTC = 09:00 Asia/Taipei)
- **Timezone**: Asia/Taipei
- **資源配置**:
  - CPU: Request 100m, Limit 200m
  - Memory: Request 128Mi, Limit 256Mi

## 部署步驟

### 前置準備

1. 確認 kubectl 已連線至 tp-hkidc-k8s 集群
2. 確認 Kustomize 已安裝
3. 配置 Slack webhook URL
4. 配置 GitHub App 認證

### 執行部署

```bash
cd /Users/user/PIGO-project/hkidc-k8s-gitlab/pigo-dev-k8s-deploy/monitor/monitor-cronjob
./deploy.sh
```

### 驗證部署

```bash
# 檢查 CronJob
kubectl get cronjob -n pigo-dev k8s-health-check

# 檢查 Pods
./get-pods.sh

# 查看日誌
kubectl logs -n pigo-dev -l app=k8s-health-check --tail=50
```

### 手動測試

```bash
# 方法 1: 從 CronJob 創建測試 Job
kubectl create job --from=cronjob/k8s-health-check manual-test-$(date +%s) -n pigo-dev

# 方法 2: 使用測試 Job
kubectl apply -f cronjob-test.yml
kubectl logs -n pigo-dev -l app=k8s-health-check-test --tail=100
```

### 刪除部署

```bash
./destroy.sh
```

## 開發歷程

### 設計階段

**需求分析**:
- 自動化日常 K8s 資源巡檢
- 減少人工檢查工作量
- 及時發現資源使用異常
- 工程化報告風格，無 emoji

**技術選型**:
- Python 3.11 (數據分析能力強)
- kubectl + metrics-server (數據來源)
- Slack webhook (即時通知)
- GitHub App (報告存檔)

### 實作階段

#### Version 1: Bash 實作 (cronjob.yml)

**特點**:
- 使用 kubectl 官方映像
- Bash 腳本直接執行
- ConfigMap 掛載腳本

**限制**:
- 數據處理能力有限
- 報告格式較簡單

#### Version 2: Docker + Python 實作 (cronjob-docker.yml)

**改進**:
- Python 進行數據分析
- 模組化設計 (health_check.py + report_generator.py)
- 更豐富的報告格式
- GitHub 自動上傳功能

**Docker Image**:
- Base: python:3.11-slim
- 包含: kubectl, PyGithub
- 標籤: asia-east2-docker.pkg.dev/uu-prod/waas-prod/pigo-health-monitor:latest

### 測試階段

**測試項目**:
1. ✅ CronJob 定時執行
2. ✅ metrics-server 數據讀取
3. ✅ Slack 通知發送
4. ✅ GitHub 報告上傳
5. ✅ RBAC 權限驗證
6. ✅ 資源使用率計算
7. ✅ 重啟次數偵測

**測試結果**: 所有功能正常運作

## 部署狀態

### PIGO-DEV 環境

- **部署日期**: 2025-12-26
- **集群**: tp-hkidc-k8s
- **Namespace**: pigo-dev
- **狀態**: ✅ 已成功部署並運行
- **CronJob**: k8s-health-check
- **Schedule**: 每日 09:00 (Asia/Taipei)
- **上次執行**: 檢查 CronJob 日誌
- **下次執行**: 依 CronJob schedule

### 擴展計劃

**待部署環境**:
1. PIGO Stage (pigo-stg)
   - 需更新 namespace: pigo-dev → pigo-stg
   - 需更新 GitHub path: 1-dev → 2-stg

2. PIGO Release (pigo-rel)
   - 需更新 namespace: pigo-dev → pigo-rel
   - 需更新 GitHub path: 1-dev → 3-rel

## 故障排查

### Job 執行失敗

```bash
# 檢查 Job 狀態
kubectl get jobs -n pigo-dev | grep k8s-health-check

# 查看日誌
kubectl logs -n pigo-dev job/k8s-health-check-<timestamp>

# 檢查事件
kubectl get events -n pigo-dev --sort-by='.lastTimestamp' | grep k8s-health-check
```

### Slack 通知未收到

```bash
# 驗證 Secret
kubectl get secret -n pigo-dev slack-webhook -o yaml

# 手動測試 webhook
curl -X POST <webhook-url> \
  -H 'Content-Type: application/json' \
  -d '{"text": "Test message"}'
```

### Metrics 無法讀取

```bash
# 檢查 metrics-server
kubectl top pods -n pigo-dev

# 如果不可用，metrics 會顯示 0
```

### GitHub 上傳失敗

```bash
# 檢查 GitHub App Secret
kubectl get secret -n pigo-dev github-app-k8s-inspector -o yaml

# 驗證 Private Key 格式
# 驗證 Repository 存取權限
```

## 文件清單

### 部署相關文件

| 文件 | 位置 | 用途 |
|------|------|------|
| README.md | monitor-cronjob/ | 完整使用說明 |
| cronjob-docker.yml | monitor-cronjob/ | 主要 CronJob 定義 (推薦使用) |
| cronjob.yml | monitor-cronjob/ | Bash 版本 CronJob |
| cronjob-test.yml | monitor-cronjob/ | 測試 Job |
| kustomization.yml | monitor-cronjob/ | Kustomize 配置 |
| deploy.sh | monitor-cronjob/ | 部署腳本 |
| destroy.sh | monitor-cronjob/ | 刪除腳本 |
| get-pods.sh | monitor-cronjob/ | 查看 Pod 狀態 |

### Secret 文件

| 文件 | 位置 | 內容 | Git 管理 |
|------|------|------|---------|
| secret-slack-webhook.yaml | monitor-cronjob/ | Slack webhook URL | ❌ 不提交 |
| secret-github-app.yaml | monitor-cronjob/ | GitHub App 私鑰 | ❌ 不提交 |
| secret-slack-webhook.yaml.template | monitor-cronjob/ | Secret 模板 | ✅ 可提交 |

### 程式碼文件

| 文件 | 位置 | 用途 |
|------|------|------|
| health-check.py | docker/ | Python 健康檢查分析器 |
| report_generator.py | docker/ | 報告生成模組 |
| Dockerfile | docker/ | Docker 映像定義 |
| build-image.sh | docker/ | 映像構建腳本 |
| health-check.sh | scripts/ | Bash 版本健康檢查 |

### 參考文檔

| 文件 | 位置 | 用途 |
|------|------|------|
| k8s-service-monitor.md | /Users/user/CLAUDE/docs/ | K8s 監控系統設計規格 |
| report-template.md | /Users/user/MONITOR/k8s-daily-monitor/ | GitHub 報告格式範本 |
| AGENTS.md | /Users/user/CLAUDE/ | 專案規範與標準 |

## 後續工作

### 短期計劃

1. **監控 PIGO-DEV 運行狀況** (1 週)
   - 驗證 CronJob 穩定性
   - 確認 Slack 通知準確性
   - 檢查 GitHub 報告完整性

2. **優化閾值設定** (依需求調整)
   - 根據實際運行數據調整警報閾值
   - 減少誤報率

### 中期計劃

3. **部署至 PIGO-STG 環境** (待需求確認)
   - 複製配置至 pigo-stg-k8s-deploy
   - 更新 namespace 和 GitHub path
   - 測試並驗證

4. **部署至 PIGO-REL 環境** (待需求確認)
   - 複製配置至 pigo-rel-k8s-deploy
   - 更新 namespace 和 GitHub path
   - 測試並驗證

### 長期改進

5. **增強分析能力**
   - 趨勢分析 (記憶體成長率)
   - 異常偵測 (突發性資源使用)
   - 容量規劃建議

6. **整合更多數據源**
   - Application logs 分析
   - Error rate 監控
   - Latency 監控

## 關鍵命令參考

### 日常維護

```bash
# 切換至 PIGO 線下集群
tp-hkidc

# 查看 CronJob 狀態
kubectl get cronjob -n pigo-dev k8s-health-check

# 查看最近執行的 Job
kubectl get jobs -n pigo-dev -l app=k8s-health-check --sort-by=.metadata.creationTimestamp

# 查看最新日誌
kubectl logs -n pigo-dev -l app=k8s-health-check --tail=100

# 手動觸發執行
kubectl create job --from=cronjob/k8s-health-check manual-$(date +%s) -n pigo-dev
```

### 更新部署

```bash
# 修改配置後重新部署
cd /Users/user/PIGO-project/hkidc-k8s-gitlab/pigo-dev-k8s-deploy/monitor/monitor-cronjob
kubectl apply -k .

# 或使用部署腳本
./deploy.sh
```

### 緊急停用

```bash
# 暫停 CronJob
kubectl patch cronjob k8s-health-check -n pigo-dev -p '{"spec":{"suspend":true}}'

# 恢復 CronJob
kubectl patch cronjob k8s-health-check -n pigo-dev -p '{"spec":{"suspend":false}}'

# 完全刪除
./destroy.sh
```

## 安全注意事項

1. **Secret 管理**
   - ⚠️ 絕不提交 secret-slack-webhook.yaml 至 Git
   - ⚠️ 絕不提交 secret-github-app.yaml 至 Git
   - ✅ 僅提交 .template 文件
   - ✅ Secret 應存於安全的憑證管理系統

2. **RBAC 權限**
   - ServiceAccount 僅授予必要的最小權限
   - 定期審查權限範圍

3. **GitHub App**
   - Private Key 妥善保管
   - 定期輪換認證金鑰
   - 限制 Repository 存取範圍

4. **Slack Webhook**
   - Webhook URL 視為敏感資訊
   - 定期更新 webhook
   - 監控異常通知活動

## 專案總結

### 達成目標

✅ **自動化巡檢**: 每日自動執行，無需人工介入
✅ **即時通知**: Slack 即時推送異常警報
✅ **完整報告**: GitHub 自動存檔，可追溯歷史
✅ **工程風格**: 直接、無 emoji、專業分析
✅ **資源效率**: 輕量化設計，資源使用最小化

### 技術亮點

- **模組化設計**: Python 模組清晰分離
- **容器化部署**: Docker 映像，環境一致性
- **多重通知**: Slack + GitHub 雙重保障
- **自動認證**: GitHub App 無需個人 Token
- **靈活擴展**: 易於複製至其他環境

### 維護建議

- 定期檢查 CronJob 執行狀況
- 監控 Slack 通知是否正常
- 驗證 GitHub 報告上傳完整性
- 根據實際需求調整閾值
- 保持 Docker 映像更新

---

**工作流程狀態**: ✅ 已完成
**部署狀態**: ✅ 三環境 (pigo-dev, pigo-stg, pigo-rel) 已部署並運行
**Docker Image**: v15
**最後更新**: 2025-12-29
**維護者**: PIGO DevOps Team

---

## 快速索引

**部署目錄**:
- **pigo-dev**: `/Users/user/PIGO-project/hkidc-k8s-gitlab/pigo-dev-k8s-deploy/monitor/monitor-cronjob/`
- **pigo-stg**: `/Users/user/PIGO-project/hkidc-k8s-gitlab/pigo-stage-k8s-deploy/monitor/monitor-cronjob/`
- **pigo-rel**: `/Users/user/PIGO-project/hkidc-k8s-gitlab/pigo-rel-k8s-deploy/monitor/monitor-cronjob/`

**核心文件**:
- **健康檢查主程式**: `docker/health-check-full.py`
- **報告生成器**: `docker/report_generator.py`
- **Prometheus 客戶端**: `docker/prometheus_client.py`

**Secrets 位置** (不納入版控):
- `/Users/user/CLAUDE/credentials/pigo-dev-health-monitor/`
- `/Users/user/CLAUDE/credentials/pigo-stg-health-monitor/`
- `/Users/user/CLAUDE/credentials/pigo-rel-health-monitor/`

**GitHub 報告**:
- Repository: `dancyu-axiom-tw-devops/k8s-daily-monitor`
- 路徑格式: `pigo/{namespace}/YYYY/YYMMDD-k8s-health.md`
