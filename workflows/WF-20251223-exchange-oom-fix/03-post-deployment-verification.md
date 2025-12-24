# 部署後驗證 - Exchange Service OOM 修復

**目的**: 確保修復配置正確生效，OOM 問題得到解決
**執行時機**: 部署完成後立即執行

## 快速驗證（5 分鐘）

執行自動化驗證腳本：
```bash
cd /Users/user/CLAUDE/workflows/WF-20251223-exchange-oom-fix/script
./verify-deployment.sh
```

腳本會自動檢查：
- Pod 狀態
- HPA 配置
- JVM 參數
- 記憶體使用
- GC 日誌設置

## 詳細驗證步驟

### 1. Pod 狀態驗證

```bash
kubectl get pods -n forex-prod -l app=exchange-service -o wide
```

**預期結果**:
```
NAME                               READY   STATUS    RESTARTS   AGE   IP          NODE
exchange-service-xxxxxxxxx-xxxxx   1/1     Running   0          5m    10.x.x.x    node-1
exchange-service-xxxxxxxxx-xxxxx   1/1     Running   0          4m    10.x.x.x    node-2
```

**檢查點**:
- ✅ 數量: 2 個 Pod
- ✅ READY: 1/1
- ✅ STATUS: Running
- ✅ RESTARTS: 0
- ✅ AGE: 最近幾分鐘
- ✅ 分散在不同節點（高可用）

**異常處理**:
- Pod 數量 ≠ 2 → 檢查 HPA 和 Deployment replicas
- STATUS ≠ Running → 檢查 Pod events 和 logs
- RESTARTS > 0 → 檢查 Pod logs，可能有啟動問題

### 2. Deployment 狀態驗證

```bash
kubectl get deployment exchange-service -n forex-prod
```

**預期結果**:
```
NAME               READY   UP-TO-DATE   AVAILABLE   AGE
exchange-service   2/2     2            2           xxx
```

**檢查點**:
- ✅ READY: 2/2
- ✅ UP-TO-DATE: 2（所有 Pod 都是最新版本）
- ✅ AVAILABLE: 2

```bash
kubectl describe deployment exchange-service -n forex-prod | grep -A 5 "RollingUpdateStrategy"
```

**預期結果**:
```
RollingUpdateStrategy:  1 max surge, 0 max unavailable
```

**檢查點**:
- ✅ maxSurge: 1
- ✅ maxUnavailable: 0

### 3. HPA 狀態驗證

```bash
kubectl get hpa exchange-service-hpa -n forex-prod
```

**預期結果**:
```
NAME                    REFERENCE                     TARGETS         MINPODS   MAXPODS   REPLICAS
exchange-service-hpa    Deployment/exchange-service   30%/70%, 45%/75%   2         10        2
```

**檢查點**:
- ✅ TARGETS: 顯示實際百分比（不是 <unknown>）
- ✅ MINPODS: 2
- ✅ MAXPODS: 10
- ✅ REPLICAS: 2（或更多，視負載）

**詳細檢查**:
```bash
kubectl describe hpa exchange-service-hpa -n forex-prod
```

**預期在 Conditions 中看到**:
```
Conditions:
  Type            Status  Reason            Message
  ----            ------  ------            -------
  AbleToScale     True    ReadyForNewScale  ready to scale
  ScalingActive   True    ValidMetricFound  the HPA was able to successfully calculate a replica count
  ScalingLimited  False   DesiredWithinRange  the desired count is within the acceptable range
```

**檢查點**:
- ✅ AbleToScale: True
- ✅ ScalingActive: True
- ✅ 看到 "successfully calculate a replica count"

**Events 檢查**:
```
Events:
  Type    Reason             Age   From                       Message
  ----    ------             ----  ----                       -------
  Normal  SuccessfulRescale  5m    horizontal-pod-autoscaler  New size: 2; reason: Current number of replicas below Spec.MinReplicas
```

**檢查點**:
- ✅ 看到 SuccessfulRescale 從 1 → 2

**異常處理**:
- TARGETS 顯示 <unknown> → Metrics Server 問題
  ```bash
  kubectl get apiservice v1beta1.metrics.k8s.io -o yaml
  kubectl get deployment metrics-server -n kube-system
  ```
