# Forex Production Upgrade Workflow

---
**狀態**: 已完成
**建立日期**: 2025-12-23
**最後更新**: 2025-12-23
**參考**: [AGENTS.md](~/CLAUDE/AGENTS.md)

---

## 📋 本次升級內容

### Backend Services (11)
- notice-service-rel: 68 → 71
- powercard-setting-service-rel: 27 → 28
- user-service-rel: 142 → 148
- powercard-service-rel: 111 → 116
- expose-api-service-rel: (新服務) → 2
- dwh-service-rel: 80 → 84
- web3j-address-service-rel: 9 → 12
- balance-service-rel: 61 → 63
- exchange-out-service-rel: (新服務) → 6
- setting-service-rel: 212 → 219
- exchange-service-rel: 231 → 239

### Frontend Services (4)
- forex-web-rel: 201 → 204
- uu-h5-rel: 386 → 407
- powercard-admin-front-rel: 74 → 76
- forex-admin-front-rel: 262 → 268

---

## 🗂️ 目錄結構

```
WF-20251223-2-forex-prod-upgrade/
├── README.md                          # 本文件
├── TEMPLATE-USAGE.md                  # 範本使用說明
├── script/
│   ├── check-and-record-versions.sh  # 檢查 GCR 鏡像並記錄版本
│   └── gcr-cleanup.sh                 # GCR 鏡像清理
├── data/
│   ├── backup/
│   │   └── current-versions.txt      # 當前生產環境版本記錄
│   ├── new-versions/
│   │   └── upgrade-list.txt          # 升級清單
│   └── version-comparison-table.md   # 版本對照表
└── worklogs/
    └── (工作日誌)
```

---

## 🚀 快速開始

### 前置準備

1. **Git 認證設定**（使用 teleport）：
   ```bash
   source ~/.zshrc
   tp-gitlab
   ```

2. **切換到工作目錄**：
   ```bash
   cd /Users/user/CLAUDE/workflows/WF-20251223-2-forex-prod-upgrade
   ```

3. **確保 gcloud 使用正確帳號**：
   ```bash
   gcloud config set account dancyu@star-link.tech
   ```

---

## 📝 執行步驟

### Step 1: 檢查 GCR 鏡像並記錄版本

執行檢查腳本，會自動：
- 從 `/Users/user/FOREX-project/prod-cloud/forex-prod-k8s-deploy/components/images/kustomization.yaml` 讀取當前版本
- 檢查所有升級鏡像是否存在於 GCR
- 生成版本對照表

```bash
./script/check-and-record-versions.sh
```

**輸出檔案**：
- `data/backup/current-versions.txt` - 當前版本記錄
- `data/version-comparison-table.md` - 版本對照表

### Step 2: GCR 鏡像清理

**清理策略**：只刪除**小於當前生產版本**的舊鏡像，保留當前版本及所有更新的版本。

#### 2.1 預覽清理計畫（Dry-run）

```bash
# 查看所有服務的清理計畫
./script/gcr-cleanup.sh

# 測試單一服務
./script/gcr-cleanup.sh --test notice-service-rel
```

#### 2.2 執行清理

```bash
# 清理所有服務
./script/gcr-cleanup.sh --apply

# 清理單一服務
./script/gcr-cleanup.sh --test notice-service-rel --apply
```

---

## 📊 版本對照表

詳見：[data/version-comparison-table.md](data/version-comparison-table.md)

---

## 🔧 腳本說明

### check-and-record-versions.sh

**功能**：
1. 從 `components/images/kustomization.yaml` 讀取當前生產版本
2. 檢查 `data/new-versions/upgrade-list.txt` 中的所有升級鏡像是否存在於 GCR
3. 生成版本對照表

**使用方式**：
```bash
./script/check-and-record-versions.sh
```

**輸出**：
- 當前版本記錄：`data/backup/current-versions.txt`
- 版本對照表：`data/version-comparison-table.md`
- GCR 鏡像檢查結果（終端輸出）

### gcr-cleanup.sh

**功能**：清理 GCR 舊版本鏡像

**清理策略**：
- 保留：**當前生產版本及以上的所有版本**
- 刪除：**只刪除小於當前生產版本的舊版本**

**參數**：
- `--apply`：實際執行刪除（預設為 dry-run）
- `--test <service-name>`：只處理指定的單一服務

**使用範例**：
```bash
# Dry-run 所有服務
./script/gcr-cleanup.sh

# 實際清理所有服務
./script/gcr-cleanup.sh --apply

# Dry-run 單一服務
./script/gcr-cleanup.sh --test user-service-rel

# 實際清理單一服務
./script/gcr-cleanup.sh --test user-service-rel --apply
```

---

## 📁 重要檔案說明

### data/new-versions/upgrade-list.txt

升級清單格式：
```
Backend
service-name-rel#新版本號

Frontend
service-name-rel#新版本號
```

### data/backup/current-versions.txt

當前生產環境版本記錄，格式：
```
service-name-rel: 版本號
```

### components/images/kustomization.yaml

Forex 專案的鏡像版本控制檔案：
```
/Users/user/FOREX-project/prod-cloud/forex-prod-k8s-deploy/components/images/kustomization.yaml
```

---

## 🎯 GCR 相關資訊

**Registry**: `asia-east2-docker.pkg.dev`
**Project**: `uu-prod`
**Repository**: `uu-prod/forex`

**鏡像路徑格式**：
```
asia-east2-docker.pkg.dev/uu-prod/uu-prod/forex/{service-name}/{image-name}:{tag}
```

**範例**：
```
asia-east2-docker.pkg.dev/uu-prod/uu-prod/forex/user-service/user-service-rel:148
```

---

## ⚠️ 注意事項

1. **Git 認證**：執行前務必先執行 `source ~/.zshrc` 和 `tp-gitlab` 設定 Git 認證

2. **GCloud 帳號**：確保使用有權限的帳號（`dancyu@star-link.tech`）

3. **新服務處理**：
   - `expose-api-service-rel` 和 `exchange-out-service-rel` 是新服務
   - 當前版本記錄中沒有這兩個服務
   - GCR 清理會自動跳過新服務

4. **GCR 清理策略**：
   - 只刪除**小於當前版本**的舊鏡像
   - 保留當前版本及所有更新的版本
   - 不會刪除大於新版本的未來版本

5. **Dry-run 優先**：
   - 執行刪除前先 dry-run 確認
   - 可以先在單一服務上測試

---

## 🔄 作為範本使用

此工作流程可作為 Forex 生產環境升級的標準範本。詳見 [TEMPLATE-USAGE.md](TEMPLATE-USAGE.md)。

---

## ✅ 檢查清單

- [ ] 已執行 `tp-gitlab` 設定 Git 認證
- [ ] 已檢查 GCR 鏡像存在性
- [ ] 已生成版本對照表
- [ ] 已執行 GCR 清理（dry-run）
- [ ] 已執行 GCR 清理（apply）
- [ ] 已驗證清理結果

---

**範本版本**: 1.0
**建立日期**: 2025-12-23
**適用於**: Forex 生產環境升級
