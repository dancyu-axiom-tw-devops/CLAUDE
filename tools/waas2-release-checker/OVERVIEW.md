# Waas2 Release Checker - 工具總覽

## 📦 工具目的

專為 Waas2 專案設計的 Release 鏡像檢查工具，在 RD release 服務時自動：
1. 檢查 GCR 鏡像是否存在
2. 比對目前 prod 版本與新版本

## 🎯 解決的問題

### Before (沒有此工具)

```
RD: "我 release 了 service-search #70"
  ↓
手動檢查 GCR (麻煩且容易遺漏)
  ↓
不確定當前版本是多少
  ↓
開始部署
  ↓
可能發生：
  • 鏡像不存在 (ImagePullBackOff)
  • 版本沒變化 (白忙一場)
  • 版本回退 (嚴重錯誤)
```

### After (使用此工具)

```
RD: "我 release 了這些服務"
  ↓
建立 release.txt (30秒)
  ↓
執行: ./check-waas2-release.sh release.txt (10秒)
  ↓
立即知道：
  ✅ 鏡像是否存在
  ✅ 版本變化情況
  ✅ 是否可以部署
  ↓
安心部署！
```

## 📊 輸入輸出示意

### 輸入格式

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

### 輸出結果

```
========================================
🔍 檢查鏡像與版本比對
========================================

[1] Backend - service-search-rel
    New Version:     #6
    Current Version: #60
    GCR Image:       ✅ FOUND
    Version Change:  ⬆️  Upgrade (#60 → #6)

[2] Backend - service-exchange-rel
    New Version:     #8
    Current Version: #8
    GCR Image:       ✅ FOUND
    Version Change:  ➡️  Same (no change)

...

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
```

## 🔄 工作流程

```
┌─────────────────────────────────────────┐
│ 1. RD 完成開發                          │
│    • 本地測試通過                       │
│    • 準備 release                       │
└─────────────────┬───────────────────────┘
                  │
                  ↓
┌─────────────────────────────────────────┐
│ 2. Build & Push Images                  │
│    • docker build                       │
│    • docker push to GCR                 │
└─────────────────┬───────────────────────┘
                  │
                  ↓
┌─────────────────────────────────────────┐
│ 3. 建立 release.txt                     │
│    Backend                              │
│    service-search-rel#70                │
│    ...                                  │
└─────────────────┬───────────────────────┘
                  │
                  ↓
┌─────────────────────────────────────────┐
│ 4. 執行檢查工具                         │
│    ./check-waas2-release.sh release.txt │
└─────────────────┬───────────────────────┘
                  │
         ┌────────┴────────┐
         │                 │
         ↓                 ↓
┌──────────────┐   ┌──────────────────┐
│ 全部 ✅       │   │ 有 ❌             │
│ Exit 0       │   │ Exit 1           │
└──────┬───────┘   └──────┬───────────┘
       │                  │
       ↓                  ↓
┌──────────────┐   ┌──────────────────┐
│ 5. 部署      │   │ 修正問題          │
│ • 通知部署   │   │ • Build missing  │
│ • kubectl    │   │ • 重新檢查        │
│   apply      │   │                  │
└──────────────┘   └──────────────────┘
```

## 🛠️ 核心功能

### 1. GCR 鏡像檢查

```bash
# 自動檢查每個服務的鏡像
asia-east2-docker.pkg.dev/uu-prod/waas-prod/service-search-rel:60
  → ✅ FOUND

asia-east2-docker.pkg.dev/uu-prod/waas-prod/service-tron-rel:70
  → ❌ NOT FOUND
```

### 2. 版本比對

```bash
# 自動讀取當前 prod 版本
/Users/user/Waas2-project/waas-tenant-prod/waas2-tenant-k8s-deploy/
├── service-search/kustomization.yml
│   └── newTag: '60'  ← 當前版本

# 比對結果
Current: #60
New:     #70
Change:  ⬆️ Upgrade (#60 → #70)
```

### 3. 智慧映射

```bash
# 自動處理服務名稱映射
輸入:  service-admin-rel#82
映射:  service-waas-admin-rel:82 (GCR 實際名稱)
目錄:  service-admin/ (K8s deploy 目錄)
```

### 4. 詳細報告

```
GCR Image Status:
  Found:   5 ✅
  Missing: 1 ❌

Version Comparison:
  Upgraded: 2 ⬆️
  Same:     4 ➡️
```

## 📁 檔案結構

```
/Users/user/CLAUDE/tools/waas2-release-checker/
├── check-waas2-release.sh      # 🔧 主腳本 (執行檢查)
├── README.md                   # 📖 完整文件
├── QUICK-START.md              # 🚀 快速開始
├── OVERVIEW.md                 # 📋 本檔案 (總覽)
├── release.template.txt        # 📝 範本 (所有服務)
├── release-example.txt         # 📝 範例 (實際案例)
└── (release-*.txt)             # 📄 你的 release 清單

/Users/user/Waas2-project/waas-tenant-prod/waas2-tenant-k8s-deploy/
├── service-search/
│   └── kustomization.yml       # 讀取當前版本
├── service-exchange/
│   └── kustomization.yml
├── service-tron/
│   └── kustomization.yml
└── ...

/Users/user/CLAUDE/credentials/
└── gcr-juancash-prod.json      # 🔐 GCR 憑證
```