- ScalingActive: False → 檢查 HPA Events，可能是 metrics 獲取失敗

### 4. JVM 參數驗證

```bash
kubectl exec -it -n forex-prod deployment/exchange-service -- env | grep ARGS1
```

**預期結果**:
```
ARGS1=-Xms3072m -Xmx4096m -XX:MetaspaceSize=256m -XX:MaxMetaspaceSize=512m -XX:+UseG1GC -XX:MaxGCPauseMillis=200 -XX:ParallelGCThreads=4 -XX:ConcGCThreads=2 -XX:InitiatingHeapOccupancyPercent=45 -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=/forex/log/exchange-service/ -XX:+PrintGCDetails -XX:+PrintGCDateStamps -Xloggc:/forex/log/exchange-service/gc.log -XX:+UseContainerSupport
```

**檢查點**:
- ✅ `-Xms3072m`（初始 heap 3GB）
- ✅ `-Xmx4096m`（最大 heap 4GB）
- ✅ `-XX:+UseG1GC`（使用 G1 GC）
- ✅ `-XX:MaxGCPauseMillis=200`（目標暫停 200ms）
- ✅ `-XX:+HeapDumpOnOutOfMemoryError`（OOM 時 dump）
- ✅ `-XX:HeapDumpPath=/forex/log/exchange-service/`（dump 路徑）
- ✅ `-Xloggc:/forex/log/exchange-service/gc.log`（GC 日誌）

**使用 jinfo 驗證**（可選）:
```bash
# 獲取 Java 進程 PID
kubectl exec -it -n forex-prod deployment/exchange-service -- ps aux | grep java

# 查看 JVM flags（替換 <PID>）
kubectl exec -it -n forex-prod deployment/exchange-service -- jinfo -flags <PID>
```

**異常處理**:
- 如參數不正確 → Secret 可能未更新
  ```bash
  kubectl get secret exchange-service-env -n forex-prod -o jsonpath='{.data.ARGS1}' | base64 -d
  ```

### 5. 記憶體使用驗證

```bash
kubectl top pods -n forex-prod -l app=exchange-service
```

**預期結果**:
```
NAME                               CPU(cores)   MEMORY(bytes)
exchange-service-xxxxxxxxx-xxxxx   100m         3500Mi
exchange-service-xxxxxxxxx-xxxxx   100m         3500Mi
```

**檢查點**:
- ✅ 記憶體使用: 3-4.5GB（符合 Xms 3GB 預期）
- ✅ 記憶體 < 5GB（安全閾值）
- ✅ 記憶體 < 5.5GB（警告閾值）
- ✅ 記憶體 < 6GB（limit）

**對比修改前**:
- 修改前: 啟動時 ~1GB，逐步增長到 3-4GB（頻繁 GC）
- 修改後: 啟動時直接 ~3.5GB，穩定（Xms 立即分配）

**趨勢監控**:
```bash
# 每分鐘記錄一次，持續 10 分鐘
for i in {1..10}; do
  echo "=== $(date) ==="
  kubectl top pods -n forex-prod -l app=exchange-service
  sleep 60
done
```

**預期**:
- 記憶體使用穩定在 3.5-4.5GB
- 無異常增長趨勢

**異常處理**:
- 記憶體 > 5.5GB → 可能有內存洩漏，檢查 heap dump
- 記憶體持續增長 → 監控 GC 日誌，可能需要調整參數

### 6. GC 日誌驗證

```bash
# 檢查 GC 日誌文件存在
kubectl exec -it -n forex-prod deployment/exchange-service -- ls -lh /forex/log/exchange-service/gc.log
```

**預期結果**:
```
-rw-r--r-- 1 app app 1.2K Dec 23 14:00 /forex/log/exchange-service/gc.log
```

**檢查點**:
- ✅ 文件存在
- ✅ 有寫入權限（app 用戶可寫）
- ✅ 文件大小 > 0

**查看 GC 日誌內容**:
```bash
kubectl exec -it -n forex-prod deployment/exchange-service -- tail -50 /forex/log/exchange-service/gc.log
```

