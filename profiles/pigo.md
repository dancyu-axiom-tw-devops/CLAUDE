# PIGO Profile

## K8s 環境總覽

| 環境 | Namespace | 集群 | 集群登入指令 |
|-----|-----------|------|---------|
| dev | pigo-dev | hkidc-k8s | tp-hkidc |
| stg | pigo-stg | hkidc-k8s | tp-hkidc |
| rel | pigo-rel | hkidc-k8s | tp-hkidc |
| prod | pigo-prod | pigo-prod-k8s | tp-pigo |

## 線下環境 (hkidc-k8s)

### DEV
- Namespace: pigo-dev
- K8s 腳本: /Users/user/PIGO-project/hkidc-k8s-gitlab/pigo-dev-k8s-deploy
- GitLab: https://hkidc-k8s-gitlab.axiom-gaming.tech/pigo/pigo-dev/pigo-dev-k8s-deploy.git

### STG
- Namespace: pigo-stg
- K8s 腳本: /Users/user/PIGO-project/hkidc-k8s-gitlab/pigo-stage-k8s-deploy
- GitLab: https://hkidc-k8s-gitlab.axiom-gaming.tech/pigo/pigo-stage/pigo-stage-k8s-deploy.git

### REL
- Namespace: pigo-rel
- K8s 腳本: /Users/user/PIGO-project/hkidc-k8s-gitlab/pigo-rel-k8s-deploy
- GitLab: https://hkidc-k8s-gitlab.axiom-gaming.tech/pigo/pigo-rel/pigo-rel-k8s-deploy.git

## 線上環境

### PROD
- Namespace: pigo-prod
- K8s 腳本: /Users/user/PIGO-project/gitlab.axiom-infra.com/pigo-prod-k8s-deploy
- infra 腳本: /Users/user/PIGO-project/gitlab.axiom-infra.com/pigo-prod-k8s-infra-deploy
- 使用 git-tp 取代 git 指令

## 微服務列表

**核心服務**: agent-system, datacenter-api, game-api, payment-api, payment-cron, payment-office, pigo-api, pigo-cron, pigo-office, pigo-web

**輔助服務**: pay-mock (dev, stg), nginx (stg, rel, prod), sql-executor-job (dev, stg, rel)

## 集群管理者腳本 (k8s-devops)

**路徑**: `/Users/user/K8S/k8s-devops`
**GitLab Runner 腳本**: `/Users/user/K8S/k8s-devops/helm/gitlab-runner`

### GitLab Runner 配置

> **Commit 規範**: k8s-devops 使用標準類型前綴並標註路徑
> 範例: `perf: helm/gitlab-runner/pigo-prod-k8s-service-runner CPU limit 500m → 1000m`

| Runner 名稱 | 配置路徑 |
|------------|---------|
| pigo-prod-k8s-service-runner | helm/gitlab-runner/pigo-prod-k8s-service-runner/values.yaml |
| waas-dev-k8s-service-runner01-pigo-dev | helm/gitlab-runner/waas-dev-k8s-service-runner01-pigo-dev/values.yaml |
| waas-dev-k8s-service-runner01-pigo-stg | helm/gitlab-runner/waas-dev-k8s-service-runner01-pigo-stg/values.yaml |
| waas-rel-k8s-service-runner01-pigo-rel | helm/gitlab-runner/waas-rel-k8s-service-runner01-pigo-rel/values.yaml |

### 常用管理指令

```bash
# GitLab Runner 管理
./helm/gitlab-runner/gitlab-runner.sh list                    # 列出所有 runner
./helm/gitlab-runner/gitlab-runner.sh upgrade <runner-name>   # 升級 runner
```

## Health Monitor CronJob

| 環境 | 腳本路徑 | 部署指令 |
|------|---------|---------|
| dev | hkidc-k8s-gitlab/pigo-dev-k8s-deploy/monitor/monitor-cronjob | `kubectl --context tp-hkidc-k8s apply -k <path>` |
| stg | hkidc-k8s-gitlab/pigo-stage-k8s-deploy/monitor/monitor-cronjob | `kubectl --context tp-hkidc-k8s apply -k <path>` |
| rel | hkidc-k8s-gitlab/pigo-rel-k8s-deploy/monitor/monitor-cronjob | `kubectl --context tp-hkidc-k8s apply -k <path>` |
| prod | gitlab.axiom-infra.com/pigo-prod-k8s-infra-deploy/monitor/monitor-cronjob | `kubectl --context tp-pigo-prod-k8s apply -k <path>` |

版本管理: `kustomization.yml` 中的 `images.newTag`

## 常用指令

```bash
./k8s.sh dev -deploy all          # 部署所有
./k8s.sh dev -deploy pigo-api     # 部署指定服務
./k8s.sh dev -restart pigo-api    # 重啟服務
./k8s.sh dev -info                # 查看集群資訊
```
