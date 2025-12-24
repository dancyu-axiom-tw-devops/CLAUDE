# GCR Image Checker - 工具總覽

## 📦 工具目的

在 RD release 服務版本時，自動檢查所有 Docker images 是否已推送到 GCR (Google Container Registry)，避免部署時才發現 image 不存在的問題。

## 🎯 解決的問題

### Before (沒有此工具)

```
RD: "我 release 了新版本 v1.2.3"
  ↓
開始部署 kubectl apply
  ↓
❌ Error: ImagePullBackOff
  ↓
檢查發現: image 忘記 push 到 GCR
  ↓
重新 build & push
  ↓
再次部署
  ↓
浪費時間: 30-60 分鐘 😢
```

### After (使用此工具)

```
RD: "我 release 了新版本 v1.2.3"
  ↓
執行: ./check-gcr-images.sh release-v1.2.3.txt
  ↓
✅ All images found!
  ↓
開始部署 kubectl apply
  ↓
成功部署 🎉
  ↓
節省時間: 立即發現問題
```

## 📁 檔案結構

```
/Users/user/CLAUDE/tools/gcr-checker/
├── check-gcr-images.sh              # 🔧 主要腳本
├── README.md                        # 📖 完整說明文件
├── QUICK-START.md                   # 🚀 5分鐘快速開始
├── OVERVIEW.md                      # 📋 本檔案 (工具總覽)
├── release-images.template.txt      # 📝 範本 (所有服務)
├── juancash-services.txt            # 📝 JuanCash 服務清單
├── .gitignore                       # 🚫 Git 忽略規則
└── (你的 release-*.txt)             # 📄 實際使用的清單

/Users/user/CLAUDE/credentials/
└── gcr-juancash-prod.json           # 🔐 GCR 認證憑證 (已妥善保存)
```

## 🔄 使用流程

```
┌─────────────────────────────────────────┐
│  1. 準備 Image 清單                     │
│  cp juancash-services.txt my-list.txt   │
│  vim my-list.txt (取消註解需要的服務)   │
└─────────────────┬───────────────────────┘
                  │
                  ↓
┌─────────────────────────────────────────┐
│  2. 執行檢查                            │
│  ./check-gcr-images.sh my-list.txt      │
└─────────────────┬───────────────────────┘
                  │
                  ↓
┌─────────────────────────────────────────┐
│  3. 自動執行:                           │
│  • 使用 GCR 憑證認證                    │
│  • 逐一檢查每個 image                   │
│  • 顯示 ✅ 或 ❌                         │
└─────────────────┬───────────────────────┘
                  │
         ┌────────┴────────┐
         │                 │
         ↓                 ↓
┌──────────────┐   ┌──────────────┐
│  全部 ✅      │   │  有 ❌        │
│  Exit 0      │   │  Exit 1      │
└──────┬───────┘   └──────┬───────┘
       │                  │
       ↓                  ↓
┌──────────────┐   ┌──────────────────┐
│ 可以部署！    │   │ Build & Push     │
│              │   │ missing images   │
└──────────────┘   └──────────────────┘
```

## 🛠️ 核心功能

### 1. 自動認證

```bash
# 自動使用憑證檔案
gcloud auth activate-service-account \
  --key-file=/Users/user/CLAUDE/credentials/gcr-juancash-prod.json
```

### 2. 批次檢查

```bash
# 支援檢查多個 images
juanworld-api-rel:v1.2.3      → ✅ FOUND
juancash-open-api-rel:v2.0.1  → ❌ NOT FOUND
juancash-app-bank-rel:v1.5.0  → ✅ FOUND
```

### 3. 智慧報表

```
📊 Summary
━━━━━━━━━━━━━━━━
Total: 10
Found: 8 ✅
Missing: 2 ❌

⚠️  Missing images:
  - juancash-open-api-rel:v2.0.1
  - juancash-app-pay-rel:v1.5.0
```

### 4. 靈活輸入

```bash
# 從檔案讀取
./check-gcr-images.sh release.txt

# 從 stdin 讀取
echo "juanworld-api-rel:v1.2.3" | ./check-gcr-images.sh -

# 使用完整路徑
asia-east2-docker.pkg.dev/uu-prod/juancash-prod/juanworld-api-rel:v1.2.3

# 使用簡短名稱 (自動補全)
juanworld-api-rel:v1.2.3
```

## 🎨 Image 清單範本

### 範本 1: 單一服務

```
juanworld-api-rel:v1.2.3
```

### 範本 2: 多個相關服務

