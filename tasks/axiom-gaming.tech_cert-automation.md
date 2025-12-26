參考 ~/CLAUDE/AGENTS.md

任務名稱：
Axiom Gaming SSL Certificate Sync & Distribution

任務目標：
從 hkidc Kubernetes 環境（pigo-dev namespace）中，
取得 axiom-gaming.tech 的 TLS 憑證，
轉換為不同服務所需的格式，
並推送至指定的 GitLab 憑證版控專案，供 HAProxy 與 GitLab 主機自動更新使用。

憑證來源：
- Kubernetes Cluster: hkidc
- Namespace: pigo-dev
- TLS Secret name: axiom-gaming.tech
- Secret type: kubernetes.io/tls
  - tls.crt
  - tls.key

Git Repo（憑證集中管理）：
https://hkidc-k8s-gitlab.axiom-gaming.tech/axiom/certs.git

Git Repo 結構規範（必須遵守）：

```
certs/
├── axiom-gaming.tech/
│   ├── haproxy/
│   │   └── axiom-gaming.tech.pem
│   ├── gitlab/
│   │   ├── fullchain.pem
│   │   └── privkey.pem
│   └── meta/
│       └── info.txt
│
├── api.example.com/
│   └── ...
```

憑證格式轉換規則：

1. HAProxy 憑證格式
- 檔案路徑（Repo 內）：
  haproxy/axiom-gaming.tech.pem
- 內容格式：
  fullchain.pem 在前
  privkey.pem 在後

2. Nginx 憑證格式
- 檔案路徑（Repo 內）：
  gitlab/fullchain.pem
  gitlab/privkey.pem
- 不合併為單一 pem 檔
- 私鑰檔案需保留嚴格權限語意

Claude 任務邊界（禁止事項）：
- 不申請或更新憑證
- 不產生 CSR
- 不修改 Kubernetes Secret
- 不直接登入 HAProxy 或 GitLab 主機

下游主機更新規範（供理解用）：
- 憑證更新機器上會有排程腳本，位置：
  /opt/monitor-cert/
- 機器會自行：
  - 檢查憑證到期日
  - git pull 憑證 repo
  - 更新本機路徑：
    - HAProxy: /etc/haproxy/certs/
    - GitLab: /opt/gitlab/data/config/ssl
  - 重新載入服務

輸出要求：
- 憑證變更需 commit 至 Git Repo
- Commit message 需包含：
  - domain name
  - update date
- 若憑證內容無變化，不進行 commit

請以工程自動化與安全為前提完成任務設計與腳本規劃。
