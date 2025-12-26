# JC-Refactor 服務健康檢查結果

**檢查時間**: 2025-12-24
**檢查範圍**: jc-refactor 目錄下所有服務
**Namespace**: jc-prod

## 檢查結果表

| 服務類別 | 鏡像名 | 服務名 | 腳本目錄 | 已部署 | 有日誌 | 有報錯 |
|---------|--------|--------|---------|--------|--------|--------|
| **API 服務 (7)** | | | | | | |
| API | juancash-applet-api-rel | juancash-applet-api | jc-refactor/api-service/juancash-applet-api | ✅(1) | ❌ | ✅ |
| API | juancash-bank-api-rel | juancash-bank-api | jc-refactor/api-service/juancash-bank-api | ✅(1) | ❌ | ✅ |
| API | juancash-clicent-api-rel | juancash-clicent-api | jc-refactor/api-service/juancash-clicent-api | ✅(1) | ❌ | ✅ |
| API | juancash-open-api-rel | juancash-open-api | jc-refactor/api-service/juancash-open-api | ✅(1) | ❌ | ✅ |
| API | juanword-api-shopmanager-rel | juanword-api-shopmanager | jc-refactor/api-service/juanword-api-shopmanager | ✅(1) | ❌ | ✅ |
| API | juanworld-admin-api-rel | juanworld-admin-api | jc-refactor/api-service/juanworld-admin-api | ✅(1) | ❌ | ✅ |
| API | juanworld-api-rel | juanworld-api | jc-refactor/api-service/juanworld-api | ✅(1) | ❌ | ✅ |
| **註冊中心 (1)** | | | | | | |
| 註冊中心 | juanworld-registercenter-rel | registercenter | jc-refactor/app-service/registercenter | ✅(3) StatefulSet | ❌ | ✅ |
| **APP 服務 (32)** | | | | | | |
| APP | juancash-agentservice-rel | juancash-agentservice | jc-refactor/app-service/juancash-agentservice | ❌ | ❌ | ✅ |
| APP | juancash-amqp-service-rel | juancash-amqp | jc-refactor/app-service/juancash-amqp | ✅(1) | ❌ | ✅ |
| APP | juancash-amqp-consumerservice-rel | juancash-amqp-consumerservice | jc-refactor/app-service/juancash-amqp-consumerservice | ✅(1) | ❌ | ✅ |
| APP | juancash-appletservice-rel | juancash-appletservice | jc-refactor/app-service/juancash-appletservice | ✅(1) | ✅ | ❌(154) |
| APP | juancash-bankservice-rel | juancash-bankservice | jc-refactor/app-service/juancash-bankservice | ✅(1) | ❌ | ✅ |
| APP | juancash-cashflowservice-rel | juancash-cashflowservice | jc-refactor/app-service/juancash-cashflowservice | ✅(1) | ❌ | ✅ |
| APP | juancash-financeservice-rel | juancash-financeservice | jc-refactor/app-service/juancash-financeservice | ✅(1) | ❌ | ✅ |
| APP | juanworld-applicationcenter-service-rel | juanworld-applicationcenter-service | jc-refactor/app-service/juanworld-applicationcenter-service | ✅(1) | ❌ | ✅ |
| APP | juanworld-commissionservice-rel | juanworld-commissionservice | jc-refactor/app-service/juanworld-commissionservice | ✅(1) | ✅ | ❌(154) |
| APP | juanworld-configservice-rel | juanworld-configservice | jc-refactor/app-service/juanworld-configservice | ✅(1) | ✅ | ✅ |
| APP | juanworld-customer-service-service-rel | juanworld-customer-service | jc-refactor/app-service/juanworld-customer-service | ✅(1) | ❌ | ✅ |
| APP | juanworld-riskcontrolservice-rel | juanworld-riskcontrolservice | jc-refactor/app-service/juanworld-riskcontrolservice | ✅(1) | ✅ | ✅ |
| APP | juanworld-service-admin-rel | juanworld-service-admin | jc-refactor/app-service/juanworld-service-admin | ✅(1) | ❌ | ✅ |
| APP | juanworld-service-card-application-rel | juanworld-service-card-application | jc-refactor/app-service/juanworld-service-card-application | ✅(1) | ✅ | ❌(153) |
| APP | juanworld-service-file-application-rel | juanworld-service-file | jc-refactor/app-service/juanworld-service-file | ✅(1) | ❌ | ✅ |
| APP | juanworld-service-image-rel | juanworld-service-image | jc-refactor/app-service/juanworld-service-image | ✅(1) | ❌ | ✅ |
| APP | juanworld-service-merchant-application-rel | juanworld-service-merchant-application | jc-refactor/app-service/juanworld-service-merchant-application | ✅(1) | ❌ | ✅ |
| APP | juanworld-service-redbag-rel | juanworld-service-redbag | jc-refactor/app-service/juanworld-service-redbag | ✅(1) | ❌ | ✅ |
| APP | juanworld-service-remittance-rel | juanworld-service-remittance | jc-refactor/app-service/juanworld-service-remittance | ✅(1) | ❌ | ✅ |
| APP | juanworld-service-shop-rel | juanworld-service-shop | jc-refactor/app-service/juanworld-service-shop | ✅(1) | ❌ | ✅ |
| APP | juanworld-service-sms-application-rel | juanworld-service-sms-application | jc-refactor/app-service/juanworld-service-sms-application | ✅(1) | ❌ | ✅ |
| APP | juanworld-service-system-rel | juanworld-service-system | jc-refactor/app-service/juanworld-service-system | ✅(1) | ❌ | ✅ |
| APP | juanworld-service-trade-rel | juanworld-service-trade-application | jc-refactor/app-service/juanworld-service-trade-application | ❌ | ❌ | ✅ |
| APP | juanworld-service-user-application-rel | juanworld-service-user-application | jc-refactor/app-service/juanworld-service-user-application | ✅(1) | ❌ | ✅ |
| APP | juanworld-shop-businessservice-rel | juanworld-shop-businessservice | jc-refactor/app-service/juanworld-shop-businessservice | ✅(1) | ❌ | ✅ |
| APP | juanworld-shop-marketservice-rel | juanworld-shop-marketservice | jc-refactor/app-service/juanworld-shop-marketservice | ✅(1) | ❌ | ✅ |
| APP | juanworld-shop-permissionservice-rel | juanworld-shop-permissionservice | jc-refactor/app-service/juanworld-shop-permissionservice | ✅(1) | ❌ | ✅ |
| APP | juanworld-statisticalservice-rel | juanworld-statisticalservice | jc-refactor/app-service/juanworld-statisticalservice | ✅(1) | ❌ | ✅ |
| APP | juanworld-userrelation-service-rel | juanworld-userrelation-service | jc-refactor/app-service/juanworld-userrelation-service | ✅(1) | ❌ | ✅ |
| APP | jw_analysis-rel | jw-analysis | jc-refactor/app-service/jw-analysis | ✅(1) | ❌ | ✅ |
| APP | jw_logsystem-rel | jw-logsystem | jc-refactor/app-service/jw-logsystem | ✅(1) | ❌ | ✅ |

