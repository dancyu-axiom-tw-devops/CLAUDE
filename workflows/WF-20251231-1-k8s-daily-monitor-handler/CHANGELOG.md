# K8s Daily Monitor Handler - CHANGELOG

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
