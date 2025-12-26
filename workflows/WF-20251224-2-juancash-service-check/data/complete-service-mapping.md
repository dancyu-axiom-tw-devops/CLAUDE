# JC-Refactor 完整服務對應表

**生成日期**: 2025-12-24
**數據來源**: 掃描 juancash-prod-k8s-deploy 下所有部署文件

## 完整服務列表（按 images.md 順序）

| # | 服務類別 | 鏡像名 | 服務名 | Deployment 名稱 | 腳本目錄 | 在檢查腳本 |
|---|---------|--------|--------|----------------|---------|-----------|
| **註冊中心** | | | | | | |
| 1 | 註冊中心 | juanworld-registercenter-rel | registercenter | registercenter | jc-refactor/app-service/registercenter | ❌ |
| **APP 服務** | | | | | | |
| 2 | APP | juanworld-service-admin-rel | juanworld-service-admin | juanworld-service-admin | jc-refactor/app-service/juanworld-service-admin | ❌ |
| 3 | APP | juanworld-service-user-application-rel | juanworld-service-user-application | juanworld-service-user-application | jc-refactor/app-service/juanworld-service-user-application | ❌ |
| 4 | APP | juanworld-service-trade-rel | juanworld-service-trade-application | juanworld-service-trade-application | jc-refactor/app-service/juanworld-service-trade-application | ❌ |
| 5 | APP | juanworld-configservice-rel | juanworld-configservice | juanworld-configservice | jc-refactor/app-service/juanworld-configservice | ❌ |
| 6 | APP | juancash-amqp-consumerservice-rel | juancash-amqp-consumerservice | juancash-amqp-consumerservice | jc-refactor/app-service/juancash-amqp-consumerservice | ❌ |
| 7 | APP | juancash-amqp-service-rel | juancash-amqp | juancash-amqp | jc-refactor/app-service/juancash-amqp | ❌ |
| 8 | APP | juanworld-applicationcenter-service-rel | juanworld-applicationcenter-service | juanworld-applicationcenter-service | jc-refactor/app-service/juanworld-applicationcenter-service | ❌ |
| 9 | APP | juancash-cashflowservice-rel | juancash-cashflowservice | juancash-cashflowservice | jc-refactor/app-service/juancash-cashflowservice | ❌ |
| 10 | APP | juanworld-commissionservice-rel | juanworld-commissionservice | juanworld-commissionservice | jc-refactor/app-service/juanworld-commissionservice | ❌ |
| 11 | APP | juanworld-riskcontrolservice-rel | juanworld-riskcontrolservice | juanworld-riskcontrolservice | jc-refactor/app-service/juanworld-riskcontrolservice | ❌ |
| 12 | APP | juancash-financeservice-rel | juancash-financeservice | juancash-financeservice | jc-refactor/app-service/juancash-financeservice | ❌ |
| 13 | APP | juanworld-service-card-application-rel | juanworld-service-card-application | juanworld-service-card-application | jc-refactor/app-service/juanworld-service-card-application | ❌ |
| 14 | APP | juanworld-service-system-rel | juanworld-service-system | juanworld-service-system | jc-refactor/app-service/juanworld-service-system | ❌ |
| 15 | APP | juanworld-service-sms-application-rel | juanworld-service-sms-application | juanworld-service-sms-application | jc-refactor/app-service/juanworld-service-sms-application | ❌ |
| 16 | APP | juanworld-service-merchant-application-rel | juanworld-service-merchant-application | juanworld-service-merchant-application | jc-refactor/app-service/juanworld-service-merchant-application | ❌ |
| 17 | APP | juanworld-service-remittance-rel | juanworld-service-remittance | juanworld-service-remittance | jc-refactor/app-service/juanworld-service-remittance | ❌ |
| 18 | APP | juanworld-userrelation-service-rel | juanworld-userrelation-service | juanworld-userrelation-service | jc-refactor/app-service/juanworld-userrelation-service | ❌ |
| 19 | APP | juanworld-shop-businessservice-rel | juanworld-shop-businessservice | juanworld-shop-businessservice | jc-refactor/app-service/juanworld-shop-businessservice | ❌ |
| 20 | APP | juanworld-shop-permissionservice-rel | juanworld-shop-permissionservice | juanworld-shop-permissionservice | jc-refactor/app-service/juanworld-shop-permissionservice | ❌ |
| 21 | APP | juanworld-shop-marketservice-rel | juanworld-shop-marketservice | juanworld-shop-marketservice | jc-refactor/app-service/juanworld-shop-marketservice | ❌ |
| 22 | APP | juanworld-service-shop-rel | juanworld-service-shop | juanworld-service-shop | jc-refactor/app-service/juanworld-service-shop | ❌ |
| 23 | APP | juancash-staff-collectionservice-rel | juancash-staff-collectionservice | juancash-staff-collectionservice | jc-target-server-deployment/app-service/juancash-staff-collectionservice-rel | ❌ |
| 24 | APP | juancash-agentservice-rel | juancash-agentservice | juancash-agentservice | jc-refactor/app-service/juancash-agentservice | ❌ |
| 25 | APP | juancash-article-service-rel | juancash-article-service | juancash-article-service | jc-target-server-deployment/app-service/juancash-article-service-rel | ❌ |
| 26 | APP | juancash-bankservice-rel | juancash-bankservice | juancash-bankservice | jc-refactor/app-service/juancash-bankservice | ❌ |
| 27 | APP | juanworld-service-activity-application-rel | juanworld-service-activity-application | juanworld-service-activity-application | jc-target-server-deployment/app-service/juanworld-service-activity-application-rel | ❌ |
| 28 | APP | juancash-appletservice-rel | juancash-appletservice | juancash-appletservice | jc-refactor/app-service/juancash-appletservice | ❌ |
| 29 | APP | juancash-vip-privilegeservice-rel | juancash-vip-privilegeservice | juancash-vip-privilegeservice | jc-target-server-deployment/app-service/juancash-vip-privilegeservice-rel | ❌ |
| 30 | APP | juancash-promotionservice-rel | juancash-promotionservice | juancash-promotionservice | jc-target-server-deployment/app-service/juancash-promotionservice-rel | ❌ |
| 31 | APP | juanworld-advertising-service-rel | juanworld-advertising-service | juanworld-advertising-service | jc-target-server-deployment/app-service/juanworld-advertising-service-rel | ❌ |
| 32 | APP | jw_analysis-rel | jw-analysis | jw-analysis | jc-refactor/app-service/jw-analysis | ❌ |
| 33 | APP | juanworld-customer-service-service-rel | juanworld-customer-service | juanworld-customer-service | jc-refactor/app-service/juanworld-customer-service | ❌ |
| 34 | APP | juanworld-statisticalservice-rel | juanworld-statisticalservice | juanworld-statisticalservice | jc-refactor/app-service/juanworld-statisticalservice | ❌ |
| 35 | APP | jw_logsystem-rel | jw-logsystem | jw-logsystem | jc-refactor/app-service/jw-logsystem | ❌ |
| 36 | APP | juanworld-service-redbag-rel | juanworld-service-redbag | juanworld-service-redbag | jc-refactor/app-service/juanworld-service-redbag | ❌ |
| 37 | APP | juancash-payservice-rel | juancash-payservice | juancash-payservice | jc-target-server-deployment/app-service/juancash-payservice-rel | ❌ |
| 38 | APP | juanworld-service-blockchain-rel | - | - | ❌ 未找到部署文件 | ❌ |
| 39 | APP | juanworld-service-file-application-rel | juanworld-service-file | juanworld-service-file | jc-refactor/app-service/juanworld-service-file | ❌ |
| 40 | APP | juanworld-service-image-rel | juanworld-service-image | juanworld-service-image | jc-refactor/app-service/juanworld-service-image | ❌ |
| 41 | APP | juancash-partnerbasicservice-rel | juancash-partnerbasicservice | juancash-partnerbasicservice | jc-target-server-deployment/app-service/juancash-partnerbasicservice-rel | ❌ |
| 42 | APP | juancash-task-rel | juancash-task | juancash-task | jc-target-server-deployment/app-service/juancash-task-rel | ❌ |
| **API 服務** | | | | | | |
| 43 | API | juanworld-admin-api-rel | juanworld-admin-api | juanworld-admin-api | jc-refactor/api-service/juanworld-admin-api | ✅ |
| 44 | API | juancash-applet-api-rel | juancash-applet-api | juancash-applet-api | jc-refactor/api-service/juancash-applet-api | ✅ |
| 45 | API | juancash-bank-api-rel | juancash-bank-api | juancash-bank-api | jc-refactor/api-service/juancash-bank-api | ✅ |
| 46 | API | juancash-clicent-api-rel | juancash-clicent-api | juancash-clicent-api | jc-refactor/api-service/juancash-clicent-api | ✅ |
| 47 | API | juanworld-api-rel | juanworld-api | juanworld-api | jc-refactor/api-service/juanworld-api | ✅ |
| 48 | API | juancash-open-api-rel | juancash-open-api | juancash-open-api | jc-refactor/api-service/juancash-open-api | ✅ |
| 49 | API | juanword-api-shopmanager-rel | juanword-api-shopmanager | juanword-api-shopmanager | jc-refactor/api-service/juanword-api-shopmanager | ✅ |
| **前端服務** | | | | | | |
| 50 | Frontend | juanworld_admin_frontend-rel | - | - | 前端不檢查 | ❌ |
| 51 | Frontend | juancash-html5-frontend | - | - | 前端不檢查 | ❌ |
| 52 | Frontend | juanworld-merchant-officialsite-frontend | - | - | 前端不檢查 | ❌ |
| 53 | Frontend | juanworld-merchant-frontend | - | - | 前端不檢查 | ❌ |
| 54 | Frontend | juanworld-officialsite-juancash-website-frontend | - | - | 前端不檢查 | ❌ |
| 55 | Frontend | juancash-app-frontend | - | - | 前端不檢查 | ❌ |
| 56 | Frontend | juanworld-fusepay-frontend | - | - | 前端不檢查 | ❌ |

