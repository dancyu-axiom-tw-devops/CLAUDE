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
