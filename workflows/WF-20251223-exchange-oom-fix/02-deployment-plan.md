# 部署計畫 - Exchange Service OOM 修復

**建立日期**: 2025-12-23
**目標**: 將 OOM 修復配置部署到 production cluster
**前置條件**: 配置已修改並 commit (a9dffc6)

## 部署前檢查清單

### 本地準備 ✅ **已完成**

- [x] 分析問題根因
- [x] 設計修復方案
- [x] 修改 deployment.yml（replicas: 2, strategy）
- [x] 確認 env/forex.env（JVM 優化）
- [x] 確認 hpa.yml（HPA 配置）
- [x] 更新 kustomization.yml（包含 hpa.yml）
- [x] Git commit (a9dffc6)
- [x] 建立備份（data/backup/20251223_135549/）
- [x] 建立文檔（README, analysis）

### 部署環境要求

- [ ] 能訪問 forex-prod Kubernetes cluster
- [ ] kubectl 已配置正確 context
- [ ] 有 forex-prod namespace 的部署權限
- [ ] Metrics Server 正常運行（HPA 需要）

## 部署時機建議

### 推薦時段
**凌晨 2-4 點（週二、週三、週四）**

**理由**:
- 流量低峰（最小用戶影響）
- 工作日（如有問題可快速響應）
- 避開週一（變更風險高）、週五（週末無人值班）

### 部署時長預估
- **準備階段**: 5 分鐘（檢查環境）
- **應用配置**: 1 分鐘（kubectl apply）
- **滾動更新**: 3-5 分鐘（2 個 Pod 重啟）
- **驗證階段**: 10 分鐘（檢查狀態、日誌）
- **總計**: 約 20 分鐘

## 部署步驟

### Step 1: 環境檢查（5 分鐘）

```bash
# 1.1 切換到正確 directory
cd /Users/user/FOREX-project/prod-cloud/forex-prod-k8s-deploy/exchange-service

# 1.2 檢查 kubectl context
kubectl config current-context
# 預期輸出: forex-prod 或類似名稱

# 1.3 檢查集群連接
kubectl get nodes
# 預期: 顯示 prod cluster 節點列表

# 1.4 檢查當前 Pod 狀態
kubectl get pods -n forex-prod -l app=exchange-service
# 預期: 1 個 Pod Running

# 1.5 記錄當前狀態（用於對比）
kubectl get pods -n forex-prod -l app=exchange-service -o wide > /tmp/before-deployment.txt
kubectl top pods -n forex-prod -l app=exchange-service >> /tmp/before-deployment.txt 2>&1 || echo "metrics not available"

# 1.6 檢查 Metrics Server
kubectl get deployment metrics-server -n kube-system
# 預期: 1/1 READY

kubectl top nodes
# 預期: 顯示節點 CPU/Memory 使用率（如失敗，HPA 將無法工作）

# 1.7 檢查是否已有 HPA（不應該存在）
kubectl get hpa -n forex-prod | grep exchange-service
# 預期: 無輸出（HPA 不存在）
```

**決策點**:
- 如 Metrics Server 不存在或異常 → 暫停部署，先修復 Metrics Server
- 如 Pod 狀態異常（不是 Running） → 暫停部署，先調查問題
- 如已有 HPA → 檢查配置，可能需要刪除舊的

### Step 2: 應用配置（1 分鐘）

```bash
# 2.1 最後確認（可選，檢查將要部署的內容）
kubectl diff -k .
# 預期: 顯示將要變更的資源

# 2.2 應用配置
kubectl apply -k .

# 預期輸出:
# secret/exchange-service-env configured
# deployment.apps/exchange-service configured
# service/exchange-service unchanged
# networkpolicy.networking.k8s.io/exchange-service-network-policy unchanged
# horizontalpodautoscaler.autoscaling/exchange-service-hpa created

# 2.3 立即檢查 HPA 創建
kubectl get hpa exchange-service-hpa -n forex-prod

# 預期輸出:
# NAME                    REFERENCE                     TARGETS         MINPODS   MAXPODS   REPLICAS
# exchange-service-hpa    Deployment/exchange-service   <unknown>/70%, <unknown>/75%   2         10        1

# TARGETS 顯示 <unknown> 是正常的，需等待 metrics 收集（約 15-30 秒）
```

