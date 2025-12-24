# Waas2 Release 鏡像檢查工具

**用途**: RD release Waas2 服務時，自動檢查 GCR 鏡像並比對版本

**建立日期**: 2025-12-23

## 🎯 功能

1. ✅ **檢查 GCR 鏡像是否存在**
2. ✅ **比對目前 prod 版本與新版本**
3. ✅ **顯示版本變更情況** (升級/不變)
4. ✅ **清楚的報告輸出**

## 🚀 快速開始

### 1. 建立 Release 清單

```bash
cd /Users/user/CLAUDE/tools/waas2-release-checker

# 複製範本
cp release.template.txt release-2025-12-23.txt

# 編輯檔案
vim release-2025-12-23.txt
```

**格式範例**:
```
Backend
service-search-rel#6
service-exchange-rel#8
service-tron-rel#70
service-eth-rel#1
service-user-rel#1

Frontend
service-admin-rel#1
```

### 2. 執行檢查

```bash
./check-waas2-release.sh release-2025-12-23.txt
```

### 3. 查看結果

**輸出範例**:
```
========================================
Waas2 Release 鏡像檢查
========================================

Registry: asia-east2-docker.pkg.dev
Project:  uu-prod
Repository: waas-prod

🔐 Authenticating with GCR...

📋 Release File: release-2025-12-23.txt

========================================
📊 Release Summary
========================================

Backend Services:  5
Frontend Services: 1
Total:             6

========================================
🔍 檢查鏡像與版本比對
========================================

[1] Backend - service-search-rel
    New Version:     #6
    Current Version: #60
    GCR Image:       ✅ FOUND
    Version Change:  ➡️  Same (no change)  或  ⬆️  Upgrade (#60 → #6)

[2] Backend - service-exchange-rel
    New Version:     #8
    Current Version: #8
    GCR Image:       ✅ FOUND
    Version Change:  ➡️  Same (no change)

[3] Backend - service-tron-rel
    New Version:     #70
    Current Version: #65
    GCR Image:       ✅ FOUND
    Version Change:  ⬆️  Upgrade (#65 → #70)

[4] Backend - service-eth-rel
    New Version:     #1
    Current Version: #1
    GCR Image:       ❌ NOT FOUND
    Version Change:  ➡️  Same (no change)

[5] Backend - service-user-rel
    New Version:     #1
    Current Version: #1
    GCR Image:       ✅ FOUND
    Version Change:  ➡️  Same (no change)

[6] Frontend - service-admin-rel
    New Version:     #1
    Current Version: #82
    GCR Image:       ✅ FOUND
    Version Change:  ⬆️  Upgrade (#82 → #1)

========================================
📊 Final Summary
========================================

GCR Image Status:
  Found:   5
  Missing: 1

Version Comparison:
  Upgraded: 2
  Same:     4

⚠️  Warning: Some images are missing in GCR!
Please build and push missing images before deployment.
```

## 📋 輸入格式說明

### 標準格式

```
Backend
service-<name>-rel#<version>

Frontend
service-<name>-rel#<version>
```

### 支援的服務

**Backend Services**:
- `service-search-rel`
- `service-exchange-rel`
- `service-tron-rel`
- `service-eth-rel`
- `service-user-rel`
- `service-api-rel`
- `service-gateway-rel`
- `service-notice-rel`
- `service-pol-rel`
- `service-setting-rel`

**Frontend Services**:
- `service-admin-rel` (自動映射到 `service-waas-admin-rel`)

### 版本號格式

- 純數字，不需要前綴
- 範例：`#6`, `#60`, `#82`

## 📊 輸出說明

### 1. GCR Image Status

- **✅ FOUND**: 鏡像存在於 GCR，可以部署
- **❌ NOT FOUND**: 鏡像不存在，需要 build & push

### 2. Version Change

- **⬆️ Upgrade**: 版本升級（例如 #60 → #70）
- **➡️ Same**: 版本相同，沒有變更
- **⚠️ Current version unknown**: 無法取得當前版本（可能是新服務）

### 3. Exit Code

- **0**: 所有鏡像都存在，可以部署
- **1**: 有鏡像不存在，需要先 build & push

## 🔧 進階用法

### 檢查並輸出報告

```bash
./check-waas2-release.sh release-2025-12-23.txt > check-report.txt
```

### 只顯示 missing images

```bash
./check-waas2-release.sh release-2025-12-23.txt 2>&1 | grep -B 3 "NOT FOUND"
```

### 整合到部署腳本