## 欄位說明

| 欄位 | 說明 | 圖例 |
|------|------|------|
| **已部署** | Pod 運行狀態 | ✅(n)=運行中n個pod, ❌=未部署或無pod |
| **有日誌** | 最近1小時有日誌輸出 | ✅=有日誌, ❌=無日誌 |
| **有報錯** | 最近1小時日誌中的錯誤數量 | ✅=無錯誤, ⚠️(n)=少量錯誤, ❌(n)=大量錯誤 |

## 統計摘要

### 部署狀態

| 類別 | 總數 | 已部署 | 未部署 | 部署率 |
|------|------|--------|--------|--------|
| API 服務 | 7 | 7 | 0 | 100% |
| APP 服務 | 32 | 30 | 2 | 93.8% |
| 註冊中心 | 1 | 1 (StatefulSet) | 0 | 100% |
| **總計** | **40** | **38** | **2** | **95%** |

### 未部署的服務 (2個)

1. **juancash-agentservice** (APP)
   - 鏡像: juancash-agentservice-rel
   - 路徑: jc-refactor/app-service/juancash-agentservice

2. **juanworld-service-trade-application** (APP)
   - 鏡像: juanworld-service-trade-rel
   - 路徑: jc-refactor/app-service/juanworld-service-trade-application

