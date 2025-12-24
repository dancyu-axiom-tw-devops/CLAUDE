---
ref: [AGENTS.md](~/CLAUDE/AGENTS.md)
status: 已完成
created: 2025-12-23
updated: 2025-12-23
---

# Waas2 Production Upgrade - Preparation Worklog

## 工作摘要

為 Waas2 生產環境升級準備完整的工作流程，包含備份、回滾、升級腳本及 GCR 鏡像清理。

## 完成項目

### 1. ✅ 建立工作目錄結構

```
WF-20251223-1-waas2-prod-upgrade/
├── README.md
├── script/
│   ├── backup-configs.sh       # 備份腳本
│   ├── rollback.sh              # 快速回滾腳本
│   ├── check-gcr-images.sh      # GCR 鏡像檢查
│   ├── gcr-cleanup.sh           # GCR 鏡像清理
│   └── upgrade.sh               # 升級執行腳本
├── data/
│   ├── backup/
│   │   ├── current-versions.txt # 當前版本記錄
│   │   └── 20251223-183632/     # 配置備份
│   └── new-versions/
│       └── upgrade-list.txt     # 升級清單
└── worklogs/
    └── WORKLOG-20251223-preparation.md
```

### 2. ✅ 記錄當前生產環境版本

| Service | Current Version |
|---------|----------------|
| service-search-rel | 60 |
| service-exchange-rel | 75 |
| service-tron-v2-rel | 70 |
| service-eth-rel | 28 |
| service-user-rel | 72 |
| service-waas-admin-rel | 82 |

### 3. ✅ 建立備份

- 備份位置: `data/backup/20251223-183632/`
- 包含: 6 個服務的完整配置
- Git 狀態已記錄

### 4. ✅ 檢查升級鏡像

所有升級鏡像已確認存在於 GCR：
- ✅ service-search-rel:6
- ✅ service-exchange-rel:8
- ✅ service-tron-rel:4 (名稱已改變)
- ✅ service-eth-rel:2
- ✅ service-user-rel:1
- ✅ service-waas-admin-rel:1

### 5. ✅ 準備腳本

#### backup-configs.sh
- 功能: 完整備份當前配置
- 包含: 服務配置 + Git 狀態

#### rollback.sh
- 功能: 快速回滾到備份狀態
- 支援: 自動使用最新備份或指定時間戳

#### check-gcr-images.sh
- 功能: 檢查升級鏡像是否存在於 GCR
- 結果: 所有鏡像已確認

#### gcr-cleanup.sh
- 功能: 清理 GCR 舊版本鏡像
- 保留: 當前 prod 版本 + 新升級版本
- 模式: 支援 --dry-run

#### upgrade.sh
- 功能: 更新 kustomization.yml 並可選擇應用到集群
- 模式: 預設 dry-run，--apply 實際執行
- 安全: 每個服務應用前需確認

## 特殊注意事項

### service-tron 鏡像名稱變更
- **舊**: service-tron-v2-rel:70
- **新**: service-tron-rel:4
- **影響**: kustomization.yml 需同時更新 image name 和 tag

### GCR Housekeeping 策略
只針對本次升級的 6 個服務進行清理：
- service-search-rel: 保留 #60 (當前) + #6 (新)
- service-exchange-rel: 保留 #75 (當前) + #8 (新)
- service-tron-v2-rel: 保留 #70 (當前)
- service-tron-rel: 保留 #4 (新)
- service-eth-rel: 保留 #28 (當前) + #2 (新)
- service-user-rel: 保留 #72 (當前) + #1 (新)
- service-waas-admin-rel: 保留 #82 (當前) + #1 (新)

## 明天執行步驟

### 執行前檢查
```bash
cd /Users/user/CLAUDE/workflows/WF-20251223-1-waas2-prod-upgrade

# 1. 確認備份完整
ls -la data/backup/20251223-183632/

# 2. 確認所有鏡像存在
./script/check-gcr-images.sh
```

### 執行升級 (DRY RUN)
```bash
# 3. 先 dry run 檢查變更
./script/upgrade.sh

# 4. 檢查差異
cd /Users/user/Waas2-project/gitlab.axiom-infra.com/waas2-tenant-k8s-deploy
git diff
```

### 執行升級 (APPLY)
```bash
# 5. 確認無誤後實際應用
cd /Users/user/CLAUDE/workflows/WF-20251223-1-waas2-prod-upgrade
./script/upgrade.sh --apply

# 每個服務會詢問是否 apply，按順序確認
```

### 驗證與清理
```bash
# 6. 驗證 Pods 狀態
kubectl get pods -n waas2-prod -w

# 7. 檢查服務是否正常
# (依實際需求檢查 logs 或 endpoints)

# 8. GCR 清理 (先 dry-run)
./script/gcr-cleanup.sh --dry-run

# 9. 確認無誤後實際清理
./script/gcr-cleanup.sh
```

### 如需回滾
```bash
# 回滾到最新備份
./script/rollback.sh

# 或指定特定備份
./script/rollback.sh 20251223-183632

# 然後重新 apply 舊版本到集群
cd /Users/user/Waas2-project/gitlab.axiom-infra.com/waas2-tenant-k8s-deploy
kubectl apply -k service-search/
kubectl apply -k service-exchange/
# ... 其他服務
```

## 工作完成狀態

- [x] 工作目錄建立
- [x] 當前版本記錄
- [x] 配置備份
- [x] 回滾腳本
- [x] GCR 鏡像檢查
- [x] GCR 清理腳本
- [x] 升級腳本
- [x] 工作日誌

## 時間記錄

- 開始時間: 2025-12-23 18:30
- 完成時間: 2025-12-23 18:50
- 總耗時: 約 20 分鐘
