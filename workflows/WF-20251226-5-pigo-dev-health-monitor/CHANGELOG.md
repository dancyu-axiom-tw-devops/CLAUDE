# Changelog - PIGO-DEV Health Monitor

## 2025-12-26 - Configuration Update

### Problem
用戶反饋 monitor-cronjob 產生一堆 failed pods，需要確保：
1. 一次只產生一個 pod
2. 執行完後自然消失
3. 不累積大量 pods

### Root Cause Analysis
1. **手動測試 Job 累積**: 手動創建的測試 Job 不受 CronJob history limit 控制
2. **TTL 過長**: 原設定 `ttlSecondsAfterFinished: 86400` (24小時) 導致 pods 保留過久
3. **History limit 過大**: 原設定保留 3 個成功和 3 個失敗 Job

### Solution Applied

#### 配置變更

**Before** (`cronjob-docker.yml`):
```yaml
successfulJobsHistoryLimit: 3
failedJobsHistoryLimit: 3
ttlSecondsAfterFinished: 86400  # 24 hours
```

**After**:
```yaml
successfulJobsHistoryLimit: 1  # Keep only 1 successful job
failedJobsHistoryLimit: 1      # Keep only 1 failed job
ttlSecondsAfterFinished: 3600  # Auto-delete after 1 hour
backoffLimit: 0  # No retry on failure
concurrencyPolicy: Forbid  # Only one job at a time (unchanged)
restartPolicy: Never  # (unchanged)
```

#### 新增配置

- **`backoffLimit: 0`**: 失敗不重試，避免產生多個 pod
- **縮短 TTL**: 1 小時後自動刪除，而非 24 小時
- **減少 history**: 只保留 1 個成功/失敗 Job，而非 3 個

### Validation

1. **清理舊 Job**:
   ```bash
   kubectl delete job manual-test-1766732396 manual-test-1766732530 \
                      manual-test-1766732639 manual-test-1766744319 -n pigo-dev
   ```

2. **測試新配置**:
   ```bash
   kubectl create job --from=cronjob/k8s-health-check test-final-$(date +%s) -n pigo-dev
   ```

   結果:
   - ✅ Pod 正常執行完成
   - ✅ Status: Completed (0 restarts)
   - ✅ TTL 設定: 3600 秒
   - ✅ backoffLimit: 0

3. **驗證 CronJob 配置**:
   ```bash
   kubectl get cronjob k8s-health-check -n pigo-dev -o yaml
   ```

   確認:
   - ✅ successfulJobsHistoryLimit: 1
   - ✅ failedJobsHistoryLimit: 1
   - ✅ concurrencyPolicy: Forbid
   - ✅ ttlSecondsAfterFinished: 3600
   - ✅ backoffLimit: 0

### Pod Lifecycle

**正常執行流程**:
1. CronJob 在排程時間 (每日 09:00) 自動創建 Job
2. Job 創建 1 個 Pod 執行健康檢查
3. Pod 執行完成 (約 30-60 秒)
4. Pod 狀態變為 Completed
5. **1 小時後** Pod 自動刪除 (TTL controller)
6. **下次排程時** 舊的 Job 被刪除 (只保留 1 個)

**結果**: 不會累積 pods，最多同時存在 1-2 個 Job/Pod

### Files Modified

1. **`/Users/user/PIGO-project/hkidc-k8s-gitlab/pigo-dev-k8s-deploy/monitor/monitor-cronjob/cronjob-docker.yml`**
   - Updated CronJob spec (lines 176-183)
   - Backed up to `cronjob-docker.yml.backup`

2. **`/Users/user/PIGO-project/hkidc-k8s-gitlab/pigo-dev-k8s-deploy/monitor/monitor-cronjob/README.md`**
   - Added "Pod Cleanup Policy" section
   - Documented automatic cleanup behavior

3. **`/Users/user/CLAUDE/workflows/WF-20251226-5-pigo-dev-health-monitor/CHANGELOG.md`**
   - Created this changelog

### Deployment

```bash
cd /Users/user/PIGO-project/hkidc-k8s-gitlab/pigo-dev-k8s-deploy/monitor/monitor-cronjob
kubectl apply -f cronjob-docker.yml
```

