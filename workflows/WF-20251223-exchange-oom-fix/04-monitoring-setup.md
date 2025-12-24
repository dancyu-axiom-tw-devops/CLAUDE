# 監控設置 - Exchange Service OOM 修復

**目的**: 持續監控 exchange-service 記憶體使用與 GC 行為
**時間範圍**: 部署後 24 小時密集監控，1-2 週持續觀察

## 快速啟動

**自動化監控腳本**（推薦）:
```bash
cd /Users/user/CLAUDE/docs/workflows/WF-20251223-exchange-oom-fix/script

# 每 5 分鐘記錄一次，持續 24 小時（288 次）
./monitor-resources.sh 300 288

# 查看即時輸出
tail -f data/monitor-YYYYMMDD_HHMMSS.log
```

## 監控策略

### 階段 1: 密集監控（部署後 1 小時）
**頻率**: 每 5 分鐘
**重點**: 確認配置生效，無異常

### 階段 2: 短期監控（部署後 24 小時）
**頻率**: 每 10-15 分鐘
**重點**: 記憶體穩定性，GC 行為，HPA 擴展

### 階段 3: 長期監控（1-2 週）
**頻率**: 每小時或每天檢查
**重點**: OOM 事件趨勢，性能基準

## 監控指標

### 1. Pod 狀態監控

**命令**:
```bash
kubectl get pods -n forex-prod -l app=exchange-service -o wide
```

**監控項**:
- Pod 數量（應該 >= 2）
- STATUS（應該是 Running）
- RESTARTS（應該是 0 或增長緩慢）
- AGE（檢測是否有重啟）
- NODE（檢查 Pod 分布）

**告警條件**:
- Pod 數量 < 2
- STATUS ≠ Running
- RESTARTS 增加（表示 Pod 重啟）

### 2. 記憶體使用監控

**命令**:
```bash
kubectl top pods -n forex-prod -l app=exchange-service
```

**監控項**:
- 當前記憶體使用（MB）
- 記憶體使用率（相對 6GB limit）
- 記憶體趨勢（穩定 / 增長 / 波動）

**正常範圍**:
- 啟動後: 3000-3500 MB（Xms 3GB 立即分配）
- 穩態: 3500-4500 MB
- 峰值: < 5500 MB（< 90% of 6GB limit）

**告警閾值**:
- ⚠️ 警告: > 5000 MB（> 81% of 6GB）
- 🔴 嚴重: > 5500 MB（> 90% of 6GB）
- 🚨 緊急: > 5900 MB（> 96% of 6GB）

**監控腳本**:
```bash
#!/bin/bash
# memory-alert.sh

while true; do
  MEMORY=$(kubectl top pods -n forex-prod -l app=exchange-service --no-headers | awk '{sum+=$3} END {print sum}' | sed 's/Mi//')

  if [ "$MEMORY" -gt 5900 ]; then
    echo "🚨 CRITICAL: Memory usage ${MEMORY}Mi > 5900Mi"
    # 發送告警（email, Slack, etc.）
  elif [ "$MEMORY" -gt 5500 ]; then
    echo "🔴 SEVERE: Memory usage ${MEMORY}Mi > 5500Mi"
  elif [ "$MEMORY" -gt 5000 ]; then
    echo "⚠️  WARNING: Memory usage ${MEMORY}Mi > 5000Mi"
  else
    echo "✅ OK: Memory usage ${MEMORY}Mi"
  fi

  sleep 300  # 每 5 分鐘檢查
done
```

### 3. HPA 行為監控

**命令**:
```bash
kubectl get hpa exchange-service-hpa -n forex-prod
```

**監控項**:
- TARGETS（CPU% / Memory%）
- REPLICAS（當前副本數）
- 擴展歷史（Events）

**正常行為**:
- TARGETS 正常顯示（不是 <unknown>）
- REPLICAS 在 2-10 之間
- 根據負載自動調整

**查看擴展歷史**:
```bash
kubectl describe hpa exchange-service-hpa -n forex-prod | grep -A 10 Events
```

**預期**:
- 看到 SuccessfulRescale 事件（如有流量波動）
- 擴展邏輯合理（CPU/Memory 達閾值才擴展）

### 4. OOM 事件監控

**命令**:
```bash
kubectl get events -n forex-prod --field-selector reason=OOMKilling --sort-by='.lastTimestamp' | grep exchange-service
```