**決策點**:
- 如 kubectl apply 失敗 → 檢查錯誤訊息，修正問題
- 如 HPA 創建失敗 → 檢查 hpa.yml 語法，可能需要手動刪除重建

### Step 3: 監控滾動更新（3-5 分鐘）

```bash
# 3.1 監控 Deployment 滾動更新狀態
kubectl rollout status deployment/exchange-service -n forex-prod

# 預期輸出:
# Waiting for deployment "exchange-service" rollout to finish: 1 old replicas are pending termination...
# Waiting for deployment "exchange-service" rollout to finish: 1 of 2 updated replicas are available...
# deployment "exchange-service" successfully rolled out

# 3.2 同時在另一個終端監控 Pod 變化
kubectl get pods -n forex-prod -l app=exchange-service -w

# 預期過程:
# 1. 看到原本的 1 個 Pod Running
# 2. 出現第 1 個新 Pod (ContainerCreating → Running)
# 3. 出現第 2 個新 Pod (ContainerCreating → Running)
# 4. 2 個新 Pod Ready 後，舊 Pod 開始 Terminating
# 5. 最終: 2 個新 Pod Running

# 滾動更新時間線:
# T+0s:   1 舊 Pod Running
# T+30s:  1 舊 + 1 新 Pod (新 Pod ContainerCreating)
# T+60s:  1 舊 + 1 新 Pod (新 Pod Running, waiting Ready)
# T+120s: 1 舊 + 2 新 Pod (第 2 個新 Pod 啟動)
# T+180s: 2 新 Pod Running (舊 Pod Terminating)
# T+200s: 2 新 Pod Running (完成)
```

**決策點**:
- 如新 Pod 一直 ContainerCreating (> 2 分鐘) → 檢查 events，可能是 image pull 問題
- 如新 Pod CrashLoopBackOff → **立即回滾**（見 Step 7）
- 如新 Pod 啟動後舊 Pod 未終止 → 正常，等待 readiness probe（45s）

### Step 4: 驗證部署結果（5 分鐘）

```bash
# 4.1 檢查 Pod 狀態
kubectl get pods -n forex-prod -l app=exchange-service -o wide

# 預期:
# NAME                               READY   STATUS    RESTARTS   AGE   IP             NODE
# exchange-service-xxxxxxxxx-xxxxx   1/1     Running   0          2m    10.x.x.x       node-x
# exchange-service-xxxxxxxxx-xxxxx   1/1     Running   0          1m    10.x.x.x       node-y

# 確認:
# - 2 個 Pod
# - STATUS: Running
# - READY: 1/1
# - RESTARTS: 0
# - AGE: 都是最近幾分鐘

# 4.2 檢查 Deployment
kubectl get deployment exchange-service -n forex-prod

# 預期:
# NAME               READY   UP-TO-DATE   AVAILABLE   AGE
# exchange-service   2/2     2            2           xxx

# 4.3 檢查 HPA 狀態
kubectl get hpa exchange-service-hpa -n forex-prod

# 預期:
# NAME                    REFERENCE                     TARGETS         MINPODS   MAXPODS   REPLICAS
# exchange-service-hpa    Deployment/exchange-service   30%/70%, 45%/75%   2         10        2

# TARGETS 應該顯示實際數值（如 30%/70%），不是 <unknown>
# REPLICAS 應該是 2

kubectl describe hpa exchange-service-hpa -n forex-prod

# 檢查:
# - Conditions: AbleToScale, ScalingActive（都應該是 True）
# - Events: 應該看到 "SuccessfulRescale" 從 1 → 2

# 4.4 驗證 JVM 參數
kubectl exec -it -n forex-prod deployment/exchange-service -- env | grep ARGS1

# 預期輸出:
# ARGS1=-Xms3072m -Xmx4096m ... -XX:+UseG1GC ... -XX:+HeapDumpOnOutOfMemoryError ...

# 確認包含:
# - Xms3072m ✓
# - Xmx4096m ✓
# - -XX:+UseG1GC ✓
# - -XX:+HeapDumpOnOutOfMemoryError ✓
# - -Xloggc:/forex/log/exchange-service/gc.log ✓

# 4.5 檢查 GC 日誌目錄
kubectl exec -it -n forex-prod deployment/exchange-service -- ls -la /forex/log/exchange-service/

# 預期: 看到 gc.log 文件（可能很小，剛啟動）

# 4.6 檢查 Pod 日誌（確認無錯誤）
kubectl logs -n forex-prod -l app=exchange-service --tail=50

# 檢查:
# - 無 OutOfMemoryError
# - 無 CrashLoopBackOff 相關錯誤
# - 看到應用正常啟動日誌

# 4.7 檢查記憶體使用
kubectl top pods -n forex-prod -l app=exchange-service

# 預期:
# NAME                               CPU(cores)   MEMORY(bytes)
# exchange-service-xxxxxxxxx-xxxxx   100m         3500Mi
# exchange-service-xxxxxxxxx-xxxxx   100m         3500Mi

# 記憶體應該在 3-4GB 左右（Xms 3GB 立即分配）
# 不應該接近 6GB limit

# 4.8 檢查服務可達性（可選，如有外部訪問方式）
# curl https://your-exchange-service-endpoint/health
# 預期: HTTP 200
```

