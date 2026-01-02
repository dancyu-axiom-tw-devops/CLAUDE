# K8s Daily Monitor Handler - CHANGELOG

## 2026-01-02

### WAAS2-PROD: ilogtail exec format error 修復

**問題**: `ilogtail-ds` pod 持續 CrashLoopBackOff，錯誤訊息 `exec format error`

**根因**: GCP registry 中的 `ilogtail:2.0.7` 是 **arm64** 架構，但 K8s 節點是 **amd64**

**解決方案**:
1. 從阿里雲官方 registry pull amd64 版本
2. 推送到 GCP registry 並標記為 `2.0.7-amd64`
3. 更新 kustomization.yml 使用正確的 tag

**修改文件**:
- `/Users/user/Waas2-project/gitlab.axiom-infra.com/waas2-tenant-k8s-deploy/waas2-log-sls/kustomization.yml`
  - `newTag: '2.0.7'` → `newTag: '2.0.7-amd64'`

**部署**: ✅ ilogtail-ds 已恢復 Running

---

### Health Monitor v25: Pod 狀態與 Runner Throttling 修正

**問題 1**: Slack 通知顯示 `Pods: 🚨 4/6 Running (2 個未 Running)`，但 2 個 pods 是已完成的 Job pods (Completed 狀態)

**問題 2**: `prod-waas2-tenant-runner-gitlab-runner` Runner throttling 11.9% 被誤報為 Critical，但 Runner 類型應該使用 20% 閾值

**解決方案**:
1. 排除 Completed/Succeeded 狀態的 Job pods，不計入「未 Running」的警示
2. 修正 Runner/Batch 類型的 throttling 判斷邏輯，throttling <= 20% 時完全不報警

**修改文件**:
- `/Users/user/MONITOR/k8s-health-monitor/src/health-check-full.py`
  - `check_pod_health()`: 新增 `total_completed` 計數，Succeeded/Completed pods 標記為 healthy
  - Slack 通知: 使用 `active_total = total - completed` 計算應該 Running 的 pods 數量
  - Runner throttling: 重構條件邏輯，`if is_runner:` 優先判斷，throttling <= 20% 完全不觸發警告
- `/Users/user/MONITOR/k8s-health-monitor/VERSION` - v24 → v25

**部署**: ✅ v25 鏡像已推送到所有 registries

**Slack 顯示邏輯**:
- 有 Completed pods: `✅ 4/4 Running (+2 Completed)`
- 有問題 pods + Completed pods: `🚨 3/4 Running (1 個未 Running) +2 Completed`

---

### Health Monitor v24: Skip TLS Check 功能

**問題**: waas2-sensitive-prod 報告顯示「無 TLS 憑證」警告，但這是內部 namespace 的預期行為

**解決方案**: 新增 `SKIP_TLS_CHECK` 環境變數，讓各 CronJob 可自行配置是否跳過 TLS 檢查

**修改文件**:
- `/Users/user/MONITOR/k8s-health-monitor/src/health-check-full.py` - 支援 SKIP_TLS_CHECK 環境變數
- `/Users/user/MONITOR/k8s-health-monitor/src/report_generator.py` - 顯示「N/A (內部 namespace，已跳過檢查)」
- `/Users/user/MONITOR/k8s-health-monitor/VERSION` - v23 → v24
- `/Users/user/MONITOR/k8s-health-monitor/build-and-push.sh` - 新增 WAAS GCP registry

**部署**:
- ✅ v24 鏡像已推送到所有 registries
- ✅ waas2-sensitive-prod CronJob: 添加 `SKIP_TLS_CHECK=true`，更新鏡像到 v24
- ✅ waas2-prod CronJob: 更新鏡像到 v24

**使用方式**: 在 CronJob 的 env 中添加 `SKIP_TLS_CHECK=true` 即可跳過 TLS 檢查

---

### JC-PROD: registercenter OOMKill 修復

**問題**: registercenter-0 OOMKill (exit code 137)

**根因分析**:
- JVM Heap: `-Xms1024m -Xmx1024m` (1024MB)
- Container Memory Limit: 1280Mi
- 非 Heap 可用空間: 僅 256Mi (不足以容納 Metaspace、Native Memory 等)

**修正**:
| 項目 | 舊值 | 新值 |
|------|------|------|
| Memory Limit | 1280Mi | 1536Mi |
| 非 Heap 可用空間 | 256Mi | 512Mi |

**修改文件**:
- `/Users/user/JUANCASH-project/github/juancash-prod-k8s-deploy/jc-refactor/app-service/registercenter/registercenter.yml`

**部署**: 使用 kustomize 滾動更新 3 個 StatefulSet pods

### FOREX-PROD: 移除無效 DNS 記錄

**問題**: forex-ui 和 powercard 域名有 DNS 解析但無對應 nginx vhost，落入 default_server

**分析**:
| 域名 | 訪問次數 | DNS 狀態 | Nginx vhost |
|------|---------|----------|-------------|
| forex-ui.uuwallet.com | 20,593 | ✅ 有解析 | ❌ 無配置 |
| powercard.uuwallet.com | 3,570 | ✅ 有解析 | ❌ 無配置 |

