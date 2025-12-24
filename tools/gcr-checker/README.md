# GCR Image Checker - 容器映像檔檢查工具

**用途**: 在 RD release 服務版本前，一次檢查所有 image 是否已推送到 GCR

**建立日期**: 2025-12-23

## 📋 目錄

- [快速開始](#快速開始)
- [前置需求](#前置需求)
- [使用方式](#使用方式)
- [範例](#範例)
- [進階用法](#進階用法)
- [故障排除](#故障排除)

## 🚀 快速開始

### 1. 準備 Image 清單

複製範本並填入要檢查的 images:

```bash
cd /Users/user/CLAUDE/tools/gcr-checker
cp release-images.template.txt release-images.txt

# 編輯檔案，取消註解需要檢查的 images
vim release-images.txt
```

### 2. 執行檢查

```bash
./check-gcr-images.sh release-images.txt
```

### 3. 查看結果

- **✅ 綠色**: Image 存在於 GCR
- **❌ 紅色**: Image 不存在，需要 build & push
- **Exit code 0**: 全部找到
- **Exit code 1**: 有 missing images

## 📦 前置需求

### 安裝 Google Cloud SDK

**macOS**:
```bash
# 使用 Homebrew
brew install google-cloud-sdk

# 或下載安裝包
# https://cloud.google.com/sdk/docs/install
```

**Linux**:
```bash
curl https://sdk.cloud.google.com | bash
exec -l $SHELL
```

**驗證安裝**:
```bash
gcloud --version
```

### GCR 憑證

憑證已妥善保存於:
```
/Users/user/CLAUDE/credentials/gcr-juancash-prod.json
```

**權限**: 600 (僅擁有者可讀寫)

**專案資訊**:
- **Project ID**: `uu-prod`
- **Registry**: `asia-east2-docker.pkg.dev`
- **Repository**: `juancash-prod`
- **Service Account**: `juancash-prod-harbor@uu-prod.iam.gserviceaccount.com`

## 📖 使用方式

### 基本用法

```bash
./check-gcr-images.sh <image-list-file>
```

### Image 清單格式

**格式 1: 簡短格式** (推薦)
```
juanworld-api-rel:v1.2.3
juancash-open-api-rel:v2.0.1
juancash-app-bank-rel:latest
```

**格式 2: 完整路徑**
```
asia-east2-docker.pkg.dev/uu-prod/juancash-prod/juanworld-api-rel:v1.2.3
asia-east2-docker.pkg.dev/uu-prod/juancash-prod/juancash-open-api-rel:v2.0.1
```

**註解與空行**:
```
# 這是註解，會被忽略
juanworld-api-rel:v1.2.3

# 空行也會被忽略
juancash-open-api-rel:v2.0.1
```

### 命令列選項

```bash
# 使用自訂憑證
./check-gcr-images.sh -c /path/to/cred.json release-images.txt

# 指定不同的 registry
./check-gcr-images.sh -r us-docker.pkg.dev release-images.txt

# 指定不同的 project
./check-gcr-images.sh -p another-project release-images.txt

# 指定不同的 repository
./check-gcr-images.sh -R another-repo release-images.txt

# 從 stdin 讀取
echo "juanworld-api-rel:v1.2.3" | ./check-gcr-images.sh -

# 顯示幫助
./check-gcr-images.sh -h
```

## 🎯 範例

### 範例 1: 檢查單一服務發布

**release-images.txt**:
```
juanworld-api-rel:v1.2.3
```

**執行**:
```bash
./check-gcr-images.sh release-images.txt
```

**輸出**:
```
========================================
GCR Image Checker
========================================

Registry: asia-east2-docker.pkg.dev
Project:  uu-prod
Repository: juancash-prod

🔐 Authenticating with GCR...
🔧 Configuring Docker for GCR...

🔍 Checking images...

[1] Checking: juanworld-api-rel:v1.2.3
    ✅ FOUND

========================================
📊 Summary
========================================
Total images checked: 1
Found:   1
Missing: 0

✅ All images found in GCR!
Ready for deployment.
```

### 範例 2: 檢查多個服務發布

**release-2025-12-23.txt**:
```
# JuanCash Release 2025-12-23
# API Services
juanworld-api-rel:v1.2.3
juancash-open-api-rel:v2.0.1

# APP Services
juancash-app-bank-rel:v1.5.0
juancash-app-pay-rel:v1.5.0
```

**執行**:
```bash
./check-gcr-images.sh release-2025-12-23.txt
```

**輸出 (有 missing)**:
```
🔍 Checking images...

[1] Checking: juanworld-api-rel:v1.2.3
    ✅ FOUND

[2] Checking: juancash-open-api-rel:v2.0.1
    ❌ NOT FOUND

[3] Checking: juancash-app-bank-rel:v1.5.0
    ✅ FOUND

[4] Checking: juancash-app-pay-rel:v1.5.0
    ✅ FOUND

========================================
📊 Summary
========================================
Total images checked: 4
Found:   3
Missing: 1

⚠️  Some images are missing in GCR!
Please build and push missing images before deployment.
```

### 範例 3: 整合到 CI/CD Pipeline

**pre-deploy-check.sh**:
```bash
#!/bin/bash
set -e

echo "Checking if all images are available in GCR..."

if /Users/user/CLAUDE/tools/gcr-checker/check-gcr-images.sh release-images.txt; then
    echo "✅ Pre-deployment check passed"
    echo "Proceeding with deployment..."
    # kubectl apply -k .
else
    echo "❌ Pre-deployment check failed"
    echo "Please build and push missing images first"
    exit 1
fi
```

### 範例 4: 從其他目錄執行

```bash
# 建立符號連結 (symbolic link)
ln -s /Users/user/CLAUDE/tools/gcr-checker/check-gcr-images.sh /usr/local/bin/check-gcr

# 從任何地方執行
cd /path/to/project
check-gcr release-images.txt
```

## 🔧 進階用法

### 1. 批次檢查多個 Release

```bash
# 建立多個 release 清單
release-v1.0.txt
release-v1.1.txt
release-v2.0.txt

# 批次檢查
for release in release-*.txt; do
    echo "Checking $release..."
    ./check-gcr-images.sh "$release"
    echo ""
done
```

### 2. 輸出檢查報告

```bash
# 輸出到檔案
./check-gcr-images.sh release-images.txt > check-report-$(date +%Y%m%d).txt

# 同時顯示到螢幕和檔案
./check-gcr-images.sh release-images.txt | tee check-report-$(date +%Y%m%d).txt
```

### 3. 只檢查特定類別的服務

```bash
# 只檢查 API 服務
grep "api-rel" release-images.txt | ./check-gcr-images.sh -

# 只檢查特定版本
grep ":v1.2" release-images.txt | ./check-gcr-images.sh -
```

### 4. 產生 Missing Images 清單

```bash
# 建立輔助腳本
cat > get-missing-images.sh <<'EOF'
#!/bin/bash
RESULT=$(./check-gcr-images.sh "$1" 2>&1)
echo "$RESULT" | grep -B 1 "❌ NOT FOUND" | grep "Checking:" | awk '{print $3}'
EOF

chmod +x get-missing-images.sh

# 使用
./get-missing-images.sh release-images.txt
```

### 5. 自動從 Kustomization 提取 Images

```bash
# 從 kustomization.yml 提取 image tag
cat > extract-images-from-kustomize.sh <<'EOF'
#!/bin/bash
KUSTOMIZE_DIR="$1"

# 使用 kubectl kustomize 預覽，提取 images
kubectl kustomize "$KUSTOMIZE_DIR" | \
    grep "image:" | \
    awk '{print $2}' | \
    sort -u
EOF

chmod +x extract-images-from-kustomize.sh

# 使用
./extract-images-from-kustomize.sh /path/to/k8s/dir > auto-generated-images.txt
./check-gcr-images.sh auto-generated-images.txt
```

## 🐛 故障排除

### 問題 1: gcloud: command not found

**原因**: Google Cloud SDK 未安裝

**解決**:
```bash
# macOS
brew install google-cloud-sdk

# Linux
curl https://sdk.cloud.google.com | bash
```

### 問題 2: ERROR: (gcloud.auth.activate-service-account) Invalid JWT

**原因**: 憑證檔案格式錯誤或損壞

**解決**:
```bash
# 檢查憑證檔案
cat /Users/user/CLAUDE/credentials/gcr-juancash-prod.json | jq .

# 重新下載憑證並替換
```

### 問題 3: ERROR: (gcloud.artifacts.docker.images) PERMISSION_DENIED

**原因**: Service Account 沒有存取 Artifact Registry 的權限

**解決**:
在 GCP Console 中檢查 Service Account 權限:
1. 前往 IAM & Admin → Service Accounts
2. 找到 `juancash-prod-harbor@uu-prod.iam.gserviceaccount.com`
3. 確認有以下角色:
   - **Artifact Registry Reader** (`roles/artifactregistry.reader`)

### 問題 4: 檢查很慢

**原因**: 每個 image 都要呼叫 GCP API

**優化**:
1. 只檢查真正需要的 images
2. 使用快取機制 (進階)
3. 批次檢查相同 repository 的 images

### 問題 5: Image 明明存在但顯示 NOT FOUND

**可能原因**:
1. Tag 拼寫錯誤
2. Image 在不同的 repository
3. Registry/Project 設定錯誤

**檢查**:
```bash
# 手動列出所有 tags
gcloud artifacts docker images list \
  asia-east2-docker.pkg.dev/uu-prod/juancash-prod/juanworld-api-rel

# 手動檢查特定 tag
gcloud artifacts docker images describe \
  asia-east2-docker.pkg.dev/uu-prod/juancash-prod/juanworld-api-rel:v1.2.3
```

## 📝 Release Workflow 建議

### 標準發布流程

```
1. RD 開發完成
   ↓
2. 建立 release-YYYYMMDD.txt
   ↓
3. 執行 check-gcr-images.sh
   ↓
4. 如有 missing images:
   - Build missing images
   - Push to GCR
   - 重新執行步驟 3
   ↓
5. 全部 ✅ 後：
   - 通知部署團隊
   - 執行 kubectl apply
   ↓
6. 部署完成
```

### Image Naming Convention

建議統一命名規範:
```
<service-name>-rel:<version>

範例:
- juanworld-api-rel:v1.2.3
- juancash-app-bank-rel:v2.0.1
- static-merchant:2025-12-23

版本號格式:
- Semantic Versioning: v1.2.3 (major.minor.patch)
- Date-based: 2025-12-23
- Git SHA: abc123f (short commit hash)
```

## 🔗 相關文件

- **GCR 憑證**: `/Users/user/CLAUDE/credentials/gcr-juancash-prod.json`
- **Image 範本**: [release-images.template.txt](release-images.template.txt)
- **K8s Deploy**: `/Users/user/JUANCASH-project/github/juancash-prod-k8s-deploy/`

## 🆘 支援

如有問題或建議，請聯繫:
- **DevOps Team**
- **維護者**: Claude AI + DevOps

---

**最後更新**: 2025-12-23
**版本**: 1.0