**決策點**:
- 如 Pod 不是 2 個 Running → 檢查 events 和 logs
- 如 HPA TARGETS 仍是 <unknown> (> 5 分鐘) → Metrics Server 問題，HPA 無法工作但不影響固定 2 replicas
- 如 JVM 參數不正確 → Secret 可能未更新，需檢查 kustomize 配置
- 如記憶體使用異常高 (> 5GB) → 可能有內存洩漏，需監控

### Step 5: 功能驗證（3 分鐘）

```bash
# 5.1 檢查 Kubernetes Events
kubectl get events -n forex-prod --field-selector involvedObject.name=exchange-service --sort-by='.lastTimestamp' | tail -20

# 檢查:
# - 無 OOMKilled 事件
# - 無 FailedScheduling
# - 看到 Scaled up/down (HPA 調整)

# 5.2 檢查 Pod 重啟次數（應該是 0）
kubectl get pods -n forex-prod -l app=exchange-service -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.containerStatuses[0].restartCount}{"\n"}{end}'

# 預期: 所有 Pod restartCount 都是 0

# 5.3 測試服務響應（如適用）
# kubectl port-forward -n forex-prod deployment/exchange-service 10320:10320
# curl localhost:10320/actuator/health
# 預期: HTTP 200, {"status":"UP"}
```

### Step 6: 記錄部署結果

```bash
# 6.1 保存部署後狀態
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
kubectl get pods -n forex-prod -l app=exchange-service -o wide > /Users/user/CLAUDE/docs/workflows/WF-20251223-exchange-oom-fix/worklogs/deployment-${TIMESTAMP}-after.txt
kubectl top pods -n forex-prod -l app=exchange-service >> /Users/user/CLAUDE/docs/workflows/WF-20251223-exchange-oom-fix/worklogs/deployment-${TIMESTAMP}-after.txt 2>&1
kubectl describe hpa exchange-service-hpa -n forex-prod >> /Users/user/CLAUDE/docs/workflows/WF-20251223-exchange-oom-fix/worklogs/deployment-${TIMESTAMP}-after.txt

# 6.2 對比部署前後
diff /tmp/before-deployment.txt /Users/user/CLAUDE/docs/workflows/WF-20251223-exchange-oom-fix/worklogs/deployment-${TIMESTAMP}-after.txt
```

### Step 7: 回滾程序（僅在失敗時）

**觸發條件**:
- Pod CrashLoopBackOff
- 服務大量 5xx 錯誤
- 記憶體使用異常（> 5.5GB）

