# GCR Image Checker - 快速開始

## 🎯 5 分鐘上手

### 步驟 1: 安裝 gcloud (如果還沒安裝)

```bash
# macOS
brew install google-cloud-sdk

# 驗證
gcloud --version
```

### 步驟 2: 建立 Image 清單

```bash
cd /Users/user/CLAUDE/tools/gcr-checker

# 複製範本
cp juancash-services.txt my-release.txt

# 編輯檔案
vim my-release.txt
```

**my-release.txt 範例**:
```
# Release 2025-12-23
juanworld-api-rel:v1.2.3
juancash-open-api-rel:v2.0.1
juancash-app-bank-rel:v1.5.0
```

### 步驟 3: 執行檢查

```bash
./check-gcr-images.sh my-release.txt
```

### 步驟 4: 查看結果

✅ **全部找到** → 可以部署！

```
✅ All images found in GCR!
Ready for deployment.
```

❌ **有 missing** → 需要 build & push

```
⚠️  Some images are missing in GCR!
Please build and push missing images before deployment.
```

## 📋 常見使用情境

### 情境 1: 單一服務 Release

```bash
# 建立清單
cat > single-service.txt <<EOF
juanworld-api-rel:v1.2.3
EOF

# 檢查
./check-gcr-images.sh single-service.txt
```

### 情境 2: 多服務 Release

```bash
# 建立清單
cat > multi-services.txt <<EOF
juanworld-api-rel:v1.2.3
juancash-open-api-rel:v2.0.1
juancash-app-bank-rel:v1.5.0
juancash-app-pay-rel:v1.5.0
EOF

# 檢查
./check-gcr-images.sh multi-services.txt
```

### 情境 3: 整合到部署腳本

```bash
#!/bin/bash
# deploy.sh

# 檢查 images
if ! /Users/user/CLAUDE/tools/gcr-checker/check-gcr-images.sh release-images.txt; then
    echo "❌ Images not ready, aborting deployment"
    exit 1
fi

# 部署
echo "✅ All images ready, deploying..."
kubectl apply -k .
```

## 🔧 進階技巧

### 從 stdin 檢查

```bash
echo "juanworld-api-rel:v1.2.3" | ./check-gcr-images.sh -
```

### 輸出到檔案

```bash
./check-gcr-images.sh my-release.txt > check-report.txt
```

### 只顯示 missing images

```bash
./check-gcr-images.sh my-release.txt 2>&1 | grep -B 1 "NOT FOUND"
```

## ❓ 常見問題

### Q: gcloud 沒安裝怎麼辦？

```bash
# macOS
brew install google-cloud-sdk

# Linux
curl https://sdk.cloud.google.com | bash
```

### Q: 憑證檔案在哪？

```
/Users/user/CLAUDE/credentials/gcr-juancash-prod.json
```

腳本會自動使用此憑證。

### Q: 如何知道 image 的完整名稱？

**格式**: `<service-name>-rel:<version>`

**範例**:
- API: `juanworld-api-rel:v1.2.3`
- APP: `juancash-app-bank-rel:v1.5.0`
- Frontend: `static-merchant:latest`

參考 [juancash-services.txt](juancash-services.txt) 查看所有服務名稱。

### Q: 檢查失敗怎麼辦？

1. 確認 image 名稱拼寫正確
2. 確認 tag 正確
3. 手動檢查：
   ```bash
   gcloud artifacts docker images list \
     asia-east2-docker.pkg.dev/uu-prod/juancash-prod/juanworld-api-rel
   ```

## 📚 更多資訊

詳細說明請參考 [README.md](README.md)

---

**工具位置**: `/Users/user/CLAUDE/tools/gcr-checker/`
**建立日期**: 2025-12-23
