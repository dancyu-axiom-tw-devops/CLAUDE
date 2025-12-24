# Waas2 生產環境升級 - 範本使用說明

## 📌 此工作流程可作為範本重複使用

### 使用此範本建立新的升級工作

#### 1. 複製範本目錄

```bash
# 複製到新的工作目錄
cp -r /Users/user/CLAUDE/workflows/WF-20251223-1-waas2-prod-upgrade \
      /Users/user/CLAUDE/workflows/WF-YYYYMMDD-n-waas2-prod-upgrade

cd /Users/user/CLAUDE/workflows/WF-YYYYMMDD-n-waas2-prod-upgrade
```

#### 2. 修改配置檔 `data/upgrade-config.conf`

```bash
# 編輯配置檔
vim data/upgrade-config.conf

# 必須修改的項目:
# - BRANCH_NAME: 改為新的分支名稱 (格式: YYYYMMDD-簡述)
# - COMMIT_TITLE: 改為新的 Release Note 標題
# - NEW_FEATURES: 更新新增功能清單
# - BUG_FIXES: 更新功能修正清單
# - UPGRADES: 更新升級清單 (service_name:current:new)
```

#### 3. 更新升級清單檔案

```bash
# 編輯升級清單
vim data/new-versions/upgrade-list.txt

# 格式:
Backend
service-xxx-rel#新版本
service-yyy-rel#新版本

Frontend
service-zzz-rel#新版本
```

#### 4. 更新 Git Commit 腳本

```bash
# 編輯 script/git-commit.sh
vim script/git-commit.sh

# 修改以下變數:
# - BRANCH_NAME: 與 config.conf 一致
# - COMMIT_MESSAGE: 更新為新的 commit 內容
```

#### 5. 清理舊備份

```bash
# 刪除舊備份
rm -rf data/backup/202512*

# 清空 worklogs (或保留作參考)
rm -rf worklogs/WORKLOG-*.md
```

#### 6. 執行備份和檢查

```bash
# 執行備份
./script/backup-configs.sh

# 檢查 GCR 鏡像
./script/check-gcr-images.sh
```

#### 7. 更新 README.md

```bash
vim README.md

# 更新:
# - status: 改為 "進行中"
# - created: 改為新日期
# - updated: 改為新日期
# - 升級清單表格
```

---

## 📋 範本檔案說明

### 需要每次修改的檔案

| 檔案 | 說明 | 必須修改 |
|------|------|---------|
| `data/upgrade-config.conf` | 升級配置 | ✅ 是 |
| `data/new-versions/upgrade-list.txt` | 升級清單 | ✅ 是 |
| `script/git-commit.sh` | Git commit 訊息 | ✅ 是 |
| `README.md` | 工作說明 | ✅ 是 |

### 可重複使用的腳本（無需修改）

| 腳本 | 用途 |
|------|------|
| `script/backup-configs.sh` | 備份當前配置 |
| `script/rollback.sh` | 快速回滾 |
| `script/check-gcr-images.sh` | 檢查 GCR 鏡像 |
| `script/gcr-cleanup.sh` | 清理舊鏡像 |
| `script/upgrade.sh` | 執行升級 |

---

## 🎯 Commit Message 範本格式

```
YYYYMMDD_WaaS_PRO_Release_Note_ [簡短標題]

新增功能
1. [功能描述1]
2. [功能描述2]
3. [功能描述3]

功能修正
1. [修正項目1]
2. [修正項目2]

升级镜像版本:
- service-xxx-rel: [current] → [new]
- service-yyy-rel: [current] → [new]
```

### 範例

```
20251225_WaaS_PRO_Release_Note_ 黑U检测+Exchange服务宕机修复+一对多子管理员+提款订单强制设置成功按钮+提款到合约

新增功能
1. 黑U检测多源风控集成方案
2. 由一个运营账号开多个商户子管理员账号
3. waas 后台提现订单列表新增设置成功按钮
4. 冻结的用户由审核人员决定后续是否继续冻结
5. 提款到合约
6. chainAnalysis开关

功能修正
1. exchange 服务宕机问题处理

升级镜像版本:
- service-search-rel: 60 → 6
- service-exchange-rel: 75 → 8
- service-tron-rel: 4 (from service-tron-v2-rel:70)
- service-eth-rel: 28 → 2
- service-user-rel: 72 → 1
- service-waas-admin-rel: 82 → 1
```

---

## 🔄 完整工作流程範本

### Phase 1: 準備階段

1. 複製範本到新目錄
2. 修改 `upgrade-config.conf`
3. 更新 `upgrade-list.txt`
4. 修改 `git-commit.sh` 的 commit message
5. 執行 `backup-configs.sh`
6. 執行 `check-gcr-images.sh`

### Phase 2: 執行階段

1. Dry run: `./script/upgrade.sh`
2. 檢查差異: `cd [DEPLOY_DIR] && git diff`
3. 執行升級: `./script/upgrade.sh --apply`
4. Git 版控: `./script/git-commit.sh`
5. 驗證 Pods: `kubectl get pods -n waas2-prod`

### Phase 3: 清理階段

1. 清理預覽: `./script/gcr-cleanup.sh --dry-run`
2. 執行清理: `./script/gcr-cleanup.sh`
3. 建立 Merge Request
4. 更新工作日誌

---

## 📝 工作日誌範本

每次升級建議建立工作日誌記錄：

```markdown
---
ref: [AGENTS.md](~/CLAUDE/AGENTS.md)
status: 已完成
created: YYYY-MM-DD
updated: YYYY-MM-DD
---

# Waas2 Production Upgrade - YYYYMMDD

## 升級內容

[Release Note 標題]

## 升級服務

- service-xxx: version_old → version_new
- service-yyy: version_old → version_new

## 執行時間

- 開始: YYYY-MM-DD HH:MM
- 完成: YYYY-MM-DD HH:MM
- 總時長: XX 分鐘

## 遇到的問題

[如有問題記錄]

## 驗證結果

- [ ] 所有 Pods Running
- [ ] 服務功能正常
- [ ] Git MR 已建立
- [ ] GCR 清理完成
```

---

## 🎓 最佳實踐

1. **每次升級前都先備份**: `./script/backup-configs.sh`
2. **總是先 dry-run**: `./script/upgrade.sh` (不加 --apply)
3. **逐一確認服務**: 不要一次 apply 所有服務
4. **Git 分支命名一致**: 使用 YYYYMMDD-簡述 格式
5. **保留備份直到下次升級**: 方便緊急回滾
6. **GCR 清理延後**: 確認服務穩定後再清理舊鏡像
7. **記錄工作日誌**: 追蹤每次升級的問題和經驗

---

**範本版本**: 1.0
**建立日期**: 2025-12-23
**適用於**: Waas2 生產環境 (gitlab.axiom-infra.com/waas2-tenant-k8s-deploy)