### 日誌狀態

| 類別 | 有日誌 | 無日誌 | 日誌率 |
|------|--------|--------|--------|
| API 服務 (已部署) | 0 | 7 | 0% |
| APP 服務 (已部署) | 4 | 26 | 13.3% |
| 註冊中心 (已部署) | 0 | 1 | 0% |
| **已部署服務總計** | **4** | **34** | **10.5%** |

### 有日誌的服務 (4個)

1. **juancash-appletservice** - ❌ 有154個錯誤
2. **juanworld-commissionservice** - ❌ 有154個錯誤
3. **juanworld-configservice** - ✅ 無錯誤
4. **juanworld-riskcontrolservice** - ✅ 無錯誤
5. **juanworld-service-card-application** - ❌ 有153個錯誤

### 錯誤分析

**有大量錯誤的服務 (3個)**:
- juancash-appletservice: 154個錯誤
- juanworld-commissionservice: 154個錯誤
- juanworld-service-card-application: 153個錯誤

**可能原因**:
- 這些服務有日誌輸出，說明正在運行
- 錯誤數量較高，需要進一步調查錯誤內容

## 日誌問題分析

### 為什麼大部分服務顯示"無日誌"？

可能原因：

1. **日誌輸出到文件而非 stdout**
   - 服務可能將日誌寫入 NAS (`/juancash/logs/`)
   - kubectl logs 只能抓取 stdout/stderr

2. **日誌級別設定**
   - 可能設定為 ERROR only
   - 最近1小時無錯誤發生則無輸出

3. **日誌收集方式**
   - 可能使用外部日誌收集系統（如 Filebeat）
   - Container 本身不輸出到 stdout

### 建議驗證方式

檢查 NAS 日誌文件：
```bash
# 使用 check-logs-exist.sh 檢查 NAS 日誌
cd /Users/user/CLAUDE/workflows/WF-20251224-2-juancash-service-check/scripts
./check-logs-exist.sh
```

## 檢查方法

本報告使用以下命令生成：

```bash
# 檢查部署狀態
kubectl get deployment <service-name> -n jc-prod
kubectl get pods -n jc-prod -l app=<service-name>

# 檢查日誌
kubectl logs -n jc-prod -l app=<service-name> --tail=10 --since=1h

# 檢查錯誤
kubectl logs -n jc-prod -l app=<service-name> --tail=200 --since=1h | \
  grep -ciE "error|exception|fatal"
```

## 建議行動

### 高優先級

1. **調查未部署的服務** (2個)
   - juancash-agentservice
   - juanworld-service-trade-application
   - 確認是否需要部署或已廢棄

2. **調查高錯誤率服務** (3個)
   - juancash-appletservice (154 errors)
   - juanworld-commissionservice (154 errors)
   - juanworld-service-card-application (153 errors)

### 中優先級

3. **驗證日誌輸出方式**
   - 檢查服務是否將日誌寫入 NAS
   - 確認 check-logs-exist.sh 的結果

4. **更新檢查腳本**
   - 將實際部署的服務列表更新到檢查腳本
   - 移除不存在的服務（如 admin-*, scheduler-* 等）

---

**報告生成時間**: 2025-12-24
**下次建議檢查**: 每日執行或部署後執行