Output:
```
serviceaccount/k8s-health-check unchanged
role.rbac.authorization.k8s.io/k8s-health-check unchanged
rolebinding.rbac.authorization.k8s.io/k8s-health-check unchanged
configmap/health-check-upload-script unchanged
cronjob.batch/k8s-health-check configured
```

### Monitoring

檢查 Pod 清理狀況:
```bash
# 查看當前 pods (應該最多 1-2 個)
kubectl get pods -n pigo-dev -l app=k8s-health-check

# 查看 jobs (應該最多 1 個成功 + 1 個失敗)
kubectl get jobs -n pigo-dev | grep k8s-health-check

# 查看 CronJob 狀態
kubectl get cronjob k8s-health-check -n pigo-dev
```

### Best Practices

**手動測試時**:
- 測試完後手動刪除 Job: `kubectl delete job <job-name> -n pigo-dev`
- 或使用 TTL: Job 會在 1 小時後自動刪除

**避免累積 pods**:
- ✅ 不要在 CronJob 中設定 `suspend: true` 然後忘記恢復
- ✅ 定期檢查殘留的手動測試 Job
- ✅ 失敗的 Job 會保留 1 個供調查，調查完即可手動刪除

---

**Updated**: 2025-12-26 18:30
**Status**: ✅ Deployed and Verified

## 2025-12-26 - Directory Cleanup & Secret Management

### Changes

清理 monitor-cronjob 目錄，移除不需要的文件，並將 secret 文件移到 workflow 目錄。

#### Files Removed

1. **Backup files**:
   - `cronjob-docker.yml.backup`
   - `cronjob-docker-fixed.yml`

2. **Obsolete CronJob files**:
   - `cronjob.yml` (bash version - replaced by Docker version)
   - `cronjob-test.yml` (test job - can be created on-demand)

3. **Bash scripts directory**:
   - `scripts/health-check.sh` (replaced by Python in Docker image)

#### Files Moved to Workflow

**Secret files** (MUST NOT be committed to Git):
- `secret-slack-webhook.yaml` → `/Users/user/CLAUDE/workflows/WF-20251226-5-pigo-dev-health-monitor/`
- `secret-github-app.yaml` → `/Users/user/CLAUDE/workflows/WF-20251226-5-pigo-dev-health-monitor/`

#### Files Added

1. **`.gitignore`**: Prevent secret files from being committed
   ```gitignore
   # Secret files - DO NOT commit
   secret-slack-webhook.yaml
   secret-github-app.yaml
   
   # Backup files
   *.backup
   *-fixed.yml
   *-old.yml
   
   # Test files
   cronjob-test.yml
   ```

#### Files Retained

**Essential files only**:
```
monitor-cronjob/
├── .gitignore                         # Ignore secret files
├── README.md                          # Updated with secret instructions
├── cronjob-docker.yml                 # Main CronJob definition
├── deploy.sh                          # Deployment script
├── destroy.sh                         # Cleanup script
├── get-pods.sh                        # Status check script
├── kustomization.yml                  # Kustomize config
├── secret-slack-webhook.yaml.template # Secret template
└── docker/                            # Docker image files
    ├── Dockerfile
    ├── build-image.sh
    ├── health-check.py
    └── report_generator.py
```

#### README.md Updates

Added **Secrets Configuration** section:
- Instructions to copy secrets from workflow directory
- Warning about NOT committing secrets to Git
- Alternative: Create from template

### Rationale

1. **Security**: Secret files should NOT be in Git repositories
2. **Clarity**: Keep only essential files in deployment directory
3. **Maintainability**: Single source of truth (Docker version)
4. **Best Practice**: Use `.gitignore` to prevent accidental commits

### Deployment Impact

**No impact** - Secrets are already deployed to cluster:
```bash
# Verify secrets exist
kubectl get secret slack-webhook -n pigo-dev
kubectl get secret github-app -n pigo-dev
```

If secrets need to be redeployed:
```bash
# Copy from workflow
cp /Users/user/CLAUDE/credentials/pigo-dev-health-monitor/secret-*.yaml .

# Apply to cluster
kubectl apply -f secret-slack-webhook.yaml
kubectl apply -f secret-github-app.yaml

# Remove local copies (they're in .gitignore anyway)
rm secret-slack-webhook.yaml secret-github-app.yaml
```

