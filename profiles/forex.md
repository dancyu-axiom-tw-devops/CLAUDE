# FOREX Profile

## K8s 環境總覽

| 環境 | Namespace | GitLab 伺服器 | 集群 | 登入指令 |
|-----|-----------|--------------|-----------|--------------|
| stg | forex-stg | hkidc-k8s-gitlab | hkidc-k8s | tp-hkidc |
| rel | forex-rel | hkidc-k8s-gitlab | hkidc-k8s | tp-hkidc |
| prod | forex-prod | gitlab.axiom-infra.com | forex-prod-k8s | tp-forex |

## 線下環境 (hkidc-k8s)

### STG
- Namespace: forex-stg
- K8s 腳本: /Users/user/FOREX-project/hkidc-k8s-gitlab/forex-stg/forex-stage-k8s-deploy
- Nacos: /Users/user/FOREX-project/hkidc-k8s-gitlab/forex-stg/forex-stage-k8s-nacos-config

### REL
- Namespace: forex-rel
- K8s 腳本: /Users/user/FOREX-project/hkidc-k8s-gitlab/forex-rel/forex-rel-k8s-deploy
- Nacos: /Users/user/FOREX-project/hkidc-k8s-gitlab/forex-rel/forex-rel-k8s-nacos-config

## 線上環境

### PROD
- Namespace: forex-prod
- K8s 腳本: /Users/user/FOREX-project/gitlab.axiom-infra.com/forex-prod-k8s-deploy
- Nacos: /Users/user/FOREX-project/gitlab.axiom-infra.com/forex-prod-k8s-nacos-config
- Infra: /Users/user/FOREX-project/gitlab.axiom-infra.com/forex-prod-k8s-infra-deploy
- GitLab: https://gitlab.axiom-infra.com/forex/forex-prod/forex-prod-k8s-deploy.git
- 使用 git-tp 取代 git 指令

## 微服務列表 (31 服務)

**前端**: forex-web, forex-h5, forex-admin-front, dd-h5, uu-h5, tenant-h5, 9d-h5-service, powercard-admin-front

**Forex 後端**: forex-gateway, user-service, setting-service, balance-service, exchange-service, jpayment-exchange-service, jcard-service, thirdparty-service, notice-service, dwh-service, support-service, web3j-address-service, expose-api-service, exchange-out-service, kyc-service

**Powercard**: powercard-gateway, powercard-service, powercard-setting-service, powercard-user-service

**公共/基礎**: captcha-service, forex-nginx, nacos, xxl-job

## 版本管理

鏡像版本統一在: components/images/kustomization.yaml

## 集群管理者腳本 (k8s-devops)

**路徑**: `/Users/user/K8S/k8s-devops`
**GitLab Runner 腳本**: `/Users/user/K8S/k8s-devops/helm/gitlab-runner`

### GitLab Runner 配置

> **Commit 規範**: k8s-devops 使用標準類型前綴並標註路徑
> 範例: `perf: helm/gitlab-runner/forex-prod-k8s-runner CPU limit 調整`

| Runner 名稱 | 配置路徑 |
|------------|---------|
| forex-prod-k8s-runner | helm/gitlab-runner/forex-prod-k8s-runner/values.yaml |

### 常用管理指令

```bash
# GitLab Runner 管理
./helm/gitlab-runner/gitlab-runner.sh list                    # 列出所有 runner
./helm/gitlab-runner/gitlab-runner.sh upgrade <runner-name>   # 升級 runner
```

## Health Monitor CronJob

| 環境 | 腳本路徑 | 部署指令 |
|------|---------|---------|
| stg | hkidc-k8s-gitlab/forex-stg/forex-stage-k8s-deploy/monitor/monitor-cronjob | `kubectl --context tp-hkidc-k8s apply -k <path>` |
| rel | hkidc-k8s-gitlab/forex-rel/forex-rel-k8s-deploy/monitor/monitor-cronjob | `kubectl --context tp-hkidc-k8s apply -k <path>` |
| prod | gitlab.axiom-infra.com/forex-prod-k8s-infra-deploy/monitor/monitor-cronjob | `kubectl --context tp-forex-prod-k8s apply -k <path>` |

版本管理: `kustomization.yml` 中的 `images.newTag`
