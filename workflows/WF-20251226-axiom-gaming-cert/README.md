---
ref: [AGENTS.md](~/CLAUDE/AGENTS.md)
status: 已完成
created: 2025-12-26
updated: 2025-12-26
---

# WF-20251226 - axiom-gaming.tech SSL 憑證配置

## 任務目標

在 tp-hkidc-k8s 叢集建立 axiom-gaming.tech 域名的 SSL 憑證自動更新配置。

## 工作內容

### 1. 憑證配置文件

創建 `/Users/user/K8S/k8s-devops/certs/cloudflare/hkidc-k8s/axiom-gaming.tech.yaml`:
- ClusterIssuer: `cloudflare-dns-axiom-gaming.tech`
- Certificate: `axiom-gaming.tech` (namespace: **pigo-dev**)
- DNS Names: `*.axiom-gaming.tech`, `axiom-gaming.tech`
- Reflector: 自動複製到 default, pigo-dev, pigo-stg, pigo-rel, **gitlab, monitoring, harbor, teleport**

### 2. Cloudflare API Token

- Token: `l7QL6Bmj2LuxztnGDVDyMLAHlQfszUB52e4fekH5`
- 備份位置: `~/CLAUDE/credentials/cloudflare/axiom-gaming.tech.token`
- Secret 配置: `script/secret-cloudflare-axiom-gaming.yaml`

### 3. 腳本工具

存放於 `script/` 目錄:
- `deploy-axiom-gaming.sh` - 部署憑證配置
- `cleanup-axiom-gaming.sh` - 清理憑證配置
- `cleanup-cp-certificates.sh` - 清理 cp-*.vip 舊憑證（已執行）
- `secret-cloudflare-axiom-gaming.yaml` - Cloudflare API Token Secret

## 部署步驟

```bash
# 1. 創建 Cloudflare API Token Secret
kubectl apply -f ~/CLAUDE/workflows/WF-20251226-axiom-gaming-cert/script/secret-cloudflare-axiom-gaming.yaml

# 2. 部署憑證配置
kubectl apply -f /Users/user/K8S/k8s-devops/certs/cloudflare/hkidc-k8s/axiom-gaming.tech.yaml

# 3. 驗證狀態
kubectl get certificate axiom-gaming.tech -n pigo-dev
kubectl describe certificate axiom-gaming.tech -n pigo-dev
```

或使用部署腳本:
```bash
~/CLAUDE/workflows/WF-20251226-axiom-gaming-cert/script/deploy-axiom-gaming.sh
```

## 部署歷程

### 問題排查

1. **阿里雲憑證衝突**: monitoring namespace 存在使用阿里雲 DNS 的舊憑證，導致 Cloudflare 憑證無法簽發
   - 解決: 刪除舊的阿里雲 ClusterIssuer 和 Certificate

2. **cp-*.vip 憑證錯誤**: cp-dev.vip, cp-rel.vip, cp-stage.vip 的 YAML 已從 repo 刪除，但 K8s 資源仍存在，導致 cert-manager 報錯
   - 解決: 執行 `cleanup-cp-certificates.sh` 清理殘留資源

3. **orphaned challenge 資源**: 刪除 monitoring namespace 憑證時留下孤兒 challenge 資源，阻塞新憑證簽發
   - 解決: 集群管理者清理所有 hkidc 託管的阿里雲憑證

### 最終部署

- **日期**: 2025-12-26
- **集群**: tp-hkidc-k8s
- **Namespace**: pigo-dev
- **狀態**: ✅ 已成功部署

## 文件結構

```
WF-20251226-axiom-gaming-cert/
├── README.md                           # 本文件
├── script/
│   ├── secret-cloudflare-axiom-gaming.yaml   # Cloudflare API Token Secret
│   ├── deploy-axiom-gaming.sh          # 部署腳本
│   └── cleanup-axiom-gaming.sh         # 清理腳本
└── docs/
    └── README-axiom-gaming.md          # 詳細操作文檔
```

## 主要配置檔

位置: `/Users/user/K8S/k8s-devops/certs/cloudflare/hkidc-k8s/axiom-gaming.tech.yaml`

## 安全注意事項

- ⚠️ Secret 文件已移至 workflow 目錄,不在 k8s-devops git repo 中
- Cloudflare API Token 已備份至 `~/CLAUDE/credentials/`
- 部署時需手動 apply secret 文件

## 參考文檔

- 詳細操作說明: `docs/README-axiom-gaming.md`
- AGENTS.md 規範: `~/CLAUDE/AGENTS.md`