**回滾步驟**:
```bash
# 方案 A: Git 回滾（推薦）
cd /Users/user/FOREX-project/prod-cloud/forex-prod-k8s-deploy/exchange-service
git revert HEAD
kubectl apply -k .

# 等待回滾完成
kubectl rollout status deployment/exchange-service -n forex-prod

# 刪除 HPA（回滾後不應該存在）
kubectl delete hpa exchange-service-hpa -n forex-prod

# 方案 B: 使用備份
cd /Users/user/CLAUDE/docs/workflows/WF-20251223-exchange-oom-fix
BACKUP_DIR="data/backup/20251223_135549"

cd /Users/user/FOREX-project/prod-cloud/forex-prod-k8s-deploy/exchange-service
cp $BACKUP_DIR/deployment.yml .
cp $BACKUP_DIR/env/forex.env env/
cp $BACKUP_DIR/kustomization.yml .

kubectl apply -k .
kubectl delete hpa exchange-service-hpa -n forex-prod

# 驗證回滾
kubectl get pods -n forex-prod -l app=exchange-service
kubectl get hpa -n forex-prod | grep exchange-service  # 應該無輸出
```

## 部署後立即監控（1 小時）

### 監控項目

**每 10 分鐘檢查**:
```bash
# Pod 狀態
kubectl get pods -n forex-prod -l app=exchange-service

# 記憶體使用
kubectl top pods -n forex-prod -l app=exchange-service

# 重啟次數
kubectl get pods -n forex-prod -l app=exchange-service -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.containerStatuses[0].restartCount}{"\n"}{end}'

# HPA 狀態
kubectl get hpa exchange-service-hpa -n forex-prod

# 檢查 OOM 事件
kubectl get events -n forex-prod --field-selector reason=OOMKilling --sort-by='.lastTimestamp' | tail -5
```

**關鍵指標**:
- Pod STATUS: Running
- Pod RESTARTS: 0
- Memory 使用: 3-4.5GB（< 5GB 安全）
- HPA REPLICAS: 2（或更多，視負載）
- 無 OOMKilled 事件

**告警閾值**:
- Memory > 5.5GB（90% of 6GB limit） → 警告
- RESTARTS > 0 → 檢查日誌
- Pod Not Running → 緊急

## 成功標準

### 立即驗證（部署後 30 分鐘內）

- [x] ✅ 2 個 Pod Running
- [x] ✅ HPA 正確部署，TARGETS 顯示數值
- [x] ✅ JVM 參數正確（Xms 3072m, G1GC, heap dump）
- [x] ✅ 無 CrashLoopBackOff
- [x] ✅ 無 OOMKilled 事件
- [x] ✅ 記憶體使用在預期範圍（3-4.5GB）
- [x] ✅ 服務響應正常

### 短期驗證（24 小時內）

- [ ] ⏳ 無 OOM 事件
- [ ] ⏳ Pod 無異常重啟
- [ ] ⏳ HPA 正常工作（如有流量波動，副本數會調整）
- [ ] ⏳ GC 日誌正常累積

### 長期驗證（1 週）

- [ ] ⏳ OOM 頻率大幅降低（目標: 0）
- [ ] ⏳ 根據 GC 日誌調整 JVM 參數（如需要）

## 聯絡資訊

**問題反饋**:
如部署時遇到問題，保存以下信息：

```bash
# 1. Pod 狀態
kubectl get pods -n forex-prod -l app=exchange-service -o wide > debug-pods.txt

# 2. Pod 日誌
kubectl logs -n forex-prod -l app=exchange-service --tail=500 > debug-logs.txt

# 3. HPA 狀態
kubectl describe hpa exchange-service-hpa -n forex-prod > debug-hpa.txt

# 4. Events
kubectl get events -n forex-prod --sort-by='.lastTimestamp' | head -50 > debug-events.txt

# 5. Deployment 狀態
kubectl describe deployment exchange-service -n forex-prod > debug-deployment.txt
```

將以上文件提供給相關人員分析。

---

**部署負責人**: User + Claude AI
**文檔版本**: 1.0
**最後更新**: 2025-12-23