**監控項**:
- OOMKilled 事件數量
- 最近 OOM 時間

**目標**:
- 部署後 24 小時: 0 次 OOM
- 部署後 1 週: 0 次 OOM

**如發生 OOM**:
1. 立即檢查 heap dump:
   ```bash
   kubectl exec -it -n forex-prod deployment/exchange-service -- ls -lh /forex/log/exchange-service/*.hprof
   ```

2. 下載 heap dump 分析:
   ```bash
   kubectl cp forex-prod/<pod-name>:/forex/log/exchange-service/java_pid*.hprof ./heap-dump.hprof
   ```

3. 使用 Eclipse MAT 或 VisualVM 分析

### 5. GC 日誌監控

**查看 GC 日誌**:
```bash
kubectl exec -it -n forex-prod deployment/exchange-service -- tail -100 /forex/log/exchange-service/gc.log
```

**監控項**:
- GC 類型（Young GC / Mixed GC / Full GC）
- GC 頻率
- GC 暫停時間
- Heap 使用情況

**關鍵指標**:

#### Young GC (G1 Evacuation Pause - young)
- **頻率**: 每分鐘 0-5 次（正常）
- **暫停時間**: < 100ms（目標 <200ms）
- **示例**:
  ```
  2025-12-23T14:00:00.123+0800: [GC pause (G1 Evacuation Pause) (young), 0.0234567 secs]
  ```

#### Mixed GC (G1 Evacuation Pause - mixed)
- **頻率**: 每 10-30 分鐘一次（視負載）
- **暫停時間**: < 200ms
- **示例**:
  ```
  2025-12-23T14:10:00.456+0800: [GC pause (G1 Evacuation Pause) (mixed), 0.1234567 secs]
  ```

#### Full GC
- **頻率**: **應該極少發生**（每天 < 1 次，最好 0）
- **暫停時間**: 未知（可能數秒）
- **示例**:
  ```
  2025-12-23T14:20:00.789+0800: [Full GC (Allocation Failure), 5.1234567 secs]
  ```
- **⚠️ 如發生 Full GC**: 需調整 JVM 參數或增加 heap

**GC 統計腳本**:
```bash
# gc-stats.sh
POD=$(kubectl get pods -n forex-prod -l app=exchange-service -o jsonpath='{.items[0].metadata.name}')

echo "=== GC Statistics ==="
kubectl exec -it -n forex-prod $POD -- grep "GC pause" /forex/log/exchange-service/gc.log | tail -100 > /tmp/gc-recent.log

echo "Young GC count: $(grep "young" /tmp/gc-recent.log | wc -l)"
echo "Mixed GC count: $(grep "mixed" /tmp/gc-recent.log | wc -l)"
echo "Full GC count: $(grep "Full GC" /tmp/gc-recent.log | wc -l)"

echo -e "\nAverage pause time (last 100 GCs):"
grep "GC pause" /tmp/gc-recent.log | awk '{print $NF}' | sed 's/\[//' | sed 's/\]//' | sed 's/secs//' | awk '{sum+=$1; count++} END {print sum/count " seconds"}'

echo -e "\nMax pause time:"
grep "GC pause" /tmp/gc-recent.log | awk '{print $NF}' | sed 's/\[//' | sed 's/\]//' | sed 's/secs//' | sort -n | tail -1
```

### 6. Pod 重啟監控

**命令**:
```bash
kubectl get pods -n forex-prod -l app=exchange-service -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.containerStatuses[0].restartCount}{"\n"}{end}'
```

**監控項**:
- 每個 Pod 的重啟次數
- 重啟趨勢

**目標**:
- 部署後 24 小時: 0 次重啟
- 如有重啟: 檢查原因（OOM / 應用錯誤 / liveness probe 失敗）

**檢查重啟原因**:
```bash
kubectl describe pod -n forex-prod <pod-name> | grep -A 20 "Last State"
```

### 7. 完整監控腳本

**保存為** `/Users/user/CLAUDE/docs/workflows/WF-20251223-exchange-oom-fix/script/monitor-resources.sh`:

