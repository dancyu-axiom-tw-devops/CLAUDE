# Juancash Profile 簡稱 JC

## K8s 環境總覽

| 環境 | Namespace | 集群 |集群登入指令 | 
|-----|-----------|------|------|
| dev | jc-dev | hkidc-k8s | tp-hkidc |
| dev-psp | psp-dev | hkidc-k8s | tp-hkidc |
| prod | jc-prod | jc-prod-k8s  | tp-jc |
| prod-psp | psp-prod | jc-prod-k8s | tp-jc |

## 線下環境 (hkidc-k8s)

### DEV
- Namespace: jc-dev
- K8s 腳本: /Users/user/JUANCASH-project/hkidc-k8s-gitlab/juancash-dev-k8s-deploy

### DEV-PSP
- Namespace: psp-dev
- K8s 腳本: /Users/user/JUANCASH-project/hkidc-k8s-gitlab/psp-dev-k8s-deploy

## 線上環境

### PROD JC 
- Namespace: jc-prod
- K8s 腳本: /Users/user/JUANCASH-project/github/juancash-prod-k8s-deploy
- Nacos: /Users/user/JUANCASH-project/github/juancash-prod-k8s-config-deploy
- Infra: /Users/user/JUANCASH-project/github/juancash-prod-k8s-infra-deploy


### PROD PSP
- Namespace: psp-prod
- K8s 腳本: /Users/user/JUANCASH-project/gitlab.axiom-infra.com/psp-prod-k8s-deploy
- 使用 git-tp 取代 git 指令

## 微服務列表 (16 核心服務)


## 集群管理者腳本 (k8s-devops)

**路徑**: `/Users/user/K8S/k8s-devops`
**GitLab Runner 腳本**: `/Users/user/K8S/k8s-devops/helm/gitlab-runner`
更改此腳本時，務必遵守更改規則

### GitLab Runner 配置

> **Commit 規範**: k8s-devops 使用標準類型前綴並標註路徑
> 範例: `perf: helm/gitlab-runner/<runner-name> CPU limit 調整`

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

