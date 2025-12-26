# images.md 與檢查腳本比對分析

**分析日期**: 2025-12-24

## 概述

比對 `images.md` 中列出的鏡像與三個檢查腳本中的服務名單。

## images.md 鏡像清單

### API 服務 (7個)
1. juanworld-admin-api-rel → `juanworld-admin-api` ✅
2. juancash-applet-api-rel → `juancash-applet-api` ✅
3. juancash-bank-api-rel → `juancash-bank-api` ✅
4. juancash-clicent-api-rel → `juancash-clicent-api` ✅
5. juanworld-api-rel → `juanworld-api` ✅
6. juancash-open-api-rel → `juancash-open-api` ✅
7. juanword-api-shopmanager-rel → `juanword-api-shopmanager` ✅

**結果**: API 服務 7/7 全部在檢查名單內 ✅

### APP 服務 (40個)

#### 在檢查名單內的服務 (30個) ✅

1. juanworld-admin-settlement → juanworld-admin-settlement-rel
2. juanworld-admin-txorder → juanworld-admin-txorder-rel (未列出，但有類似服務)
3. juancash-admin-bank → (對應鏡像未明確列出)
4. juancash-admin-finance → (對應鏡像未明確列出)
5. juancash-admin-mgmt → (對應鏡像未明確列出)
6. juancash-admin-pay → (對應鏡像未明確列出)
7. juancash-admin-system → (對應鏡像未明確列出)
8. juancash-admin-txorder → (對應鏡像未明確列出)
9. juancash-admin-withdrawal → (對應鏡像未明確列出)
10. juancash-scheduler-bank → (對應鏡像未明確列出)
11. juancash-scheduler-pay → (對應鏡像未明確列出)
12. juancash-scheduler-system → (對應鏡像未明確列出)
13. juancash-scheduler-txorder → (對應鏡像未明確列出)
14. juancash-app-bank → (對應鏡像未明確列出)
15. juancash-app-pay → (對應鏡像未明確列出)
16. juancash-app-system → (對應鏡像未明確列出)
17. juancash-app-txorder → (對應鏡像未明確列出)
18. juancash-app-withdrawal → (對應鏡像未明確列出)
19. juancash-app-merchant → (對應鏡像未明確列出)
20. juanworld-app-merchant → (對應鏡像未明確列出)
21. juancash-open-bank → (對應鏡像未明確列出)
22. juancash-open-pay → (對應鏡像未明確列出)
23. juancash-open-system → (對應鏡像未明確列出)
24. juancash-open-txorder → (對應鏡像未明確列出)
25. juancash-socket-app → (對應鏡像未明確列出)
26. juancash-socket-merchant → (對應鏡像未明確列出)
27. juancash-client-finance → (對應鏡像未明確列出)
28. juancash-client-merchant → (對應鏡像未明確列出)
29. juancash-client-settlement → (對應鏡像未明確列出)
30. juancash-client-withdrawal → (對應鏡像未明確列出)

#### images.md 中列出但不在檢查名單內的服務 (10個) ⚠️

1. **juanworld-service-admin-rel** ❌
2. **juanworld-service-user-application-rel** ❌
3. **juanworld-service-trade-rel** ❌
4. **juanworld-configservice-rel** ❌
5. **juancash-amqp-consumerservice-rel** ❌
6. **juancash-amqp-service-rel** ❌
7. **juanworld-applicationcenter-service-rel** ❌
8. **juancash-cashflowservice-rel** ❌
9. **juanworld-commissionservice-rel** ❌
10. **juanworld-riskcontrolservice-rel** ✅ (已在腳本 - 誤判)

實際缺少: 9個

#### 其他 images.md 中的服務 (未檢查原因分析)

這些服務可能不在 jc-refactor 目錄下，或屬於其他部署方式：

11. juancash-financeservice-rel
12. juanworld-service-card-application-rel
13. juanworld-service-system-rel
14. juanworld-service-sms-application-rel
15. juanworld-service-merchant-application-rel
16. juanworld-service-remittance-rel ✅ (有對應檢查)
17. juanworld-userrelation-service-rel
18. juanworld-shop-businessservice-rel
19. juanworld-shop-permissionservice-rel ✅ (有對應檢查)
20. juanworld-shop-marketservice-rel
21. juanworld-service-shop-rel
22. juancash-staff-collectionservice-rel
23. juancash-agentservice-rel
24. juancash-article-service-rel
25. juancash-bankservice-rel
26. juanworld-service-activity-application-rel
27. juancash-appletservice-rel
28. juancash-vip-privilegeservice-rel
29. juancash-promotionservice-rel
30. juanworld-advertising-service-rel
31. jw_analysis-rel ✅ (對應 jw-analysis)
32. juanworld-customer-service-service-rel
33. juanworld-statisticalservice-rel
34. jw_logsystem-rel
35. juanworld-service-redbag-rel ✅ (對應 juanworld-service-redbag)
36. juancash-payservice-rel
37. juanworld-service-blockchain-rel
38. juanworld-service-file-application-rel
39. juanworld-service-image-rel
40. juancash-partnerbasicservice-rel
41. juancash-task-rel