```bash
#!/bin/bash
# monitor-resources.sh
# Usage: ./monitor-resources.sh [interval_seconds] [count]
# Example: ./monitor-resources.sh 300 288  # 每 5 分鐘，持續 24 小時

INTERVAL=${1:-300}  # 默認 5 分鐘
COUNT=${2:-288}     # 默認 288 次（24 小時）
NAMESPACE="forex-prod"
APP="exchange-service"
LOGFILE="monitor-$(date +%Y%m%d_%H%M%S).log"

echo "Starting monitoring: interval=${INTERVAL}s, count=${COUNT}"
echo "Log file: ${LOGFILE}"

for i in $(seq 1 $COUNT); do
  echo "====================================" | tee -a $LOGFILE
  echo "Monitor #${i} - $(date)" | tee -a $LOGFILE
  echo "====================================" | tee -a $LOGFILE

  # Pod 狀態
  echo -e "\n--- Pod Status ---" | tee -a $LOGFILE
  kubectl get pods -n $NAMESPACE -l app=$APP | tee -a $LOGFILE

  # 記憶體使用
  echo -e "\n--- Memory Usage ---" | tee -a $LOGFILE
  kubectl top pods -n $NAMESPACE -l app=$APP 2>&1 | tee -a $LOGFILE

  # 總記憶體
  TOTAL_MEMORY=$(kubectl top pods -n $NAMESPACE -l app=$APP --no-headers 2>/dev/null | awk '{sum+=$3} END {print sum}' | sed 's/Mi//')
  if [ ! -z "$TOTAL_MEMORY" ]; then
    echo "Total Memory: ${TOTAL_MEMORY}Mi" | tee -a $LOGFILE

    # 告警檢查
    if [ "$TOTAL_MEMORY" -gt 5900 ]; then
      echo "🚨 CRITICAL: Memory usage ${TOTAL_MEMORY}Mi > 5900Mi" | tee -a $LOGFILE
    elif [ "$TOTAL_MEMORY" -gt 5500 ]; then
      echo "🔴 SEVERE: Memory usage ${TOTAL_MEMORY}Mi > 5500Mi" | tee -a $LOGFILE
    elif [ "$TOTAL_MEMORY" -gt 5000 ]; then
      echo "⚠️  WARNING: Memory usage ${TOTAL_MEMORY}Mi > 5000Mi" | tee -a $LOGFILE
    else
      echo "✅ OK: Memory usage ${TOTAL_MEMORY}Mi" | tee -a $LOGFILE
    fi
  fi

  # HPA 狀態
  echo -e "\n--- HPA Status ---" | tee -a $LOGFILE
  kubectl get hpa ${APP}-hpa -n $NAMESPACE 2>&1 | tee -a $LOGFILE

  # 重啟次數
  echo -e "\n--- Restart Count ---" | tee -a $LOGFILE
  kubectl get pods -n $NAMESPACE -l app=$APP -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.containerStatuses[0].restartCount}{"\n"}{end}' 2>&1 | tee -a $LOGFILE

  # OOM 事件
  echo -e "\n--- Recent OOM Events ---" | tee -a $LOGFILE
  kubectl get events -n $NAMESPACE --field-selector reason=OOMKilling --sort-by='.lastTimestamp' 2>&1 | grep $APP | tail -5 | tee -a $LOGFILE || echo "No OOM events" | tee -a $LOGFILE

  # 等待下一次
  if [ $i -lt $COUNT ]; then
    echo -e "\nNext check in ${INTERVAL}s..." | tee -a $LOGFILE
    sleep $INTERVAL
  fi
done

echo -e "\n\nMonitoring completed. Log saved to: ${LOGFILE}"
```

## Prometheus 監控（如可用）

### 關鍵 Metrics

如集群有 Prometheus，設置以下告警:

#### 1. Container Memory 告警
```yaml
- alert: ExchangeServiceHighMemory
  expr: container_memory_working_set_bytes{namespace="forex-prod",pod=~"exchange-service-.*"} > 5500000000
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "Exchange Service memory usage > 5.5GB"
    description: "Pod {{ $labels.pod }} memory: {{ $value | humanize }}B"
```

#### 2. JVM Heap 告警
```yaml
- alert: ExchangeServiceHighHeap
  expr: jvm_memory_used_bytes{namespace="forex-prod",pod=~"exchange-service-.*",area="heap"} > 3600000000
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "Exchange Service heap usage > 3.6GB (90% of 4GB max)"
    description: "Pod {{ $labels.pod }} heap: {{ $value | humanize }}B"
```