## 🎨 支援的服務

### Backend Services (10)
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

### Frontend Services (1)
- `service-admin-rel` → 映射到 `service-waas-admin-rel`

## 📊 版本比對邏輯

```python
if new_version == current_version:
    狀態 = "➡️ Same (no change)"
    動作 = "不需要更新，但可能需要重啟"

elif new_version > current_version:
    狀態 = "⬆️ Upgrade"
    動作 = "正常升級，建議部署"

elif new_version < current_version:
    狀態 = "⬇️ Downgrade"  # 通常不應該發生
    動作 = "警告：版本回退！請確認是否正確"

elif current_version == "unknown":
    狀態 = "⚠️ Current version unknown"
    動作 = "可能是新服務，請手動確認"
```

## 🔐 安全性

### GCR 憑證
- 路徑: `/Users/user/CLAUDE/credentials/gcr-juancash-prod.json`
- 權限: 600 (僅擁有者可讀寫)
- 專案: `uu-prod`
- Repository: `waas-prod`

### Service Account
- Email: `juancash-prod-harbor@uu-prod.iam.gserviceaccount.com`
- 權限: Artifact Registry Reader (唯讀)

## ⚡ 效能

| 檢查項目 | 時間 |
|---------|------|
| 單一服務 | ~1-2 秒 |
| 6 個服務 | ~6-12 秒 |
| 10 個服務 | ~10-20 秒 |

## 🎯 使用情境

### 情境 1: 日常 Release

```bash
# RD 每天 release
cat > release-daily.txt <<EOF
Backend
service-search-rel#61
service-tron-rel#71
EOF

./check-waas2-release.sh release-daily.txt
```

### 情境 2: 大版本 Release

```bash
# 多個服務同時 release
cat > release-v2.0.txt <<EOF
Backend
service-search-rel#70
service-exchange-rel#10
service-tron-rel#80
service-eth-rel#5
service-user-rel#5

Frontend
service-admin-rel#90
EOF

./check-waas2-release.sh release-v2.0.txt
```

### 情境 3: Hotfix Release

```bash
# 緊急修復單一服務
echo "Backend" > hotfix.txt
echo "service-tron-rel#72" >> hotfix.txt

./check-waas2-release.sh hotfix.txt
```

### 情境 4: CI/CD 整合

```yaml
# .gitlab-ci.yml
stages:
  - check
  - deploy

check-images:
  stage: check
  script:
    - /path/to/check-waas2-release.sh release.txt
  only:
    - main

deploy-services:
  stage: deploy
  script:
    - cd /path/to/waas2-tenant-k8s-deploy
    - ./k8s.sh apply service-search
  needs:
    - check-images
  when: on_success
```

## 📈 最佳實踐

### 1. Release 清單命名

```bash
# 推薦格式
release-YYYYMMDD.txt           # 日期
release-v2.0.txt               # 版本號
release-hotfix-issue-123.txt   # Hotfix
release-sprint-42.txt          # Sprint

# 範例
release-20251223.txt
release-v2.1.0.txt
release-hotfix-tron-timeout.txt
```

### 2. 版本號規則

```bash
# 建議使用遞增數字
#60 → #61 → #62 → ...

# 或使用 Git commit count
git rev-list --count HEAD
```

### 3. Git 版本控制

```bash
# 把 release 清單加入 git
git add release-20251223.txt
git commit -m "Add release checklist for 2025-12-23"
git tag release-20251223
```

### 4. 部署前檢查清單

```
□ 1. 本地測試通過
□ 2. Build Docker images
□ 3. Push to GCR
□ 4. 建立 release.txt
□ 5. 執行 check-waas2-release.sh
□ 6. 全部 ✅ 通過
□ 7. 通知部署團隊
□ 8. 執行部署
□ 9. 驗證服務
```

## 🐛 常見問題

### Q: 版本號格式錯誤

```bash
# ❌ 錯誤
service-search-rel:60     # 使用 : 而非 #
service-search-rel 60     # 缺少 #
service-search-rel#v60    # 版本號包含 v

# ✅ 正確
service-search-rel#60
```

### Q: 服務名稱不匹配

```bash
# ❌ 錯誤
search-rel#60             # 缺少 service- 前綴
service-search#60         # 缺少 -rel 後綴

# ✅ 正確
service-search-rel#60
```

### Q: Backend/Frontend 分類錯誤

```bash
# ❌ 錯誤
backend                   # 小寫
BACKEND                   # 大寫
Backend Services          # 多餘文字

# ✅ 正確
Backend
Frontend
```

## 🔗 相關工具

| 工具 | 用途 | 位置 |
|------|------|------|
| **Waas2 Release Checker** | Waas2 專用 | `/Users/user/CLAUDE/tools/waas2-release-checker/` |
| **通用 GCR Checker** | 通用檢查 | `/Users/user/CLAUDE/tools/gcr-checker/` |
| **Waas2 K8s Deploy** | 部署腳本 | `/Users/user/Waas2-project/waas-tenant-prod/waas2-tenant-k8s-deploy/` |

## 📞 支援

- **工具問題**: Claude AI
- **GCR 權限**: DevOps Team
- **Waas2 部署**: Waas2 Team

---

**建立日期**: 2025-12-23
**版本**: 1.0
**維護者**: Claude AI + Waas2 Team