```
# API Services Release v1.2.3
juanworld-api-rel:v1.2.3
juanworld-admin-api-rel:v1.2.3
juancash-open-api-rel:v1.2.3
```

### 範本 3: 完整 Release (API + APP)

```
# Full Release 2025-12-23
# API Services
juanworld-api-rel:v1.2.3
juancash-open-api-rel:v2.0.1

# APP Services
juancash-app-bank-rel:v1.5.0
juancash-app-pay-rel:v1.5.0
juancash-scheduler-bank-rel:v1.3.0

# Frontend
static-merchant:2025-12-23
```

## 🔐 安全性

### 憑證保護

```bash
# 檔案權限: 600 (僅擁有者可讀寫)
-rw------- 1 user staff /Users/user/CLAUDE/credentials/gcr-juancash-prod.json

# .gitignore 已設定忽略
*.json
```

### Service Account 權限

- **專案**: `uu-prod`
- **帳號**: `juancash-prod-harbor@uu-prod.iam.gserviceaccount.com`
- **權限**: Artifact Registry Reader (唯讀，無法修改或刪除)

## 📊 效能考量

### 檢查速度

- **單一 image**: ~1-2 秒
- **10 個 images**: ~10-20 秒
- **50 個 images**: ~1-2 分鐘

### 優化建議

1. 只檢查真正需要的 images
2. 使用註解分類，方便選擇性檢查
3. 建立多個小清單而非一個大清單

## 🔌 整合建議

### 整合到 CI/CD

**GitLab CI**:
```yaml
check-images:
  stage: pre-deploy
  script:
    - /path/to/check-gcr-images.sh release-images.txt
  only:
    - main
```

**GitHub Actions**:
```yaml
- name: Check GCR Images
  run: |
    ./check-gcr-images.sh release-images.txt
```

### 整合到部署腳本

```bash
#!/bin/bash
# deploy.sh

echo "Step 1: Checking images..."
if ! ./check-gcr-images.sh release-images.txt; then
    echo "❌ Aborting: Images not ready"
    exit 1
fi

echo "Step 2: Deploying to K8s..."
kubectl apply -k .

echo "✅ Deployment complete"
```

## 📈 使用統計 (建議追蹤)

建議記錄:
- 每次檢查的日期
- 檢查的 image 數量
- 發現的 missing images
- 節省的部署時間

範例:
```
2025-12-23: 檢查 10 個 images, 2 個 missing, 節省 30 分鐘
2025-12-24: 檢查 5 個 images, 0 個 missing, 部署順利
```

## 🎓 最佳實踐

### 1. 命名規範

```bash
# 推薦格式
<service>-rel:<version>

# 範例
juanworld-api-rel:v1.2.3          # ✅ 好
juanworld-api-rel:20251223        # ✅ 好 (日期)
juanworld-api-rel:abc123f         # ✅ 好 (git sha)
juanworld-api:v1.2.3              # ❌ 缺少 -rel
juanworld-api-rel:latest          # ⚠️  不推薦 (難追蹤)
```

### 2. 版本控制

```bash
# 把 image 清單加入 git
git add release-2025-12-23.txt
git commit -m "Add release image list for v1.2.3"
```

### 3. 部署前檢查清單

```
□ 1. 所有 images 已 build
□ 2. 執行 check-gcr-images.sh
□ 3. 全部 ✅ 通過
□ 4. 開始部署
□ 5. 驗證部署結果
```

## 🆘 故障排除快速參考

| 問題 | 原因 | 解決方案 |
|------|------|----------|
| `gcloud: command not found` | 未安裝 SDK | `brew install google-cloud-sdk` |
| `Permission denied` | 憑證權限不足 | 檢查 IAM 角色設定 |
| `NOT FOUND` | Image 不存在 | Build & push image |
| `Invalid JWT` | 憑證檔案錯誤 | 重新下載憑證 |
| 檢查很慢 | API 呼叫多 | 減少 image 數量 |

## 🔗 相關連結

- **GCP Artifact Registry**: https://console.cloud.google.com/artifacts?project=uu-prod
- **gcloud 文件**: https://cloud.google.com/sdk/gcloud/reference/artifacts/docker/images
- **JuanCash K8s Deploy**: `/Users/user/JUANCASH-project/github/juancash-prod-k8s-deploy/`

## 📞 支援

- **工具維護**: Claude AI + DevOps Team
- **GCR 權限**: DevOps Team
- **憑證問題**: 聯繫 GCP 管理員

---

**建立日期**: 2025-12-23
**版本**: 1.0
**位置**: `/Users/user/CLAUDE/tools/gcr-checker/`