**修正**: 註解這些 DNS 記錄

**修改文件**:
- `/Users/user/FOREX-project/hkidc-k8s-gitlab/dns-recored-uu-domain/record_list/uuwallet.com.yaml`
- `/Users/user/FOREX-project/hkidc-k8s-gitlab/dns-recored-uu-domain/record_list/uuwallet.ph.yaml`

### Error Logs 分析

**JC-PROD** (12,758 errors/24h):
- 來源: APM Server 8.9.0 (ECK Operator 部署)
- 錯誤: `precondition 'apm integration installed' failed`
- 根因: Elasticsearch 缺少 APM integration index templates (`metrics-apm.service_summary.60m`, `traces-apm`)
- 解法選項: (1) 部署 Kibana 透過 Fleet 安裝 integration (2) 手動透過 ES API 安裝 templates (3) Scale down APM
- 結論: APM 功能仍需使用，暫不處理，待後續評估是否部署 Kibana

**FOREX-PROD** (523 errors/24h):
- 來源: forex-nginx
- 錯誤: 404 Not Found (掃描攻擊)
- 結論: 正常安全行為，無需處理

### PIGO-PROD: Runner CPU Throttling 修復

**問題**: pigo-prod-k8s-service-runner throttling 27.5% (> 20% 閾值)

**修正**:
| 項目 | 舊值 | 新值 |
|------|------|------|
| CPU Limit | 500m | 1000m |

**修改文件**:
- `/Users/user/K8S/k8s-devops/helm/gitlab-runner/pigo-prod-k8s-service-runner/values.yaml`

**部署**: `helm upgrade -n pigo-prod pigo-prod-k8s-service-runner gitlab/gitlab-runner -f values.yaml --set runnerToken="<token>"`

### Profile 更新

為各專案 Profile 添加 GitLab Runner 腳本路徑：
- `/Users/user/CLAUDE/profiles/pigo.md`
- `/Users/user/CLAUDE/profiles/forex.md`
- `/Users/user/CLAUDE/profiles/waas.md`
- `/Users/user/CLAUDE/profiles/jc.md`

新增內容：`**GitLab Runner 腳本**: /Users/user/K8S/k8s-devops/helm/gitlab-runner`

### PIGO-DEV: Pod 失敗調查

**用戶報告**: agent-system, game-api (3 pods) Failed

**調查結果**:
| Pod | 目前狀態 | 重啟時間 | 節點 |
|-----|---------|---------|------|
| agent-system-9c6b5446-jrkd5 | ✅ Running | 2026-01-01 16:02 | node05 |
| game-api-7dc7647dc6-stv59 | ✅ Running | 2026-01-01 16:02 | node02 |
| pigo-cron-77cc9c4d8c-jgn2x | ✅ Running | 2026-01-01 16:02 | node04 |

**分析**:
- 三個 pod 在不同節點上同時重啟 (11h ago)
- 節點狀態正常，無 MemoryPressure/DiskPressure
- K8s events 已過期無法追溯
- 用戶報告的 pod 名稱與目前運行的不同 (舊 pod 已被替換)

**結論**: Pod 已自動恢復，無需處理。可能是 deployment 更新或臨時性問題。

### 待處理 (未執行)

| 環境 | 問題 | 說明 |
|------|------|------|
| forex-prod | jcard-service throttling 13.9% | < 20% Runner 閾值 |
| forex-prod | runner throttling 16.1% | < 20% Runner 閾值 |
| waas2-prod | runner throttling 11.9% | < 20% Runner 閾值 |

---

## 2025-12-31

### CPU Throttling 問題處理

根據 k8s-daily-monitor 健康檢查報告，處理了以下 CPU Throttling 問題：

#### PIGO 專案

| 服務 | 環境 | Throttling | 調整內容 |
|-----|------|-----------|---------|
| pigo-rel-gitlab-runner | rel | 42.2% | CPU limit: 200m → 500m |
| pigo-prod-k8s-service-runner | prod | 19.7% | CPU limit: 200m → 500m |

**修改文件**:
- `/Users/user/K8S/k8s-devops/helm/gitlab-runner/waas-rel-k8s-service-runner01-pigo-rel/values.yaml`
- `/Users/user/K8S/k8s-devops/helm/gitlab-runner/pigo-prod-k8s-service-runner/values.yaml`

#### FOREX 專案

| 服務 | 環境 | Throttling | 調整內容 |
|-----|------|-----------|---------|
| jcard-service | prod | 23.1% | CPU limit: 3000m → 4000m |
| jcard-service | rel | 11.3% | CPU limit: 2000m → 3000m |

**修改文件**:
- `/Users/user/FOREX-project/gitlab.axiom-infra.com/forex-prod-k8s-deploy/jcard-service/deployment.yml`
- `/Users/user/FOREX-project/hkidc-k8s-gitlab/forex-rel/forex-rel-k8s-deploy/jcard-service/deployment.yml`

