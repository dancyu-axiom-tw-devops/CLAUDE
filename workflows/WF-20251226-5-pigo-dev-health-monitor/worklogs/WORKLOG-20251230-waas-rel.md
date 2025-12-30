---
ref: [AGENTS.md](~/CLAUDE/AGENTS.md)
status: 已完成
created: 2025-12-30
updated: 2025-12-30
---

# WORKLOG-20251230 - WAAS-REL Health Monitor 部署

## 任務目標

為 waas-rel 環境部署 K8s 健康監控 CronJob。

## 完成項目

### 1. Credentials 設置

- 建立目錄: `~/CLAUDE/credentials/waas-rel-health-monitor/`
- Slack webhook secret: `secret-slack-webhook.yaml`
- GitHub App secret: `secret-github-app.yaml` (使用 App ID: 2539631)

### 2. 配置文件

- 複製自: `waas2-dev-k8s-deploy/monitor/monitor-cronjob/`
- 目標位置: `waas2-rel-k8s-deploy/monitor/monitor-cronjob/`

修改項目:
- namespace: waas-dev → waas-rel
- schedule: 08:30 → 08:25 (Asia/Taipei)
- imagePullSecrets: waas-dev-harbor → waas-rel-harbor
- TARGET_NAMESPACE: waas-dev → waas-rel

### 3. K8s 部署

```bash
# Secrets
kubectl apply -f ~/CLAUDE/credentials/waas-rel-health-monitor/secret-slack-webhook.yaml
kubectl apply -f ~/CLAUDE/credentials/waas-rel-health-monitor/secret-github-app.yaml

# CronJob
kubectl apply -k /Users/user/Waas2-project/hkidc-k8s-gitlab/waas2-rel-k8s-deploy/monitor/monitor-cronjob/
```

### 4. 測試結果

```
NAME                     STATUS     COMPLETIONS   DURATION   AGE
manual-test-1767058842   Complete   1/1           31s        40s
```

## 部署資訊

| 項目 | 值 |
|------|-----|
| Namespace | waas-rel |
| Schedule | 08:25 (Asia/Taipei) |
| Image | waas-harbor.axiom-gaming.tech/infra-devops/waas-health-monitor:v19 |
| GitHub Path | waas2/waas-rel/YYYY/YYMMDD-k8s-health.md |
| Slack Channel | (使用提供的 webhook) |

## 相關文件

- 配置目錄: `/Users/user/Waas2-project/hkidc-k8s-gitlab/waas2-rel-k8s-deploy/monitor/monitor-cronjob/`
- Credentials: `~/CLAUDE/credentials/waas-rel-health-monitor/`
- 排程表: [SCHEDULE.md](../SCHEDULE.md)