## 統計摘要

### images.md 總計
- 註冊中心: 1
- APP 服務: 41
- API 服務: 7
- 前端服務: 7
- **總計**: 56

### 實際部署位置分布

#### jc-refactor 目錄 (40個)
- 註冊中心: 1
- APP: 32
- API: 7

#### jc-target-server-deployment 目錄 (8個)
1. juancash-staff-collectionservice-rel
2. juancash-article-service-rel
3. juanworld-service-activity-application-rel
4. juancash-vip-privilegeservice-rel
5. juancash-promotionservice-rel
6. juanworld-advertising-service-rel
7. juancash-payservice-rel
8. juancash-partnerbasicservice-rel
9. juancash-task-rel

#### 未找到 (1個)
- juanworld-service-blockchain-rel ❌

### 檢查腳本涵蓋率

**目前腳本檢查的服務**:
- ✅ API 服務: 7/7 (100%)
- ❌ APP 服務: 0/41 (0%)
- ❌ 註冊中心: 0/1 (0%)

**問題**: 腳本中使用的 APP 服務名稱（如 `juancash-admin-bank`, `juancash-scheduler-pay`）與實際部署的服務名稱完全不符！

## Deployment 名稱規律

根據掃描結果，**Deployment 名稱 = 服務名 = 目錄名**（移除 -rel 後綴）

