# Waas2 生產環境升級 - 快速執行指南

## 📋 明天執行清單

### 1️⃣ 執行前準備 (5 分鐘)

```bash
cd /Users/user/CLAUDE/workflows/WF-20251223-1-waas2-prod-upgrade

# 確認備份存在
ls -la data/backup/20251223-183632/

# 確認所有升級鏡像存在於 GCR
./script/check-gcr-images.sh
```

**預期結果**: 所有鏡像顯示 "FOUND"

---

### 2️⃣ Dry Run 測試 (5 分鐘)

```bash
# 執行 dry run（不會實際部署）
./script/upgrade.sh

# 檢查 git 差異
cd /Users/user/Waas2-project/gitlab.axiom-infra.com/waas2-tenant-k8s-deploy
git diff
```

**檢查項目**:
- service-search: newTag: '60' → '6'
- service-exchange: newTag: '75' → '8'
- service-tron: image name 從 service-tron-v2-rel 改為 service-tron-rel，tag '70' → '4'
- service-eth: newTag: '28' → '2'
- service-user: newTag: '72' → '1'
- service-admin: newTag: '82' → '1'

---

### 3️⃣ 執行升級 (20 分鐘)

```bash
cd /Users/user/CLAUDE/workflows/WF-20251223-1-waas2-prod-upgrade

# 執行升級（會逐一詢問確認）
./script/upgrade.sh --apply
```

**每個服務會詢問**: "Apply XXX? (y/N)"
**建議順序**:
1. service-search (y)
2. service-exchange (y)
3. service-eth (y)
4. service-user (y)
5. service-admin (y)
6. service-tron (y) - 最後執行，因為有改名稱

---

### 4️⃣ Git 版控 (5 分鐘)

```bash
cd /Users/user/CLAUDE/workflows/WF-20251223-1-waas2-prod-upgrade

# 創建分支並提交變更
./script/git-commit.sh
```

**流程**:
1. 創建分支: `20251225-waas-prod-upgrade`
2. 顯示變更檔案和差異
3. 確認後提交 commit
4. 詢問是否 push 到 remote
5. 建議在 GitLab 創建 Merge Request

**Commit Message 已包含**:
- Release Note 標題
- 新增功能清單
- 功能修正清單
- 升級鏡像版本

---

### 5️⃣ 驗證服務 (10 分鐘)

```bash
# 查看所有 Pods 狀態
kubectl get pods -n waas2-prod -o wide

# 查看特定服務
kubectl get pods -n waas2-prod -l app=service-search
kubectl get pods -n waas2-prod -l app=service-exchange
kubectl get pods -n waas2-prod -l app=service-tron
kubectl get pods -n waas2-prod -l app=service-eth
kubectl get pods -n waas2-prod -l app=service-user
kubectl get pods -n waas2-prod -l app=service-admin

# 如有問題，查看 logs
kubectl logs -n waas2-prod -l app=service-XXX --tail=100
```

**預期結果**: 所有 Pods 狀態為 Running，READY 1/1

---

### 6️⃣ GCR 鏡像清理 (5 分鐘)

```bash
cd /Users/user/CLAUDE/workflows/WF-20251223-1-waas2-prod-upgrade

# 先 dry-run 檢查會刪除哪些版本
./script/gcr-cleanup.sh --dry-run

# 確認無誤後實際執行
./script/gcr-cleanup.sh
```

**會保留**:
- 當前 prod 版本 (rollback 用)
- 新升級版本 (當前使用)

**會刪除**: 其他所有舊版本

---

## 🚨 如需緊急回滾

### 方案 A: 使用回滾腳本

```bash
cd /Users/user/CLAUDE/workflows/WF-20251223-1-waas2-prod-upgrade

# 回滾配置檔
./script/rollback.sh

# 重新應用到集群
cd /Users/user/Waas2-project/gitlab.axiom-infra.com/waas2-tenant-k8s-deploy
kubectl apply -k service-search/
kubectl apply -k service-exchange/
kubectl apply -k service-tron/
kubectl apply -k service-eth/
kubectl apply -k service-user/
kubectl apply -k service-admin/
```

### 方案 B: Git 回滾

```bash
cd /Users/user/Waas2-project/gitlab.axiom-infra.com/waas2-tenant-k8s-deploy

# 取消本地修改
git checkout service-*/kustomization.yml

# 重新應用
kubectl apply -k service-XXX/
```

---

## 📊 升級版本對照表

| Service | 當前 | 新版本 | 備註 |
|---------|------|--------|------|
| service-search-rel | 60 | 6 | - |
| service-exchange-rel | 75 | 8 | - |
| service-tron | v2-rel:70 | rel:4 | ⚠️ 鏡像名稱改變 |
| service-eth-rel | 28 | 2 | - |
| service-user-rel | 72 | 1 | - |
| service-waas-admin-rel | 82 | 1 | - |

---

## ⏱️ 預估時間

| 階段 | 時間 |
|------|------|
| 執行前準備 | 5 分鐘 |
| Dry Run 測試 | 5 分鐘 |
| 執行升級 | 20 分鐘 |
| Git 版控 | 5 分鐘 |
| 驗證服務 | 10 分鐘 |
| GCR 清理 | 5 分鐘 |
| **總計** | **50 分鐘** |

---

## 📞 檢查清單

- [ ] 備份確認完整
- [ ] GCR 鏡像檢查通過
- [ ] Dry run 測試通過
- [ ] 升級執行完成
- [ ] Git 分支創建並提交
- [ ] GitLab Merge Request 創建
- [ ] 所有 Pods Running
- [ ] 服務功能驗證通過
- [ ] GCR 清理完成
- [ ] 文檔更新（如需要）

---

**準備日期**: 2025-12-23
**執行日期**: 2025-12-24 (預定)
