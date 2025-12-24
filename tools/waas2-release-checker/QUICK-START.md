# Waas2 Release Checker - 快速開始

## 🎯 3 步驟完成檢查

### 步驟 1: 建立 Release 清單

```bash
cd /Users/user/CLAUDE/tools/waas2-release-checker
cp release.template.txt release-today.txt
vim release-today.txt
```

**填入您的服務和版本**:
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

### 步驟 2: 執行檢查

```bash
./check-waas2-release.sh release-today.txt
```

### 步驟 3: 查看結果

**✅ 全部通過**:
```
✅ All images found in GCR!
✅ 3 service(s) will be upgraded.
Ready for deployment!
```
→ 可以部署！

**❌ 有問題**:
```
⚠️  Warning: Some images are missing in GCR!
Please build and push missing images before deployment.
```
→ 需要 build & push missing images

## 📋 輸入格式

```
Backend
service-<name>-rel#<版本號>

Frontend
service-<name>-rel#<版本號>
```

**範例**:
- `service-search-rel#60` ✅
- `service-admin-rel#82` ✅
- `service-search:60` ❌ (錯誤格式)

## 📊 輸出內容

檢查工具會顯示：

1. **GCR 鏡像狀態**:
   - ✅ FOUND = 鏡像存在
   - ❌ NOT FOUND = 需要 build & push

2. **版本比對**:
   - ⬆️ Upgrade = 版本升級
   - ➡️ Same = 版本相同

3. **總結報告**:
   - 找到的鏡像數量
   - 缺失的鏡像數量
   - 升級的服務數量

## 🔧 常用指令

```bash
# 檢查並輸出報告
./check-waas2-release.sh release.txt > report.txt

# 只看 missing images
./check-waas2-release.sh release.txt 2>&1 | grep "NOT FOUND"

# 顯示幫助
./check-waas2-release.sh -h
```

## ❓ 常見問題

**Q: 沒有 gcloud 怎麼辦？**
```bash
brew install google-cloud-sdk
```

**Q: 服務名稱不確定？**
```bash
# 查看範本
cat release.template.txt
```

**Q: 版本號怎麼填？**
- 只填數字，不要其他符號
- 範例：`#6`, `#60`, `#82`

---

更多詳情請參考 [README.md](README.md)
