# 部署後驗證與監控指引

## 部署狀態

✅ **配置已部署**: 2025-12-23

## 立即驗證項目

### 1. 檢查 Pod 狀態

```bash
# 查看 Pod 是否 Running
kubectl -n forex-stg get pod kafka-0

# 預期輸出:
# NAME      READY   STATUS    RESTARTS   AGE
# kafka-0   1/1     Running   0          Xm
```

**檢查重點**:
- STATUS 應為 `Running`
- READY 應為 `1/1`
- RESTARTS 次數（記錄基準值）

### 2. 確認無 OOMKilled

```bash
# 檢查容器終止原因
kubectl -n forex-stg get pod kafka-0 -o jsonpath='{.status.containerStatuses[0].lastState.terminated.reason}'

# 預期: 空輸出或非 OOMKilled
```

```bash
# 查看 Pod 事件
kubectl -n forex-stg describe pod kafka-0 | grep -i oom

# 預期: 無 OOMKilled 相關事件
```

### 3. 驗證 JVM 參數生效

```bash
# 進入容器
kubectl -n forex-stg exec -it kafka-0 -- bash

# 查看 Java 進程參數
ps aux | grep java | grep -E 'Xmx|Xms|MaxDirectMemorySize'

# 預期看到:
# -Xmx3072m -Xms3072m -XX:MaxDirectMemorySize=1536m
```

**確認項**:
- ✅ `-Xmx3072m` (Heap 最大 3GB)
- ✅ `-Xms3072m` (Heap 初始 3GB)
- ✅ `-XX:MaxDirectMemorySize=1536m` (Direct Memory 1.5GB)

### 4. 查看容器資源配置

```bash
# 檢查資源限制
kubectl -n forex-stg get pod kafka-0 -o jsonpath='{.spec.containers[0].resources}'

# 預期輸出:
# {"limits":{"cpu":"4","memory":"6Gi"},"requests":{"cpu":"1","memory":"2Gi"}}
```

### 5. 測試 Kafka 功能

```bash
# 列出 Topics
kubectl -n forex-stg exec -it kafka-0 -- \
  kafka-topics.sh --bootstrap-server localhost:9094 --list

# 創建測試 Topic
kubectl -n forex-stg exec -it kafka-0 -- \
  kafka-topics.sh --bootstrap-server localhost:9094 \
  --create --topic oom-fix-verification --partitions 1 --replication-factor 1

# 發送測試訊息
echo "OOM fix deployed at $(date)" | \
kubectl -n forex-stg exec -i kafka-0 -- \
  kafka-console-producer.sh --bootstrap-server localhost:9094 --topic oom-fix-verification

# 消費測試訊息
kubectl -n forex-stg exec -it kafka-0 -- \
  kafka-console-consumer.sh --bootstrap-server localhost:9094 \
  --topic oom-fix-verification --from-beginning --max-messages 1
```

**預期**: 訊息正常收發，無錯誤

## 記憶體監控

### 即時記憶體使用

```bash
# 查看 Pod 記憶體使用
kubectl -n forex-stg top pod kafka-0

# 預期輸出範例:
# NAME      CPU(cores)   MEMORY(bytes)
# kafka-0   XXXm         XXXXMi
```

**記錄基準值**:
- 啟動後穩定記憶體: _______ MiB
- 時間: _______

### JVM 記憶體指標

```bash
# 查看 JVM 記憶體使用 (透過 JMX Exporter)
kubectl -n forex-stg exec -it kafka-0 -- \
  curl -s localhost:5556/metrics | grep -E 'jvm_memory_used_bytes|jvm_memory_max_bytes'
```

**關鍵指標**:
- `jvm_memory_used_bytes{area="heap"}` - Heap 使用量
- `jvm_memory_max_bytes{area="heap"}` - Heap 上限 (應為 3221225472 bytes = 3GB)
- `jvm_memory_used_bytes{area="nonheap"}` - Non-Heap 使用量
- `jvm_buffer_pool_used_bytes{pool="direct"}` - Direct Memory 使用量

### 容器記憶體詳細資訊

```bash
# 查看記憶體使用詳情
kubectl -n forex-stg exec -it kafka-0 -- cat /sys/fs/cgroup/memory/memory.usage_in_bytes
kubectl -n forex-stg exec -it kafka-0 -- cat /sys/fs/cgroup/memory/memory.limit_in_bytes

# Limit 應為 6442450944 bytes (6Gi)
```

## Prometheus 監控查詢

如果有 Prometheus 可用，執行以下查詢：

### 記憶體使用率

```promql
# 記憶體使用百分比
container_memory_working_set_bytes{pod="kafka-0",namespace="forex-stg"}
/ container_spec_memory_limit_bytes{pod="kafka-0",namespace="forex-stg"} * 100
```

**目標**: < 85%

### JVM Heap 使用率

```promql
# Heap 使用百分比
jvm_memory_used_bytes{area="heap",pod="kafka-0",namespace="forex-stg"}
/ jvm_memory_max_bytes{area="heap",pod="kafka-0",namespace="forex-stg"} * 100
```

**目標**: < 80%

### Direct Memory 監控

