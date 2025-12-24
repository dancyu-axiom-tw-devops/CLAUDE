# Waas2 GCR Image 名稱對照表

**日期**: 2025-12-23
**用途**: 請 RD 使用正確的 GCR image 名稱

---

## ⚠️ 重要：正確的 Image 命名規則

在填寫 release 清單時，請使用以下**正確的 GCR image 名稱**：

---

## 📋 完整對照表

| 服務目錄 | ❌ 錯誤寫法 | ✅ 正確的 GCR Image 名稱 |
|---------|------------|------------------------|
| service-search | service-search-rel | **service-search-rel** ✅ |
| service-exchange | service-exchange-rel | **service-exchange-rel** ✅ |
| service-tron | service-tron-rel | **service-tron-v2-rel** ⚠️ 注意有 v2 |
| service-eth | service-eth-rel | **service-eth-rel** ✅ |
| service-user | service-user-rel | **service-user-rel** ✅ |
| service-admin | service-admin-rel | **service-waas-admin-rel** ⚠️ 注意是 waas-admin |
| service-api | service-api-rel | **service-api-rel** ✅ |
| service-gateway | service-gateway-rel | **gateway-service-rel** ⚠️ 注意順序相反 |
| service-notice | service-notice-rel | **service-notice-rel** ✅ |
| service-pol | service-pol-rel | **service-pol-rel** ✅ |
| service-setting | service-setting-rel | **service-setting-rel** ✅ |

---

## 🔴 特別注意！三個特殊命名

### 1. service-tron → `service-tron-v2-rel`
**錯誤**: `service-tron-rel#70`
**正確**: 使用 `service-tron-rel#70` (工具會自動映射到 service-tron-v2-rel)

**GCR 完整路徑**:
```
asia-east2-docker.pkg.dev/uu-prod/waas-prod/service-tron-v2-rel:70
```

---

### 2. service-admin → `service-waas-admin-rel`
**錯誤**: 沒有，繼續使用 `service-admin-rel#82`
**正確**: 使用 `service-admin-rel#82` (工具會自動映射到 service-waas-admin-rel)

**GCR 完整路徑**:
```
asia-east2-docker.pkg.dev/uu-prod/waas-prod/service-waas-admin-rel:82
```

---

### 3. service-gateway → `gateway-service-rel`
**錯誤**: `service-gateway-rel#10`
**正確**: 使用 `service-gateway-rel#10` (工具會自動映射到 gateway-service-rel)

**GCR 完整路徑**:
```
asia-east2-docker.pkg.dev/uu-prod/waas-prod/gateway-service-rel:10
```

---

## 📝 Release 清單填寫範例

### ✅ 正確寫法（繼續使用簡化名稱，工具會自動處理）

```
Backend
service-search-rel#60
service-exchange-rel#75
service-tron-rel#70          # 工具自動映射到 service-tron-v2-rel
service-eth-rel#28
service-user-rel#72
service-api-rel#10
service-gateway-rel#5        # 工具自動映射到 gateway-service-rel
service-notice-rel#3
service-pol-rel#2
service-setting-rel#1

Frontend
service-admin-rel#82         # 工具自動映射到 service-waas-admin-rel
```

---

## 🔧 工具已支援自動映射

**好消息**: 檢查工具已經更新，會自動處理這些特殊命名！

您**不需要**改變輸入格式，繼續使用：
- `service-tron-rel#70` ✅ (工具會自動查詢 service-tron-v2-rel:70)
- `service-admin-rel#82` ✅ (工具會自動查詢 service-waas-admin-rel:82)
- `service-gateway-rel#5` ✅ (工具會自動查詢 gateway-service-rel:5)

---

## 📊 完整 GCR Image 清單

### Backend Services

```bash
# service-search
asia-east2-docker.pkg.dev/uu-prod/waas-prod/service-search-rel

# service-exchange
asia-east2-docker.pkg.dev/uu-prod/waas-prod/service-exchange-rel

# service-tron ⚠️ 特殊：實際是 v2
asia-east2-docker.pkg.dev/uu-prod/waas-prod/service-tron-v2-rel

# service-eth
asia-east2-docker.pkg.dev/uu-prod/waas-prod/service-eth-rel

# service-user
asia-east2-docker.pkg.dev/uu-prod/waas-prod/service-user-rel

# service-api
asia-east2-docker.pkg.dev/uu-prod/waas-prod/service-api-rel

# service-gateway ⚠️ 特殊：順序相反
asia-east2-docker.pkg.dev/uu-prod/waas-prod/gateway-service-rel

# service-notice
asia-east2-docker.pkg.dev/uu-prod/waas-prod/service-notice-rel

# service-pol
asia-east2-docker.pkg.dev/uu-prod/waas-prod/service-pol-rel

# service-setting
asia-east2-docker.pkg.dev/uu-prod/waas-prod/service-setting-rel
```

### Frontend Services

```bash
# service-admin ⚠️ 特殊：實際是 waas-admin
asia-east2-docker.pkg.dev/uu-prod/waas-prod/service-waas-admin-rel
```

---

## 🎯 給 RD 的建議

### 選項 A: 不需要改變（推薦）

繼續使用簡化名稱，檢查工具會自動處理映射：
```
service-tron-rel#70
service-admin-rel#82
service-gateway-rel#5
```

### 選項 B: 統一命名（長期建議）

如果要統一命名規則，建議：
1. 將 GCR image 重新命名（需要重新 push）
2. 或更新 kustomization.yml 中的 image 名稱

---

## 📌 快速參考

**最重要的三個特殊映射**:

| 簡化名稱 | 實際 GCR 名稱 |
|---------|--------------|
| service-tron-rel | service-tron-**v2**-rel |
| service-admin-rel | service-**waas-admin**-rel |
| service-gateway-rel | **gateway-service**-rel |

---

**建立日期**: 2025-12-23
**維護者**: DevOps Team + Claude AI
**工具位置**: `/Users/user/CLAUDE/tools/waas2-release-checker/`
