# Forex 生產環境升級 - 範本使用說明

## 📌 此工作流程可作為範本重複使用

---

## 使用此範本建立新的升級工作

### 1. 複製範本目錄

```bash
# 複製到新的工作目錄（修改日期和序號）
cp -r /Users/user/CLAUDE/workflows/WF-20251223-2-forex-prod-upgrade \
      /Users/user/CLAUDE/workflows/WF-YYYYMMDD-n-forex-prod-upgrade

cd /Users/user/CLAUDE/workflows/WF-YYYYMMDD-n-forex-prod-upgrade
```

### 2. 更新升級清單

編輯 `data/new-versions/upgrade-list.txt`：

```bash
vim data/new-versions/upgrade-list.txt
```

**格式**：
```
Backend
service-name-rel#新版本號
service-name-rel#新版本號

Frontend
service-name-rel#新版本號
```

**範例**：
```
Backend
notice-service-rel#75
user-service-rel#150

Frontend
forex-web-rel#210
uu-h5-rel#420
```

### 3. 清理舊備份

```bash
# 刪除舊的版本記錄
rm -f data/backup/current-versions.txt
rm -f data/version-comparison-table.md

# 清空 worklogs（或保留作參考）
rm -rf worklogs/*
```

### 4. 執行檢查和記錄

```bash
# 前置準備
source ~/.zshrc
tp-gitlab
gcloud config set account dancyu@star-link.tech

# 執行檢查
./script/check-and-record-versions.sh
```

### 5. 執行 GCR 清理

```bash
# Dry-run 預覽
./script/gcr-cleanup.sh

# 確認後執行
./script/gcr-cleanup.sh --apply
```

### 6. 更新 README.md

修改 README.md 中的升級內容和日期：

```bash
vim README.md

# 更新以下欄位：
# - 建立日期
# - 最後更新日期
# - 本次升級內容（Backend/Frontend 列表）
```

---

## 📋 範本檔案說明

### 需要每次修改的檔案

| 檔案 | 說明 | 必須修改 |
|------|------|---------|
| `data/new-versions/upgrade-list.txt` | 升級清單 | ✅ 是 |
| `README.md` | 工作說明（更新日期和升級內容） | ✅ 是 |

### 可重複使用的腳本（無需修改）

| 腳本 | 用途 |
|------|------|
| `script/check-and-record-versions.sh` | 檢查 GCR 鏡像並記錄版本 |
| `script/gcr-cleanup.sh` | 清理 GCR 舊鏡像 |

---

## 🎯 完整工作流程範本

### Phase 1: 準備階段

1. 複製範本到新目錄
2. 修改 `data/new-versions/upgrade-list.txt`
3. 清理舊備份檔案
4. 更新 `README.md`

### Phase 2: 執行階段

1. 設定 Git 認證：`source ~/.zshrc && tp-gitlab`
2. 切換 GCloud 帳號：`gcloud config set account dancyu@star-link.tech`
3. 執行版本檢查：`./script/check-and-record-versions.sh`
4. 審查版本對照表：`cat data/version-comparison-table.md`
5. GCR 清理 dry-run：`./script/gcr-cleanup.sh`
6. 執行 GCR 清理：`./script/gcr-cleanup.sh --apply`

### Phase 3: 驗證階段

1. 驗證 GCR 清理結果
2. 記錄工作日誌（可選）

---

## 📝 工作日誌範本

建議每次升級建立工作日誌：

```markdown
---
ref: [AGENTS.md](~/CLAUDE/AGENTS.md)
status: 已完成
created: YYYY-MM-DD
updated: YYYY-MM-DD
---

# Forex Production Upgrade - YYYYMMDD

## 升級內容

[列出升級的服務]

## 升級服務數量

- Backend: X 個
- Frontend: X 個

## 執行時間

- 開始: YYYY-MM-DD HH:MM
- 完成: YYYY-MM-DD HH:MM
- 總時長: XX 分鐘

## GCR 清理統計

- 清理服務數: X
- 刪除鏡像總數: X

## 遇到的問題

[如有問題記錄]

## 驗證結果

- [ ] GCR 鏡像檢查通過
- [ ] 版本對照表已生成
- [ ] GCR 清理完成
```

---

## 🎓 最佳實踐

1. **每次升級前都先檢查 GCR 鏡像**：確保所有升級鏡像存在
2. **總是先 dry-run**：`./script/gcr-cleanup.sh`（不加 --apply）
3. **可以先測試單一服務**：`./script/gcr-cleanup.sh --test service-name`
4. **保留備份直到下次升級**：方便查看歷史版本
5. **GCR 清理策略**：只刪除小於當前版本的舊鏡像
6. **記錄工作日誌**：追蹤每次升級的問題和經驗

---

## 🔄 與 Waas2 範本的差異

Forex 升級範本與 Waas2 升級範本的主要差異：

| 項目 | Forex | Waas2 |
|------|-------|-------|
| **版本控制檔案** | `components/images/kustomization.yaml` | 各服務的 `kustomization.yml` |
| **鏡像路徑** | `asia-east2-docker.pkg.dev/uu-prod/uu-prod/forex/{service}/{image}` | `asia-east2-docker.pkg.dev/uu-prod/waas-prod/{image}` |
| **是否需要修改 K8s 配置** | ❌ 否（只清理 GCR） | ✅ 是（需更新 kustomization.yml） |
| **Git 認證方式** | Teleport (`tp-gitlab`) | Teleport (`tp-gitlab`) |
| **清理策略** | 保留當前版本及以上 | 保留當前版本 + 新版本 |

---

## ⚠️ 重要提醒

1. **Forex 專案特性**：
   - 使用集中式的 `components/images/kustomization.yaml` 管理所有鏡像版本
   - **不需要**修改各服務的 K8s 配置檔
   - 升級工作流程主要是 GCR 鏡像清理

2. **新服務處理**：
   - 如果升級清單中包含新服務（當前版本記錄中沒有）
   - GCR 清理會自動跳過這些服務
   - 不會誤刪新服務的鏡像

3. **Git 認證**：
   - 必須先執行 `source ~/.zshrc` 和 `tp-gitlab`
   - 否則無法訪問 GitLab 倉庫

4. **GCloud 權限**：
   - 需使用有 `artifactregistry.tags.delete` 權限的帳號
   - 建議使用個人帳號 `dancyu@star-link.tech`

---

## 📂 目錄命名規範

```
WF-YYYYMMDD-n-forex-prod-upgrade
   │      │ │
   │      │ └─ 序號（當天第幾個工作）
   │      └─── 日期
   └────────── 工作流程前綴
```

**範例**：
- `WF-20251223-2-forex-prod-upgrade` - 2025年12月23日第2個 Forex 升級工作
- `WF-20251225-1-forex-prod-upgrade` - 2025年12月25日第1個 Forex 升級工作

---

**範本版本**: 1.0
**建立日期**: 2025-12-23
**適用於**: Forex 生產環境升級