#### 3. OOM 告警
```yaml
- alert: ExchangeServiceOOMKilled
  expr: increase(kube_pod_container_status_restarts_total{namespace="forex-prod",pod=~"exchange-service-.*"}[5m]) > 0
  for: 1m
  labels:
    severity: critical
  annotations:
    summary: "Exchange Service Pod restarted (possible OOM)"
    description: "Pod {{ $labels.pod }} restarted"
```

#### 4. HPA 副本數告警
```yaml
- alert: ExchangeServiceLowReplicas
  expr: kube_hpa_status_current_replicas{namespace="forex-prod",hpa="exchange-service-hpa"} < 2
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "Exchange Service replicas < 2 (high availability risk)"
    description: "Current replicas: {{ $value }}"
```

### Grafana Dashboard（如可用）

**建議 Panel**:
1. **Memory Usage Trend** (時間序列)
   - Query: `container_memory_working_set_bytes{namespace="forex-prod",pod=~"exchange-service-.*"}`
   - 顯示: 7 天趨勢，6GB limit 線

2. **JVM Heap Usage** (時間序列)
   - Query: `jvm_memory_used_bytes{area="heap"}`
   - 顯示: Heap 使用 vs 4GB max

3. **GC Pause Time** (熱力圖或時間序列)
   - Query: `jvm_gc_pause_seconds_sum / jvm_gc_pause_seconds_count`
   - 顯示: 平均 GC 暫停時間

4. **HPA Replicas** (時間序列)
   - Query: `kube_hpa_status_current_replicas{hpa="exchange-service-hpa"}`
   - 顯示: 副本數變化

5. **Pod Restart Count** (計數器)
   - Query: `kube_pod_container_status_restarts_total{pod=~"exchange-service-.*"}`
   - 顯示: 累計重啟次數

## 監控報告

### 每日報告模板

```markdown
# Exchange Service 監控報告 - YYYY-MM-DD

## 摘要
- 部署日期: 2025-12-23
- 報告日期: YYYY-MM-DD
- 運行天數: X 天

## 指標

### 記憶體使用
- 平均: X GB
- 峰值: X GB
- 穩定性: 穩定 / 波動 / 增長

### OOM 事件
- 次數: X 次
- 最近 OOM: YYYY-MM-DD HH:MM（或「無」）

### GC 行為
- Young GC 平均頻率: X 次/分鐘
- Young GC 平均暫停: X ms
- Full GC 次數: X 次

### HPA 行為
- 平均副本數: X
- 峰值副本數: X
- 擴展次數: X 次

### Pod 重啟
- 總重啟次數: X
- 原因: OOM / 應用錯誤 / 其他

## 問題
- [ ] 無問題
- [ ] 發現問題: <描述>

## 行動項
- [ ] 繼續監控
- [ ] 調整 JVM 參數
- [ ] 其他: <描述>

**報告人**: User + Claude AI
```

## 監控檢查清單

### 部署後 1 小時（密集監控）
- [ ] 每 5 分鐘檢查 Pod 狀態
- [ ] 每 5 分鐘檢查記憶體使用
- [ ] 檢查 HPA 是否正常工作
- [ ] 檢查 GC 日誌（暫停時間）
- [ ] 確認無 OOM 事件

### 部署後 24 小時
- [ ] 記憶體使用穩定在 3.5-4.5GB
- [ ] 無 OOM 事件
- [ ] 無 Pod 重啟
- [ ] GC 暫停時間 < 200ms
- [ ] HPA 根據負載正常擴展/縮容

### 部署後 1 週
- [ ] 總結 OOM 次數（目標: 0）
- [ ] 分析 GC 日誌（是否需調整參數）
- [ ] 評估 Heap 大小是否合適
- [ ] 決定是否需要進一步優化

## 異常應對

### 記憶體持續增長
1. 檢查是否有內存洩漏
2. 生成 heap dump 分析
3. 檢查 Direct Memory 使用

### 頻繁 Full GC
1. 可能 Heap 不足，考慮增加 Xmx
2. 檢查是否有大對象創建
3. 調整 G1GC 參數（如 InitiatingHeapOccupancyPercent）

### HPA 不擴展
1. 檢查 Metrics Server
2. 檢查 CPU/Memory 是否達閾值
3. 檢查 HPA Events

---

**文檔版本**: 1.0
**最後更新**: 2025-12-23