```promql
# Direct Buffer 使用量
jvm_buffer_pool_used_bytes{pool="direct",pod="kafka-0",namespace="forex-stg"}
```

**目標**: < 1536 MiB (1610612736 bytes)

## 監控時程

### 前 24 小時 (密集監控)

**檢查頻率**: 每 1 小時

**檢查項目**:
- [ ] Pod 狀態 (無重啟)
- [ ] 記憶體使用趨勢
- [ ] 無 OOMKilled 事件
- [ ] Kafka 功能正常

**記錄模板**:
```
時間: ____:____
Pod 狀態: Running / 其他 ______
記憶體使用: ______ MiB / 6144 MiB (___%)
重啟次數: ______
異常: 有 / 無 ______
```

### 第 2-7 天 (每日監控)

**檢查頻率**: 每日 2 次 (上午/下午)

**重點觀察**:
- 記憶體峰值
- GC 行為
- 服務穩定性

### 第 2-4 週 (週度監控)

**檢查頻率**: 每週 1 次

**評估項目**:
- 配置是否需要微調
- 性能是否符合預期
- 是否有新的問題

## 告警設定建議

### 記憶體使用率告警

```yaml
# 建議在 Prometheus 設定
- alert: KafkaHighMemoryUsage
  expr: |
    container_memory_working_set_bytes{pod="kafka-0",namespace="forex-stg"}
    / container_spec_memory_limit_bytes{pod="kafka-0",namespace="forex-stg"}
    > 0.85
  for: 5m
  labels:
    severity: warning
    team: forex
  annotations:
    summary: "Kafka 記憶體使用超過 85%"
    description: "當前使用: {{ $value | humanizePercentage }}"

- alert: KafkaNearOOM
  expr: |
    container_memory_working_set_bytes{pod="kafka-0",namespace="forex-stg"}
    / container_spec_memory_limit_bytes{pod="kafka-0",namespace="forex-stg"}
    > 0.95
  for: 1m
  labels:
    severity: critical
    team: forex
  annotations:
    summary: "Kafka 記憶體使用超過 95% - 接近 OOM"
    description: "當前使用: {{ $value | humanizePercentage }}"
```

### Pod 重啟告警

```yaml
- alert: KafkaPodRestarting
  expr: |
    rate(kube_pod_container_status_restarts_total{pod="kafka-0",namespace="forex-stg"}[15m]) > 0
  for: 5m
  labels:
    severity: warning
    team: forex
  annotations:
    summary: "Kafka Pod 頻繁重啟"
```

## 問題排查

### 如果記憶體使用仍然過高 (> 90%)

1. **收集資料**:
   ```bash
   # JVM Heap Dump
   kubectl -n forex-stg exec -it kafka-0 -- \
     jmap -dump:live,format=b,file=/tmp/heap.hprof 1

   # 查看記憶體分布
   kubectl -n forex-stg exec -it kafka-0 -- \
     jmap -histo 1 | head -30
   ```

2. **分析 GC 日誌**:
   ```bash
   kubectl -n forex-stg logs kafka-0 | grep -i gc
   ```

3. **考慮調整**:
   - 進一步降低緩衝區大小
   - 增加 Memory Limit 到 7Gi
   - 調整 Heap 到 2.5GB

### 如果發生 OOMKilled

1. **立即回滾**:
   ```bash
   cd /Users/user/CLAUDE/docs/workflows/WF-20251223-kafka-oom-fix/script
   ./rollback.sh [timestamp]
   ```

2. **收集事件**:
   ```bash
   kubectl -n forex-stg describe pod kafka-0 > /tmp/kafka-oom-event.txt
   kubectl -n forex-stg logs kafka-0 --previous > /tmp/kafka-last-log.txt
   ```

3. **重新評估**:
   - 檢查實際負載
   - 考慮採用方案 A (Memory Limit 8Gi)

### 如果性能下降

1. **檢查 GC 頻率**:
   ```bash
   kubectl -n forex-stg exec -it kafka-0 -- \
     curl -s localhost:5556/metrics | grep jvm_gc
   ```

2. **評估 Heap 是否過小**:
   - 如 GC 時間 > 5% 總時間，考慮增加 Heap

3. **調整參數**:
   - 可將 Heap 調整為 3.5GB
   - 對應降低 Direct Memory 為 1GB

## 成功標準確認

在 2 週觀察期後，確認以下標準：

- [ ] ✅ 無 OOMKilled 事件
- [ ] ✅ 記憶體使用穩定 < 85%
- [ ] ✅ Kafka 功能正常
- [ ] ✅ 無明顯性能劣化
- [ ] ✅ Pod 無異常重啟

**確認日期**: _____________
**確認人**: _____________

## 後續行動

### 如驗證成功

1. 更新 WORKLOG 記錄最終結果
2. 歸檔到 `worklogs/completed/2025-12/`
3. 總結經驗教訓
4. 考慮應用到其他環境

### 如需調整

1. 記錄調整原因
2. 更新配置文件
3. 重新驗證
4. 更新文檔

## 相關文件

- [README](README.md)
- [根因分析](01-analysis.md)
- [實施指南](02-implementation-guide.md)
- [工作記錄](worklogs/WORKLOG-20251223-implementation.md)