---

**Updated**: 2025-12-26 18:33
**Status**: ✅ Completed

## 2025-12-26 - GitHub Report Structure Update (Planned)

### Background

用戶要求更新 k8s-daily-monitor 的目錄結構，簡化日期層級並將日期前綴加入檔名。

### Current Structure

```
k8s-daily-monitor/
├── <project>/
│   ├── 0-prod/
│   ├── 1-dev/
│   ├── 2-stg/
│   └── 3-rel/
│       └── YYYY/
│           └── MM/
│               └── DD/
│                   ├── k8s-health.md
│                   ├── resource-optimization.md
│                   └── <other-checks>.md
```

**路徑範例**: `pigo/1-dev/2025/12/26/k8s-health.md`

### New Structure (Planned)

```
k8s-daily-monitor/
├── <project>/
│   ├── 0-prod/
│   ├── 1-dev/
│   ├── 2-stg/
│   └── 3-rel/
│       └── YYYY/
│           ├── YYMMDD-k8s-health.md
│           ├── YYMMDD-resource-optimization.md
│           └── YYMMDD-<other-checks>.md
```

**路徑範例**: `pigo/1-dev/2025/251226-k8s-health.md`

### Changes Required

#### 1. Repository Structure Documentation

**File**: `/Users/user/MONITOR/k8s-daily-monitor/README.md`

**Changes**:
- 移除 `MM/DD/` 子目錄層級
- 在檔名中加入 `YYMMDD-` 前綴
- 更新路徑範例
- 更新命名規則說明

#### 2. Health Check Python Scripts

**Files**:
- `/Users/user/PIGO-project/hkidc-k8s-gitlab/pigo-dev-k8s-deploy/monitor/monitor-cronjob/docker/health-check.py`
- `/Users/user/PIGO-project/hkidc-k8s-gitlab/pigo-dev-k8s-deploy/monitor/monitor-cronjob/docker/health-check-full.py` (if exists)

**Current Code**:
```python
REPORT_YEAR = now.strftime("%Y")
REPORT_MONTH = now.strftime("%m")
REPORT_DAY = now.strftime("%d")

REPORT_PATH = f"pigo/1-dev/{REPORT_YEAR}/{REPORT_MONTH}/{REPORT_DAY}"
FILENAME = "k8s-health.md"
```

**New Code** (Planned):
```python
REPORT_YEAR = now.strftime("%Y")
REPORT_YYMMDD = now.strftime("%y%m%d")  # 251226

REPORT_PATH = f"pigo/1-dev/{REPORT_YEAR}"
FILENAME = f"{REPORT_YYMMDD}-k8s-health.md"
```

#### 3. Docker Image Rebuild

**After code changes**:
```bash
cd /Users/user/PIGO-project/hkidc-k8s-gitlab/pigo-dev-k8s-deploy/monitor/monitor-cronjob/docker
./build-image.sh v2  # or next version
docker push asia-east2-docker.pkg.dev/uu-prod/waas-prod/pigo-health-monitor:v2
```

**Update CronJob**:
```bash
# Update cronjob-docker.yml to use new image tag
kubectl apply -f cronjob-docker.yml
```

#### 4. Workflow Documentation

**File**: `/Users/user/CLAUDE/workflows/WF-20251226-5-pigo-dev-health-monitor/README.md`

**Section to Update**:
- **GitHub 報告結構** (line 113)
- **路徑格式** (line 113)

### Benefits of New Structure

1. **扁平化目錄**: 減少巢狀深度，更易瀏覽
2. **檔名唯一性**: 日期前綴確保檔名唯一且可排序
3. **下載友善**: 檔案下載後即包含日期資訊
4. **簡化路徑**: GitHub URL 更短更清晰
5. **年度歸檔**: 按年份資料夾組織，便於長期保存

### Implementation Timeline

**Status**: ✅ Completed (7/7 完成)

**Implementation Progress** (2025-12-27 ~ 2025-12-29):

1. ✅ 更新 k8s-daily-monitor README.md
   - Commit: `e6b231c`
   - Repository: dancyu-axiom-tw-devops/k8s-daily-monitor
   - 更新目錄結構說明、檔名格式、路徑範例