#### WAAS 專案

| 服務 | 環境 | Throttling | 調整內容 |
|-----|------|-----------|---------|
| waas-rel-gitlab-runner | rel | 39.5% | CPU limit: 200m → 500m |
| service-user | rel | 22.7% | CPU limit: 400m → 800m |
| service-notice | rel | 14.3% | CPU limit: 400m → 800m |

**修改文件**:
- `/Users/user/K8S/k8s-devops/helm/gitlab-runner/waas-rel-k8s-service-runner01/values.yaml`
- `/Users/user/Waas2-project/hkidc-k8s-gitlab/waas2-rel-k8s-deploy/service-user/service-user.yml`
- `/Users/user/Waas2-project/hkidc-k8s-gitlab/waas2-rel-k8s-deploy/service-notice/service-notice.yml`

### Profile 更新

為各專案 Profile 添加了集群管理者腳本 (k8s-devops) 資訊：

- `/Users/user/CLAUDE/profiles/pigo.md`
- `/Users/user/CLAUDE/profiles/waas.md`
- `/Users/user/CLAUDE/profiles/forex.md`

新增內容包括：
- k8s-devops 路徑: `/Users/user/K8S/k8s-devops`
- 各專案相關的 GitLab Runner 配置路徑
- 常用管理指令

### GitLab Runner 配置變更技巧

**說明**: GitLab Runner 使用 token 進行身份驗證，token 從 GitLab 管理介面取得

**部署流程**:

```bash
# 方式一：使用 gitlab-runner.sh 腳本 (需要對應環境的 token 環境變數)
cd /Users/user/K8S/k8s-devops/helm/gitlab-runner
./gitlab-runner.sh <env-name>

# 方式二：手動 helm upgrade (已有 secret 存在時)
# 1. 從現有 secret 取得 token
kubectl -n <namespace> get secret <secret-name>-gitlab-runner -o jsonpath='{.data.runner-token}' | base64 -d

# 2. 執行 helm upgrade
helm upgrade -n <namespace> --install <release-name> gitlab/gitlab-runner \
  -f <values-path>/values.yaml \
  --set runnerToken="<token>"
```

**values.yaml 中的關鍵設定**:
- `runners.secret`: 指定存儲 token 的 secret 名稱
- `resources.limits.cpu`: Runner Pod 本身的 CPU 限制 (本次調整目標)
- `runners.config.[runners.kubernetes.resources]`: 執行 Job 的 Pod 資源限制

**本次部署結果**:
- ✅ pigo-prod-k8s-service-runner (已成功部署)
- ⚠️ pigo-rel, waas-rel (需集群管理員權限)

**注意事項**:
- 線下環境 (hkidc-k8s) 需要具有 RBAC 權限的帳號執行
- prod 環境的 runner 在獨立集群中，需切換 context

### k8s-health-monitor 版本修正

**問題**: 報告顯示 v21，但 CronJob 鏡像 tag 是 v23

**根因**:
1. `report_generator.py` 中的版本號是 hardcode
2. CronJob 的 `imagePullPolicy: IfNotPresent` 導致不拉取新鏡像

**修正**:
1. 新增 `VERSION` 文件，程式動態讀取版本號
2. 修改 `report_generator.py` 從 VERSION 文件讀取版本
3. 修改 `Dockerfile` 複製 VERSION 文件
4. 修改 `build-and-push.sh` 從 VERSION 文件讀取版本
5. 重新 build 並推送 v23 鏡像到所有 registry
6. 更新 pigo-dev CronJob 的 `imagePullPolicy` 為 `Always`

**驗證**:
- ✅ pigo-dev 報告已顯示 `v23`

**提醒**: 其他環境的 CronJob 也需要更新 `imagePullPolicy: Always`

### CronJob imagePullPolicy 更新

已更新所有環境的 CronJob `imagePullPolicy` 為 `Always`：

**hkidc-k8s 集群**:
- ✅ pigo-dev, pigo-stg, pigo-rel
- ✅ forex-stg, forex-rel
- ✅ waas-dev, waas-rel, waas-sensitive-rel

**prod 集群**:
- ✅ pigo-prod
- ✅ forex-prod
- ✅ waas2-prod, waas2-sensitive-prod

### 鏡像推送

v23 已推送到所有 registry：
- ✅ pigo-harbor.axiom-gaming.tech/infra-devops/pigo-health-monitor:v23
- ✅ waas-harbor.axiom-gaming.tech/infra-devops/waas-health-monitor:v23
- ✅ harbor.innotech-stage.com/forex-infra/forex-health-monitor:v23
- ✅ registry.juancash.com/infra-devops/jc-health-monitor:v23

### 待辦事項

- [x] k8s-health-monitor 版本修正並推送
- [x] 更新各環境 CronJob imagePullPolicy
- [x] Git commit 並推送各專案的修改 (k8s-devops, WAAS)
- [ ] 監控調整後的效果
- [ ] 審視精簡資源 (識別過度配置的服務，優化資源使用)