```bash
#!/bin/bash
# deploy-waas2.sh

RELEASE_FILE="release-$(date +%Y%m%d).txt"

echo "Step 1: Checking images..."
if ! /Users/user/CLAUDE/tools/waas2-release-checker/check-waas2-release.sh "$RELEASE_FILE"; then
    echo "❌ Images not ready, aborting deployment"
    exit 1
fi

echo "Step 2: Deploying services..."
cd /Users/user/Waas2-project/waas-tenant-prod/waas2-tenant-k8s-deploy
# ./k8s.sh apply <service>

echo "✅ Deployment complete"
```

## 🔍 版本比對原理

工具會自動讀取當前 prod 環境的版本：

```
/Users/user/Waas2-project/waas-tenant-prod/waas2-tenant-k8s-deploy/
├── service-search/
│   └── kustomization.yml  ← 讀取 newTag
├── service-exchange/
│   └── kustomization.yml  ← 讀取 newTag
...
```

**範例 kustomization.yml**:
```yaml
images:
- name: asia-east2-docker.pkg.dev/uu-prod/waas-prod/service-search-rel
  newTag: '60'  ← 當前版本
```

## 📁 檔案結構

```
/Users/user/CLAUDE/tools/waas2-release-checker/
├── check-waas2-release.sh      # 🔧 主要腳本
├── README.md                   # 📖 本檔案
├── release.template.txt        # 📝 範本
├── release-example.txt         # 📝 範例
└── (你的 release-*.txt)        # 📄 實際 release 清單

/Users/user/CLAUDE/credentials/
└── gcr-juancash-prod.json      # 🔐 GCR 憑證
```

## 🎯 使用情境

### 情境 1: RD Release 前檢查

```bash
# RD: "我要 release 這些服務"
# 建立 release 清單
cat > release-2025-12-23.txt <<EOF
Backend
service-search-rel#70
service-tron-rel#80

Frontend
service-admin-rel#85
EOF

# 執行檢查
./check-waas2-release.sh release-2025-12-23.txt

# 如果全部 ✅ → 可以通知部署
# 如果有 ❌ → 請 RD build & push missing images
```

### 情境 2: 定期檢查

```bash
# 每週五檢查下週要 release 的服務
./check-waas2-release.sh release-next-week.txt > weekly-check.txt

# 發送給團隊
```

### 情境 3: CI/CD 整合

```yaml
# .gitlab-ci.yml
check-images:
  stage: pre-deploy
  script:
    - /Users/user/CLAUDE/tools/waas2-release-checker/check-waas2-release.sh release.txt
  only:
    - main
```

## ❓ 常見問題

### Q: 如何知道服務的正確名稱？

A: 參考範本檔案 `release.template.txt`，或查看：
```bash
ls /Users/user/Waas2-project/waas-tenant-prod/waas2-tenant-k8s-deploy/ | grep service-
```

### Q: service-admin-rel 和 service-waas-admin-rel 有什麼區別？

A: 兩者是同一個服務，工具會自動處理映射：
- 輸入格式：`service-admin-rel#82`
- GCR 鏡像名稱：`service-waas-admin-rel:82`

### Q: 版本號一定要用 # 符號嗎？

A: 是的，格式必須是 `service-xxx-rel#版本號`，例如：
- ✅ 正確：`service-search-rel#60`
- ❌ 錯誤：`service-search-rel:60`
- ❌ 錯誤：`service-search-rel 60`

### Q: 如果當前版本顯示 unknown 怎麼辦？

A: 可能原因：
1. 這是新服務，還沒部署過
2. kustomization.yml 格式不標準
3. 服務目錄名稱不匹配

解決方法：手動檢查 kustomization.yml 檔案。

### Q: 檢查失敗怎麼辦？

A: 根據錯誤訊息處理：
- `NOT FOUND`: Build & push image 到 GCR
- `Permission denied`: 檢查 GCR 憑證
- `Directory not found`: 確認 K8s deploy 目錄路徑

## 🔗 相關工具

- **通用 GCR Checker**: `/Users/user/CLAUDE/tools/gcr-checker/`
- **Waas2 K8s Deploy**: `/Users/user/Waas2-project/waas-tenant-prod/waas2-tenant-k8s-deploy/`
- **GCR Console**: https://console.cloud.google.com/artifacts?project=uu-prod

## 📝 Release Workflow 建議

```
1. RD 完成開發
   ↓
2. Build Docker images
   ↓
3. Push to GCR
   ↓
4. 建立 release.txt
   ↓
5. 執行 check-waas2-release.sh
   ↓
6. 檢查結果：
   • 全部 ✅ → 通知部署團隊
   • 有 ❌ → 回到步驟 2
   ↓
7. 部署到 K8s
   ↓
8. 驗證服務
```

---

**維護者**: Claude AI + DevOps Team
**最後更新**: 2025-12-23
**版本**: 1.0