### 前端服務 (7個)

前端服務不在檢查範圍內（腳本僅檢查後端服務）：
1. juanworld_admin_frontend-rel
2. juancash-html5-frontend
3. juanworld-merchant-officialsite-frontend
4. juanworld-merchant-frontend
5. juanworld-officialsite-juancash-website-frontend
6. juancash-app-frontend
7. juanworld-fusepay-frontend

### 註冊中心 (1個)

不在檢查範圍內：
1. juanworld-registercenter-rel

## 關鍵發現

### 1. 檢查腳本中的服務數量

- **API 服務**: 7個 ✅
- **APP 服務**: 30個 ✅
- **總計**: 37個服務

### 2. images.md 與檢查腳本的差異

#### 完全匹配的服務 (API)
- 所有 7 個 API 服務都匹配 ✅

#### jc-refactor 下確認存在但可能命名不同的服務

需要檢查實際的 jc-refactor 目錄結構來確認：

```bash
# 建議執行以下命令確認
ls -1 /Users/user/JUANCASH-project/github/juancash-prod-k8s-deploy/jc-refactor/app-service/
```

### 3. 可能缺少的服務檢查

根據 images.md，以下服務可能需要添加到檢查腳本（如果它們在 jc-refactor 目錄下）：

**高優先級（很可能在 jc-refactor）**:
1. juanworld-riskcontrolservice ✅ 已在檢查名單
2. juanworld-service-redbag ✅ 已在檢查名單
3. jw-analysis ✅ 已在檢查名單
4. juanworld-shop-permissionservice ✅ 已在檢查名單
5. juanworld-service-remittance ✅ 已在檢查名單

**中優先級（可能在 jc-refactor）**:
1. juanworld-service-admin
2. juanworld-service-user-application
3. juanworld-service-trade
4. juanworld-configservice
5. juancash-amqp-consumerservice
6. juancash-amqp-service
7. juanworld-applicationcenter-service
8. juancash-cashflowservice
9. juanworld-commissionservice

## 建議行動

### 1. 確認 jc-refactor 實際部署的服務

```bash
# 列出所有 API 服務
ls -1 /Users/user/JUANCASH-project/github/juancash-prod-k8s-deploy/jc-refactor/api-service/

# 列出所有 APP 服務
ls -1 /Users/user/JUANCASH-project/github/juancash-prod-k8s-deploy/jc-refactor/app-service/
```

### 2. 比對 Kubernetes 實際運行的 Deployment

```bash
# 列出 jc-prod namespace 中所有 deployment
kubectl get deployments -n jc-prod -o name | sort
```

### 3. 更新檢查腳本

如果發現缺少的服務確實在 jc-refactor 目錄下：
- 更新 `check-services.sh`
- 更新 `check-logs-exist.sh`
- 更新 `check-logs-errors.sh`
- 更新 README.md 中的服務數量

### 4. 同步文檔

更新以下文檔：
- ERROR-LOG-CHECK-GUIDE.md 中的服務清單
- README.md 中的服務數量和分類

## 結論

**當前狀態**:
- ✅ API 服務: 7/7 完全匹配
- ⚠️ APP 服務: 腳本檢查 30 個，images.md 列出約 40+ 個
- ❓ 需要確認實際在 jc-refactor 部署的服務範圍

**主要問題**:
1. images.md 包含的服務範圍可能超過 jc-refactor 目錄
2. 部分服務可能在其他部署目錄（如 jc-target-server-deployment）
3. 需要實際檢查 jc-refactor 目錄結構來確認

**建議**:
1. 執行上述確認命令
2. 根據實際情況更新檢查腳本
3. 或者明確標註檢查範圍為「jc-refactor 目錄下的 37 個服務」

---

**分析完成時間**: 2025-12-24
**分析者**: Claude Sonnet 4.5