**預期看到**:
```
2025-12-23T14:00:00.123+0800: 1.234: [GC pause (G1 Evacuation Pause) (young), 0.0234567 secs]
   [Parallel Time: 18.5 ms, GC Workers: 4]
   ...
2025-12-23T14:00:05.456+0800: 6.789: [GC pause (G1 Evacuation Pause) (young), 0.0198765 secs]
   ...
```

**檢查點**:
- ✅ 看到 "G1 Evacuation Pause"（確認使用 G1GC）
- ✅ 暫停時間 < 0.2 秒（200ms 目標）
- ✅ 有時間戳（PrintGCDateStamps）
- ✅ 有詳細信息（PrintGCDetails）

**GC 頻率檢查**:
```bash
# 統計最近 GC 次數
kubectl exec -it -n forex-prod deployment/exchange-service -- grep "GC pause" /forex/log/exchange-service/gc.log | wc -l
```

**預期**:
- 啟動後 10 分鐘內: 10-50 次 GC（正常）
- 如 > 100 次: 可能 GC 過於頻繁，需調整參數

### 7. Heap Dump 配置驗證

```bash
# 檢查 heap dump 目錄權限
kubectl exec -it -n forex-prod deployment/exchange-service -- ls -ld /forex/log/exchange-service/
```

**預期結果**:
```
drwxrwxr-x 2 app app 4096 Dec 23 14:00 /forex/log/exchange-service/
```

**檢查點**:
- ✅ 目錄存在
- ✅ app 用戶有寫權限（rwx）

**注意**: Heap dump 只在 OOM 時生成，現在應該不存在 `.hprof` 文件

**如果已有 heap dump**（表示曾 OOM）:
```bash
kubectl exec -it -n forex-prod deployment/exchange-service -- ls -lh /forex/log/exchange-service/*.hprof
```

如存在 → 表示部署前曾 OOM，檔案可用於分析

### 8. 事件檢查

```bash
kubectl get events -n forex-prod --field-selector involvedObject.name=exchange-service --sort-by='.lastTimestamp' | tail -20
```

**不應該看到**:
- ❌ OOMKilled
- ❌ FailedScheduling
- ❌ BackOff

**應該看到**:
- ✅ Scaled up (HPA 調整)
- ✅ Pulled (image pull 成功)
- ✅ Created (容器創建)
- ✅ Started (容器啟動)

**檢查 OOM 歷史**:
```bash
kubectl get events -n forex-prod --field-selector reason=OOMKilling --sort-by='.lastTimestamp' | grep exchange-service
```

**預期**:
- 無最近的 OOM 事件（部署後應該是 0）

### 9. 服務功能驗證

**基礎連通性**:
```bash
kubectl exec -it -n forex-prod deployment/exchange-service -- curl -s localhost:10320/actuator/health || echo "端點可能不存在"
```

**預期**:
- HTTP 200
- `{"status":"UP"}` 或類似響應

**如需外部訪問**:
```bash
kubectl port-forward -n forex-prod deployment/exchange-service 10320:10320 &
curl localhost:10320/actuator/health
```

### 10. 完整性檢查

**一鍵檢查腳本**:
```bash
echo "=== Pod Status ==="
kubectl get pods -n forex-prod -l app=exchange-service

echo -e "\n=== Deployment Status ==="
kubectl get deployment exchange-service -n forex-prod

echo -e "\n=== HPA Status ==="
kubectl get hpa exchange-service-hpa -n forex-prod

echo -e "\n=== Memory Usage ==="
kubectl top pods -n forex-prod -l app=exchange-service

echo -e "\n=== Restart Count ==="
kubectl get pods -n forex-prod -l app=exchange-service -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.containerStatuses[0].restartCount}{"\n"}{end}'

echo -e "\n=== Recent Events ==="
kubectl get events -n forex-prod --field-selector involvedObject.name=exchange-service --sort-by='.lastTimestamp' | tail -10

echo -e "\n=== OOM Events (should be empty) ==="
kubectl get events -n forex-prod --field-selector reason=OOMKilling --sort-by='.lastTimestamp' | grep exchange-service | tail -5 || echo "No OOM events"
```

## 驗證檢查清單

### 立即驗證（部署後 30 分鐘）

