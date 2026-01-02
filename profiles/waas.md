# WAAS Profile

## K8s 環境總覽

| 環境 | Namespace | 集群 |集群登入指令 | 
|-----|-----------|------|------|
| dev | waas-dev | hkidc-k8s | tp-hkidc |
| rel | waas-rel | hkidc-k8s | tp-hkidc |
| sensitive-rel | waas-sensitive-rel | hkidc-k8s | tp-hkidc | 
| prod | waas2-prod | prod-waas2-tenant | tp-waas |
| prod-sensitive | waas2-sensitive-prod | prod-waas2-tenant | tp-waas |

## 線下環境 (hkidc-k8s)

### DEV
- Namespace: waas-dev
- K8s 腳本: /Users/user/Waas2-project/hkidc-k8s-gitlab/waas2-dev-k8s-deploy

### REL
- Namespace: waas-rel
- K8s 腳本: /Users/user/Waas2-project/hkidc-k8s-gitlab/waas2-rel-k8s-deploy

### Sensitive-REL
- Namespace: waas-sensitive-rel
- K8s 腳本: /Users/user/Waas2-project/hkidc-k8s-gitlab/waas2-k8s-sensitive-rel-deploy

## 線上環境

### PROD 
- Namespace: waas2-prod
- K8s 腳本: /Users/user/Waas2-project/gitlab.axiom-infra.com/waas2-tenant-k8s-deploy
- GitLab: https://gitlab.axiom-infra.com/waas2/waas2-tenant-k8s-deploy
- 使用 git-tp 取代 git 指令

### PROD Sensitive
- Namespace: waas2-sensitive-prod
- K8s 腳本: /Users/user/Waas2-project/gitlab.axiom-infra.com/waas2-tenant-sensitive-k8s-deploy
- 使用 git-tp 取代 git 指令

## 微服務列表 (16 核心服務)

service-admin, service-api, service-gateway, service-user, service-eth, service-tron, service-bsc, service-exchange, service-notice, service-setting, service-pol, service-search, service-security, service-waas-payment-front, xxl-job, nacos

**輔助**: nginx, kafka-ui, monitor, upload, mysql-client

## 集群管理者腳本 (k8s-devops)

**路徑**: `/Users/user/K8S/k8s-devops`
**GitLab Runner 腳本**: `/Users/user/K8S/k8s-devops/helm/gitlab-runner`

### GitLab Runner 配置

| Runner 名稱 | 配置路徑 |
|------------|---------|
| waas-dev-k8s-service-runner01 | helm/gitlab-runner/waas-dev-k8s-service-runner01/values.yaml |
| waas-rel-k8s-service-runner01 | helm/gitlab-runner/waas-rel-k8s-service-runner01/values.yaml |
| waas2-prod-k8s-service-runner | helm/gitlab-runner/waas2-prod-k8s-service-runner/values.yaml |
| prod-waas2-tenant-runner | helm/gitlab-runner/prod-waas2-tenant-runner/values.yaml |

### 常用管理指令

```bash
# GitLab Runner 管理
./helm/gitlab-runner/gitlab-runner.sh list                    # 列出所有 runner
./helm/gitlab-runner/gitlab-runner.sh upgrade <runner-name>   # 升級 runner
```