2. ✅ 更新 health-check-full.py 報告路徑邏輯
   - 路徑: `pigo/1-dev/YYYY` (移除 MM/DD)
   - 檔名: `{YYMMDD}-k8s-health.md`
   - 新增 `git pull --rebase` 處理衝突

3. ✅ 重新建立 Docker image v2
   - Image: `pigo-harbor.axiom-gaming.tech/infra-devops/pigo-health-monitor:v2`
   - Digest: `sha256:247cae0ad725ac53cae6eb26ec219148638a0f6c365237ece0f4b76d983f4265`

4. ✅ 推送 Docker image 到 Harbor
   - Status: 成功 (2025-12-29)

5. ✅ 更新 CronJob 配置
   - Image tag: v4 → v2
   - Schedule: `0 9 * * *` (Asia/Taipei timezone)
   - 新增 `timeZone: "Asia/Taipei"` 設定
   - 更新 ConfigMap 中的路徑格式

6. ✅ 測試驗證新路徑格式
   - Job: `manual-test-1766973800`
   - 結果: 報告成功上傳至 `pigo/1-dev/2025/251229-k8s-health.md`
   - Slack 通知正常發送
   - GitHub 推送成功

7. ✅ 更新本 workflow 文檔
   - CHANGELOG.md 已更新

### Impact Analysis

**檔案影響**:
- ✅ `/Users/user/MONITOR/k8s-daily-monitor/README.md` - 需更新
- ✅ `health-check.py` - 需修改路徑邏輯
- ✅ Docker image - 需重建
- ✅ 本 workflow README.md - 需更新

**部署影響**:
- ⚠️ 需重新部署 CronJob (新 image tag)
- ⚠️ 下次執行時將使用新路徑格式
- ✅ 舊報告不受影響 (路徑不變)

**測試計劃**:
1. 手動觸發 Job 驗證新路徑
2. 確認 GitHub 報告成功上傳
3. 確認 Slack 通知包含正確 URL
4. 驗證報告格式正確

---

**Updated**: 2025-12-26 19:00
**Status**: 📋 Planning Complete - Ready for Tomorrow Implementation

## 2025-12-26 - Integration of K8S-SERVICE-HEALTH-CHECK-2 Specification

### Background

整合完整的 K8s 服務健康檢查規範文檔到本項目中。此規範定義了完整的檢查標準、輸出格式、Slack 通知與 Git 報告模板。

### Specification Source

**File**: `/Users/user/CLAUDE/workflows/WF-20251226-5-pigo-dev-health-monitor/K8S-SERVICE-HEALTH-CHECK-2.md`

**Version**: 2.3
**Last Updated**: 2025-01
**Purpose**: Claude Code K8s 上線服務檢查規範

### Key Specifications Integrated

#### 1. Directory Structure (已實現)

```
k8s-daily-monitor/
├── <project>/
│   ├── 0-prod/
│   ├── 1-dev/
│   ├── 2-stg/
│   └── 3-rel/
│       └── YYYY/
│           ├── YYMMDD-k8s-health.md
│           ├── YYMMDD-resource-optimization.md
│           └── YYMMDD-<other-checks>.md
```

**Status**: ✅ 已整合到路徑結構更新規劃中

#### 2. Environment Codes (已實現)

| Code | Environment | Description |
|------|-------------|-------------|
| `0-prod` | Production | 正式環境 |
| `1-dev` | Development | 開發環境 |
| `2-stg` | Staging | 預備環境 |
| `3-rel` | Release | 發布環境 |

**Status**: ✅ PIGO-DEV 使用 `1-dev` 代碼

#### 3. Check Types Defined

| Filename Format | Purpose | Status |
|-----------------|---------|--------|
| `YYMMDD-k8s-health.md` | 服務健康狀態檢查 | ✅ 已實現 |
| `YYMMDD-resource-optimization.md` | 資源使用與優化建議 | 📋 待開發 |
| `YYMMDD-security-audit.md` | 安全性稽核 | 📋 待開發 |
| `YYMMDD-certificate-status.md` | 證書狀態檢查 | 📋 待開發 |
| `YYMMDD-backup-status.md` | 備份狀態檢查 | 📋 待開發 |

