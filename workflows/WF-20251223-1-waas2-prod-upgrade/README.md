---
ref: [AGENTS.md](~/CLAUDE/AGENTS.md)
status: 準備完成，待執行
created: 2025-12-23
updated: 2025-12-23
---

# Waas2 生產環境升級工作流程

## 任務概述

升級 Waas2 生產環境的服務鏡像版本，並清理 GCR 不需要的舊版本鏡像。

## 目標環境

- **Repo**: `/Users/user/Waas2-project/gitlab.axiom-infra.com/waas2-tenant-k8s-deploy`
- **Git Command**: `git-tp` (gitlab.axiom-infra.com 專案)

## 升級清單

### Backend Services

| Service | 當前版本 | 新版本 | 鏡像名稱變更 |
|---------|---------|--------|-------------|
| service-search-rel | ? | #6 | 無 |
| service-exchange-rel | ? | #8 | 無 |
| service-tron-v2-rel | ? | #4 | **改為 service-tron-rel** |
| service-eth-rel | ? | #2 | 無 |
| service-user-rel | ? | #1 | 無 |

### Frontend Services

| Service | 當前版本 | 新版本 | 鏡像名稱變更 |
|---------|---------|--------|-------------|
| service-waas-admin-rel | ? | #1 | 無 |

## 工作流程

1. ✅ 建立工作目錄
2. ✅ 記錄當前生產環境版本
3. ✅ 備份當前 k8s deploy 配置
4. ✅ 準備快速回滾腳本
5. ✅ 檢查 GCR 上的鏡像版本
6. ✅ 建立 GCR 鏡像清理腳本
7. ✅ 準備升級執行腳本
8. ✅ 建立 Git 版控腳本

## 檔案結構

```
WF-20251223-1-waas2-prod-upgrade/
├── README.md                       # 本文件
├── QUICK-START.md                  # 快速執行指南
├── TEMPLATE-USAGE.md               # 範本使用說明
├── script/
│   ├── backup-configs.sh           # 備份腳本
│   ├── rollback.sh                 # 回滾腳本
│   ├── check-gcr-images.sh         # GCR 鏡像檢查
│   ├── upgrade.sh                  # 升級執行腳本
│   ├── gcr-cleanup.sh              # GCR 清理腳本
│   └── git-commit.sh               # Git 版控腳本
├── data/
│   ├── backup/                     # 備份的配置檔
│   │   ├── current-versions.txt    # 當前版本記錄
│   │   └── [timestamp]/            # 時間戳命名的備份
│   ├── new-versions/
│   │   └── upgrade-list.txt        # 升級清單
│   └── upgrade-config.conf         # 升級配置範本
└── worklogs/
    └── WORKLOG-20251223-*.md       # 工作日誌
```

## 安全措施

- ✅ 完整備份當前配置
- ✅ 快速回滾腳本
- ✅ GCR 鏡像清理前保留當前+新版本
- ✅ 明天執行時可快速回滾

## Git 版控

### 分支命名
- 格式: `YYYYMMDD-簡述`
- 本次: `20251225-waas-prod-upgrade`

### Commit Message 格式
```
YYYYMMDD_WaaS_PRO_Release_Note_ [標題]

新增功能
1. [功能1]
2. [功能2]

功能修正
1. [修正1]

升级镜像版本:
- service-xxx: old → new
```

### 執行
```bash
./script/git-commit.sh
```

## 注意事項

- service-tron 鏡像名稱從 `service-tron-v2-rel` 改為 `service-tron-rel`
- GCR housekeeping 只針對本次升級的服務
- 刪除鏡像時保留：當前 prod 版本 + 新升級版本
- Git 使用標準 `git` 指令（非 git-tp）

## 此工作流程可作為範本

詳見 [TEMPLATE-USAGE.md](./TEMPLATE-USAGE.md) 了解如何重複使用此範本。