例如：
- 目錄: `jc-refactor/app-service/juancash-cashflowservice`
- 服務名: `juancash-cashflowservice`
- Deployment: `juancash-cashflowservice`
- 鏡像名: `juancash-cashflowservice-rel`

**特例**:
- 目錄: `juanworld-service-trade-application`
- 鏡像名: `juanworld-service-trade-rel` (不含 -application)

## 應該檢查的完整服務列表

### 註冊中心 (1)
```
registercenter
```

### API 服務 (7)
```
juancash-applet-api
juancash-bank-api
juancash-clicent-api
juancash-open-api
juanword-api-shopmanager
juanworld-admin-api
juanworld-api
```

### APP 服務 (41) - jc-refactor (32個)
```
juancash-agentservice
juancash-amqp
juancash-amqp-consumerservice
juancash-appletservice
juancash-bankservice
juancash-cashflowservice
juancash-financeservice
juanworld-applicationcenter-service
juanworld-commissionservice
juanworld-configservice
juanworld-customer-service
juanworld-riskcontrolservice
juanworld-service-admin
juanworld-service-card-application
juanworld-service-file
juanworld-service-image
juanworld-service-merchant-application
juanworld-service-redbag
juanworld-service-remittance
juanworld-service-shop
juanworld-service-sms-application
juanworld-service-system
juanworld-service-trade-application
juanworld-service-user-application
juanworld-shop-businessservice
juanworld-shop-marketservice
juanworld-shop-permissionservice
juanworld-statisticalservice
juanworld-userrelation-service
jw-analysis
jw-logsystem
```

### APP 服務 - jc-target-server-deployment (8個)
```
juancash-article-service
juancash-partnerbasicservice
juancash-payservice
juancash-promotionservice
juancash-staff-collectionservice
juancash-task
juancash-vip-privilegeservice
juanworld-advertising-service
juanworld-service-activity-application
```

## 建議行動

### 1. 更新檢查腳本服務列表

需要更新以下三個腳本：
- `scripts/check-services.sh`
- `scripts/check-logs-exist.sh`
- `scripts/check-logs-errors.sh`

將 APP 服務列表替換為上述完整列表（41個服務）。

### 2. 決定檢查範圍

建議選項：

**選項 A**: 僅檢查 jc-refactor (40個服務)
- 優點: 集中在重構後的服務
- 總數: 1 註冊中心 + 32 APP + 7 API = 40

**選項 B**: 檢查所有 images.md 中的服務 (49個後端服務)
- 優點: 完整涵蓋
- 總數: 1 註冊中心 + 41 APP + 7 API = 49
- 需跨兩個目錄檢查

### 3. 更新文檔

- README.md: 更新服務數量
- ERROR-LOG-CHECK-GUIDE.md: 更新服務清單

---

**生成時間**: 2025-12-24
**生成方式**: 掃描 juancash-prod-k8s-deploy 所有部署目錄