**Status**: 目前僅實現 k8s-health.md，其他類型待未來擴展

#### 4. Check Categories & Thresholds

規範定義了 7 大檢查類別:

1. **服務狀態檢查** (Service Status)
   - Deployment 狀態
   - 副本就緒率
   - ReplicaSet 數量

2. **Pod 健康檢查** (Pod Health)
   - Pod 狀態 (Running/Pending/CrashLoop)
   - Ready 狀態
   - 重啟次數 (1h/24h)
   - Pod 年齡

3. **資源使用檢查** (Resource Usage)
   - CPU 使用率 (< 60% 健康, 60-80% 警告, > 80% 異常)
   - Memory 使用率 (< 70% 健康, 70-85% 警告, > 85% 異常)
   - HPA 狀態

4. **網路連線檢查** (Network Connectivity)
   - Service Endpoints
   - Ingress 狀態
   - 健康檢查端點 (HTTP 200)

5. **日誌異常檢查** (Log Anomalies)
   - Error 數量 (1h): < 10 健康, 10-50 警告, > 50 異常
   - Warn 數量 (1h): < 50 健康, 50-200 警告, > 200 異常
   - OOM/Panic 偵測

6. **存儲檢查** (Storage)
   - PVC 狀態 (Bound/Pending/Lost)
   - 存儲使用率 (< 70% 健康, 70-85% 警告, > 85% 異常)

7. **證書檢查** (Certificates)
   - 證書有效期 (> 30 天健康, 7-30 天警告, < 7 天異常)

**Status**: ⚠️ 目前實現部分檢查項目，需逐步完善

#### 5. Slack Summary Format (已實現)

規範定義了 3 種 Slack 訊息格式:

- ✅ **健康狀態** - 全部正常
- ⚠️ **警告狀態** - 發現 N 項警告
- 🚨 **異常狀態** - 發現 N 項異常

**訊息包含**:
- 整體健康狀態 emoji
- 專案/環境/時間資訊
- 關鍵數據摘要 (Pods, CPU, Memory, 錯誤日誌)
- 異常/警告項目列表
- 完整報告連結

**Status**: ✅ 已實現基本格式，但未使用 emoji (符合 PIGO 工程風格要求)

#### 6. Git Markdown Report Format (已實現)

規範定義了完整的 Markdown 報告模板:

**包含章節**:
1. 基本資訊 (專案、環境、時間、狀態)
2. 檢查結果總覽 (表格形式)
3. 各類別詳細檢查結果
   - 服務狀態
   - Pod 健康
   - 資源使用
   - 網路連線
   - 日誌異常
   - 存儲狀態
   - 證書狀態
4. 異常與警告彙整
5. 建議事項 (短期/中期/長期)
6. 附錄：原始檢查數據 (可摺疊)

**Status**: ✅ 已透過 report_generator.py 實現基本報告格式

#### 7. Automation Script (參考實現)

規範提供了完整的 Bash 腳本範例:

**功能**:
- 環境代碼自動對照
- 多項健康檢查
- 狀態判斷 (healthy/warning/critical)
- Slack 通知發送
- Git 報告產生與提交
- README 索引更新

**K8s CronJob 部署**:
- ServiceAccount + RBAC 權限定義
- Secrets 配置 (Slack webhook, Git token)
- ConfigMap 配置 (專案列表、閾值)
- Dockerfile 定義
- 部署步驟文檔

**Status**: ✅ 已實現 Python 版本 (health-check.py)，使用 GitHub App 認證

### Current Implementation vs Specification

#### ✅ Already Implemented

1. **Directory Structure**: `pigo/1-dev/YYYY/YYMMDD-k8s-health.md`
2. **Environment Code**: `1-dev` for pigo-dev
3. **Basic Health Checks**: Pod 狀態, 資源使用, 重啟偵測
4. **Slack Notification**: 工程風格 (無 emoji)
5. **Git Report**: Markdown 格式, GitHub App 上傳
6. **CronJob Deployment**: K8s CronJob, RBAC, ServiceAccount
7. **Automatic Cleanup**: TTL 1h, history limit 1

#### ⚠️ Partially Implemented

