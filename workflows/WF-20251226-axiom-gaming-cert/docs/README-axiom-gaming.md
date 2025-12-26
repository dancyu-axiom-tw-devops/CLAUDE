# axiom-gaming.tech SSL Certificate Management

## 概述

此目錄包含 `axiom-gaming.tech` 域名的 SSL 憑證配置，使用 cert-manager 和 Cloudflare DNS-01 challenge 自動更新。

## 文件說明

| 文件 | 說明 |
|------|------|
| `secret-cloudflare-axiom-gaming.yaml` | Cloudflare API Token Secret |
| `axiom-gaming.tech.yaml` | ClusterIssuer 和 Certificate 配置 |
| `deploy-axiom-gaming.sh` | 部署腳本 |

## 部署步驟

### 1. 部署憑證配置

```bash
cd /Users/user/K8S/k8s-devops/certs/cloudflare/hkidc-k8s
./deploy-axiom-gaming.sh
```

### 2. 驗證部署狀態

```bash
# 查看 Certificate 狀態
kubectl get certificate axiom-gaming.tech -n default

# 查看詳細資訊
kubectl describe certificate axiom-gaming.tech -n default

# 查看 ClusterIssuer
kubectl get clusterissuer cloudflare-dns-axiom-gaming.tech
```

### 3. 檢查憑證 Secret

```bash
# 查看 Secret
kubectl get secret axiom-gaming.tech -n default

# 查看憑證詳細內容
kubectl get secret axiom-gaming.tech -n default -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -text -noout
```

## 配置說明

### ClusterIssuer

- **Name**: `cloudflare-dns-axiom-gaming.tech`
- **ACME Server**: Let's Encrypt Production
- **Email**: robywei@star-link.tech
- **DNS Solver**: Cloudflare DNS-01

### Certificate

- **Name**: `axiom-gaming.tech`
- **Namespace**: `default`
- **Common Name**: `axiom-gaming.tech`
- **DNS Names**:
  - `*.axiom-gaming.tech` (wildcard)
  - `axiom-gaming.tech`

### Reflector 配置

憑證會自動複製到以下 namespaces:
- `default`
- `pigo-dev`
- `pigo-stg`
- `pigo-rel`

如需新增其他 namespace,修改 `axiom-gaming.tech.yaml` 中的:
```yaml
reflector.v1.k8s.emberstack.com/reflection-allowed-namespaces: "namespace1,namespace2"
reflector.v1.k8s.emberstack.com/reflection-auto-namespaces: "namespace1,namespace2"
```

## 故障排查

### 憑證未成功簽發

1. 檢查 cert-manager logs:
```bash
kubectl logs -n cert-manager -l app=cert-manager
```

2. 檢查 Certificate 事件:
```bash
kubectl describe certificate axiom-gaming.tech -n default
```

3. 檢查 CertificateRequest:
```bash
kubectl get certificaterequest -n default
kubectl describe certificaterequest <name> -n default
```

### Cloudflare API Token 問題

驗證 Secret 是否正確創建:
```bash
kubectl get secret cloudflare-api-token-secret-axiom-gaming -n cert-manager
kubectl get secret cloudflare-api-token-secret-axiom-gaming -n cert-manager -o yaml
```

## 憑證更新

cert-manager 會在憑證到期前 30 天自動更新。手動強制更新:

```bash
kubectl delete certificaterequest -n default -l certificate.cert-manager.io/certificate-name=axiom-gaming.tech
```

## 安全注意事項

- ⚠️ **不要將 `secret-cloudflare-axiom-gaming.yaml` 提交到 Git**
- Cloudflare API Token 應存放於 `~/CLAUDE/credentials/` 目錄
- 使用最小權限原則配置 Cloudflare API Token (僅需 Zone:DNS:Edit 權限)

## 相關文檔

- [cert-manager 文檔](https://cert-manager.io/docs/)
- [Cloudflare DNS-01 Challenge](https://cert-manager.io/docs/configuration/acme/dns01/cloudflare/)
- [Reflector 文檔](https://github.com/emberstack/kubernetes-reflector)

---

**Created**: 2025-12-26
**Cluster**: tp-hkidc-k8s
**Maintainer**: DevOps Team