- [ ] ✅ 2 個 Pod Running, READY 1/1
- [ ] ✅ Deployment READY 2/2
- [ ] ✅ HPA 正確配置（min 2, max 10）
- [ ] ✅ HPA TARGETS 顯示實際數值（不是 <unknown>）
- [ ] ✅ JVM 參數正確（Xms 3072m, UseG1GC, HeapDumpOnOutOfMemoryError）
- [ ] ✅ 記憶體使用 3-4.5GB（< 5GB）
- [ ] ✅ GC 日誌存在且正常寫入
- [ ] ✅ Heap dump 目錄有寫權限
- [ ] ✅ 無 OOMKilled 事件
- [ ] ✅ 無 Pod 重啟（RESTARTS = 0）
- [ ] ✅ 服務響應正常

### 短期驗證（24 小時）

- [ ] ⏳ 記憶體使用穩定（無異常增長）
- [ ] ⏳ 無 OOM 事件
- [ ] ⏳ 無 Pod 重啟
- [ ] ⏳ HPA 正常工作（如有流量波動）
- [ ] ⏳ GC 日誌顯示暫停時間 < 200ms

### 長期驗證（1 週）

- [ ] ⏳ OOM 頻率大幅降低（目標: 0）
- [ ] ⏳ GC 行為健康（無頻繁 Full GC）
- [ ] ⏳ HPA 擴展歷史正常

## 問題排查

### 問題 1: HPA TARGETS 顯示 <unknown>

**症狀**:
```
TARGETS: <unknown>/<unknown>
```

**原因**: Metrics Server 未運行或配置錯誤

**檢查**:
```bash
kubectl get apiservice v1beta1.metrics.k8s.io -o yaml
kubectl get deployment metrics-server -n kube-system
kubectl top nodes
```

**解決**:
- 如 Metrics Server 不存在 → 需安裝
- 如存在但無法訪問 → 檢查網路和權限

**影響**: HPA 無法自動擴展，但固定 2 replicas 仍可用

### 問題 2: 記憶體使用 > 5.5GB

**症狀**: `kubectl top` 顯示記憶體使用超過 5.5GB

**可能原因**:
1. 內存洩漏
2. Heap 參數不足
3. Direct Memory 或 Native Memory 過高

**排查**:
```bash
# 觸發手動 GC（如 Pod 提供 JMX）
kubectl exec -it -n forex-prod deployment/exchange-service -- jcmd <PID> GC.run

# 檢查 GC 後記憶體
kubectl top pods -n forex-prod -l app=exchange-service
```

**如記憶體仍高**:
- 生成 heap dump 分析:
  ```bash
  kubectl exec -it -n forex-prod deployment/exchange-service -- jmap -dump:format=b,file=/forex/log/exchange-service/manual-heap.hprof <PID>
  ```

- 下載 heap dump 分析（使用 VisualVM 或 Eclipse MAT）

### 問題 3: Pod 頻繁重啟

**症狀**: RESTARTS > 0

**檢查**:
```bash
kubectl logs -n forex-prod <pod-name> --previous
kubectl describe pod -n forex-prod <pod-name>
```

**可能原因**:
- OOM（檢查 events 是否有 OOMKilled）
- 應用錯誤（檢查 logs）
- Liveness probe 失敗（檢查 probe 配置）

## 總結報告模板

```markdown
# Exchange Service OOM 修復 - 驗證報告

**驗證時間**: YYYY-MM-DD HH:MM

## 驗證結果

### Pod 狀態
- 數量: X 個
- 狀態: Running / CrashLoopBackOff / ...
- 重啟次數: X

### HPA 狀態
- 當前副本數: X
- CPU 使用率: X% / 70%
- Memory 使用率: X% / 75%
- Metrics 可用: Yes / No

### JVM 配置
- Xms: X
- Xmx: X
- GC: X
- Heap dump: Enabled / Disabled

### 記憶體使用
- 當前: X GB
- 趨勢: 穩定 / 增長 / 波動

### 問題
- [ ] 無問題
- [ ] 發現問題: <描述>

## 結論
- [ ] ✅ 驗證通過，可進入監控階段
- [ ] ❌ 驗證失敗，需回滾或修正

**負責人**: User + Claude AI
```

---

**文檔版本**: 1.0
**最後更新**: 2025-12-23