1. **Resource Thresholds**: 有定義但未完全對齊規範
   - 目前: Memory > 80%, Memory < 50%, CPU < 20%
   - 規範: CPU 60%/80%, Memory 70%/85%

2. **Check Categories**: 僅實現部分項目
   - ✅ Pod 健康, 資源使用
   - ⚠️ 日誌異常 (未實現)
   - ⚠️ 網路連線 (未實現)
   - ⚠️ 存儲狀態 (未實現)
   - ⚠️ 證書檢查 (未實現)

3. **Report Format**: 基本結構符合，但內容不完整

#### ❌ Not Implemented

1. **Multi-Check Types**: 僅有 k8s-health.md
   - 缺少: resource-optimization, security-audit, certificate-status, backup-status

2. **Advanced Features**:
   - 日誌異常統計 (Error/Warn 數量)
   - 網路連線測試 (Endpoints, Ingress, Health endpoints)
   - 存儲使用率檢查
   - 證書到期時間檢查

3. **README Auto-generation**:
   - 環境 README (`pigo/1-dev/README.md`)
   - 年度 README (`pigo/1-dev/2025/README.md`)
   - 根目錄 README (`k8s-daily-monitor/README.md`)

### Gap Analysis & Action Items

#### High Priority (應優先實現)

1. **對齊資源使用閾值**
   - 調整 CPU/Memory 警告和異常閾值
   - 與規範保持一致

2. **實現日誌異常檢查**
   - Error/Warn 數量統計
   - 最近錯誤樣本收集
   - OOM/Panic 偵測

3. **完善報告格式**
   - 加入「建議事項」章節
   - 加入「原始數據附錄」
   - 完善各檢查類別的表格展示

#### Medium Priority (可逐步實現)

4. **網路連線檢查**
   - Service Endpoints 驗證
   - Ingress 狀態檢查
   - 健康檢查端點測試

5. **存儲狀態檢查**
   - PVC 狀態
   - 存儲使用率

6. **README 自動生成**
   - 環境 README
   - 年度 README
   - 根目錄索引

#### Low Priority (未來擴展)

7. **證書檢查**
   - TLS 證書到期時間

8. **多種檢查類型**
   - resource-optimization.md
   - security-audit.md
   - certificate-status.md

9. **高級功能**
   - Prometheus 告警規則
   - 趨勢分析
   - 異常偵測

### Integration Notes

#### 規範文檔位置

**原始文檔**: `K8S-SERVICE-HEALTH-CHECK-2.md`
**用途**: Claude Code 參考規範
**版本**: 2.3
**內容**:
- 完整檢查項目定義
- 判斷標準與閾值
- Slack/Git 輸出格式範本
- 自動化腳本範例
- K8s 部署 YAML 範例

#### 如何使用此規範

1. **新增檢查項目**: 參考「檢查指令」和「判斷標準」章節
2. **調整閾值**: 參考各檢查類別的「健康/警告/異常」標準
3. **修改報告格式**: 參考「Git Markdown 報告格式」章節
4. **擴展 Slack 通知**: 參考「Slack Summary 格式」章節
5. **部署新環境**: 參考「自動化腳本範例」和「K8s CronJob 部署」章節

#### 規範與實現的差異

**規範風格**: 包含 emoji, 表格豐富, 完整檢查項目
**PIGO 實現**: 工程風格 (無 emoji), 簡潔輸出, 核心檢查項目

**原因**: PIGO 專案特別要求「工程化觀察」、「無 emoji」、「直接性建議」

**結論**: 規範作為參考標準，實際實現可根據專案需求調整

### Next Steps

1. **評估**: 與用戶討論哪些檢查項目需要優先實現
2. **規劃**: 制定分階段實現計劃
3. **開發**: 逐步完善健康檢查功能
4. **測試**: 驗證新增檢查項目的準確性
5. **文檔**: 更新 README.md 說明已實現的功能

### Reference

- **規範文檔**: `K8S-SERVICE-HEALTH-CHECK-2.md`
- **當前實現**: `health-check.py`, `report_generator.py`
- **CronJob 配置**: `cronjob-docker.yml`
- **工作流程文檔**: `README.md`, `CHANGELOG.md`

---

**Updated**: 2025-12-26 19:30
**Status**: ✅ Specification Integrated - Gap Analysis Complete
