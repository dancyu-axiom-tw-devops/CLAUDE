# Kafka OOM 修復實施指南

## 修復方案：平衡方案 (Solution B)

基於根因分析，採用平衡方案在資源使用和性能之間取得最佳平衡。

## 配置變更摘要

### 1. JVM 記憶體參數調整

**檔案**: `env/forex.env` Line 3

**修改前**:
```bash
KAFKA_HEAP_OPTS=-Xmx4096m -Xms4096m -server -XX:+UseG1GC -XX:MaxGCPauseMillis=20 -XX:InitiatingHeapOccupancyPercent=35 -XX:+ExplicitGCInvokesConcurrent -XX:MaxInlineLevel=15
```

**修改後**:
```bash
KAFKA_HEAP_OPTS=-Xmx3072m -Xms3072m -XX:MaxDirectMemorySize=1536m -server -XX:+UseG1GC -XX:MaxGCPauseMillis=20 -XX:InitiatingHeapOccupancyPercent=35 -XX:+ExplicitGCInvokesConcurrent -XX:MaxInlineLevel=15
```

**變更內容**:
- `-Xmx4096m` → `-Xmx3072m` (Heap 最大值: 4GB → 3GB)
- `-Xms4096m` → `-Xms3072m` (Heap 初始值: 4GB → 3GB)
- 新增 `-XX:MaxDirectMemorySize=1536m` (限制 Direct Memory 為 1.5GB)

**原因**:
- Kafka 官方建議 Heap 不超過 6GB，更多依賴 OS Page Cache
- 明確限制 Direct Memory 防止無限制增長
- 為 Non-Heap Memory 和系統開銷預留空間

### 2. 容器資源限制調整

**檔案**: `statefulset.yml` Line 62-68

**修改前**:
```yaml
resources:
  requests:
    cpu: "1000m"
    memory: "512Mi"
  limits:
    cpu: "4000m"
    memory: "5Gi"
```

**修改後**:
```yaml
resources:
  requests:
    cpu: "1000m"
    memory: "2Gi"
  limits:
    cpu: "4000m"
    memory: "6Gi"
```

**變更內容**:
- Memory Request: 512Mi → 2Gi (提高 4 倍)
- Memory Limit: 5Gi → 6Gi (增加 1GB)

**原因**:
- Request 反映實際最低需求，改善調度準確性
- Limit 提供足夠緩衝空間（總需求 ~6GB）

### 3. 緩衝區配置優化

**檔案**: `env/forex.env` Line 23, 25, 26, 33

**修改項目**:

| 參數 | 修改前 | 修改後 | 說明 |
|------|--------|--------|------|
| `KAFKA_CFG_MESSAGE_MAX_BYTES` | 50000000 (50MB) | 10485760 (10MB) | 單條訊息大小上限 |
| `KAFKA_SOCKET_REQUEST_MAX_BYTES` | 500000000 (500MB) | 104857600 (100MB) | Socket 請求緩衝區 |
| `KAFKA_CFG_REPLICA_FETCH_MAX_BYTES` | 500000000 (500MB) | 104857600 (100MB) | 副本抓取緩衝區 |
| `KAFKA_CFG_CONSUMER_FETCH_MAX_BYTES` | 50000000 (50MB) | 10485760 (10MB) | 消費者抓取上限 |

**原因**:
- 降低單次操作記憶體峰值
- 減少 Direct Memory 累積速度
- 適合 forex-stg 測試環境負載

## 修復後記憶體分配

```
Component              Allocation    Notes
─────────────────────────────────────────────────────
JVM Heap              3072 MB       固定配置
Direct Memory         1536 MB       明確限制
MetaSpace             512 MB        動態分配
Code Cache            240 MB        JIT 編譯
Compressed Class      1024 MB       類指標
Thread Stacks         67 MB         所有線程
JMX Agent             128 MB        Monitoring
OS Overhead           425 MB        系統進程
─────────────────────────────────────────────────────
總計                 ~6004 MB       < 6Gi Limit ✅
安全邊際              ~140 MB        2.3%
```

## 實施步驟

### Phase 1: 準備工作 ✅

1. **備份當前配置** ✅
   ```bash
   cd /Users/user/CLAUDE/docs/workflows/WF-20251223-kafka-oom-fix/script
   ./backup-config.sh
   ```

2. **驗證備份** ✅
   ```bash
   ls -lh /Users/user/CLAUDE/docs/workflows/WF-20251223-kafka-oom-fix/data/backup/
   ```

3. **準備修改後配置** ✅
   - Solution B 配置已準備於 `data/solution-b/`

### Phase 2: 配置驗證

1. **檢查配置差異**
   ```bash
   # 比較 JVM 參數
   diff -u \
     /Users/user/CLAUDE/docs/workflows/WF-20251223-kafka-oom-fix/data/backup/forex.env \
     /Users/user/CLAUDE/docs/workflows/WF-20251223-kafka-oom-fix/data/solution-b/forex.env

   # 比較資源限制
   diff -u \
     /Users/user/CLAUDE/docs/workflows/WF-20251223-kafka-oom-fix/data/backup/statefulset.yml \
     /Users/user/CLAUDE/docs/workflows/WF-20251223-kafka-oom-fix/data/solution-b/statefulset.yml
   ```

2. **驗證語法正確性**
   ```bash
   # 檢查 YAML 語法
   kubectl apply --dry-run=client -f \
     /Users/user/CLAUDE/docs/workflows/WF-20251223-kafka-oom-fix/data/solution-b/statefulset.yml
   ```

### Phase 3: 應用配置

1. **複製修改後配置到 Kafka 目錄**
   ```bash
   cp /Users/user/CLAUDE/docs/workflows/WF-20251223-kafka-oom-fix/data/solution-b/forex.env \
      /Users/user/FOREX-project/hkidc-k8s-gitlab/forex-stg/forex-stage-k8s-deploy/kafka-cluster/env/

   cp /Users/user/CLAUDE/docs/workflows/WF-20251223-kafka-oom-fix/data/solution-b/statefulset.yml \
      /Users/user/FOREX-project/hkidc-k8s-gitlab/forex-stg/forex-stage-k8s-deploy/kafka-cluster/
   ```

2. **重新生成 Secret 並部署**
   ```bash
   cd /Users/user/FOREX-project/hkidc-k8s-gitlab/forex-stg/forex-stage-k8s-deploy/kafka-cluster

   # 使用 Kustomize 部署
   kustomize build . | kubectl apply -f -
   ```

3. **觀察 Pod 重啟**
   ```bash
   # 監控 Pod 狀態
   kubectl -n forex-stg get pods -w

   # 查看 Pod 事件
   kubectl -n forex-stg describe pod kafka-0
   ```

### Phase 4: 驗證與監控

1. **檢查 Pod 狀態**
   ```bash
   # 確認 Pod Running
   kubectl -n forex-stg get pod kafka-0

   # 檢查無 OOMKilled
   kubectl -n forex-stg get pod kafka-0 -o jsonpath='{.status.containerStatuses[0].lastState.terminated.reason}'
   ```

2. **驗證 JVM 參數生效**
   ```bash
   # 進入容器檢查
   kubectl -n forex-stg exec -it kafka-0 -- bash

   # 查看 JVM 參數
   ps aux | grep java

   # 確認 Heap 和 Direct Memory 限制
   # 應看到: -Xmx3072m -Xms3072m -XX:MaxDirectMemorySize=1536m
   ```

3. **測試 Kafka 功能**
   ```bash
   # 列出 Topics
   kubectl -n forex-stg exec -it kafka-0 -- \
     kafka-topics.sh --bootstrap-server localhost:9094 --list

   # 創建測試 Topic
   kubectl -n forex-stg exec -it kafka-0 -- \
     kafka-topics.sh --bootstrap-server localhost:9094 \
     --create --topic test-oom-fix --partitions 1 --replication-factor 1

   # 發送測試訊息
   kubectl -n forex-stg exec -it kafka-0 -- \
     kafka-console-producer.sh --bootstrap-server localhost:9094 --topic test-oom-fix

   # 消費測試訊息
   kubectl -n forex-stg exec -it kafka-0 -- \
     kafka-console-consumer.sh --bootstrap-server localhost:9094 \
     --topic test-oom-fix --from-beginning
   ```

4. **監控記憶體使用**
   ```bash
   # 查看容器記憶體使用
   kubectl -n forex-stg top pod kafka-0

   # 查看 JVM 記憶體 (透過 JMX)
   kubectl -n forex-stg exec -it kafka-0 -- \
     curl -s localhost:5556/metrics | grep -E 'jvm_memory|process_resident'
   ```

5. **檢查 Prometheus Metrics**
   - 訪問 Prometheus UI
   - 查詢 `container_memory_working_set_bytes{pod="kafka-0",namespace="forex-stg"}`
   - 確認記憶體使用穩定在 6GB 以下

### Phase 5: 持續觀察

1. **短期監控 (前 24 小時)**
   - 每小時檢查一次 Pod 狀態
   - 監控記憶體使用趨勢
   - 確認無 OOMKilled 事件

2. **中期監控 (1-2 週)**
   - 每天檢查記憶體峰值
   - 觀察不同負載下的表現
   - 收集 JVM GC 統計

3. **記錄實際使用量**
   - 記錄平均記憶體使用
   - 記錄峰值記憶體使用
   - 評估是否需要微調

## 回滾程序

如果修復後出現問題，可快速回滾：

```bash
cd /Users/user/CLAUDE/docs/workflows/WF-20251223-kafka-oom-fix/script

# 執行回滾腳本
./rollback.sh [backup_timestamp]

# 重新部署
cd /Users/user/FOREX-project/hkidc-k8s-gitlab/forex-stg/forex-stage-k8s-deploy/kafka-cluster
kustomize build . | kubectl apply -f -
```

## 監控告警建議

### Prometheus Alert Rules

```yaml
# 記憶體使用率告警
- alert: KafkaHighMemoryUsage
  expr: |
    container_memory_working_set_bytes{pod="kafka-0",namespace="forex-stg"}
    / container_spec_memory_limit_bytes{pod="kafka-0",namespace="forex-stg"}
    > 0.85
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "Kafka memory usage above 85%"

# 接近 OOM 告警
- alert: KafkaNearOOM
  expr: |
    container_memory_working_set_bytes{pod="kafka-0",namespace="forex-stg"}
    / container_spec_memory_limit_bytes{pod="kafka-0",namespace="forex-stg"}
    > 0.95
  for: 1m
  labels:
    severity: critical
  annotations:
    summary: "Kafka memory usage above 95% - near OOM"
```

### JVM Metrics 監控

- `jvm_memory_used_bytes{area="heap"}` - Heap 使用量
- `jvm_memory_used_bytes{area="nonheap"}` - Non-Heap 使用量
- `jvm_buffer_pool_used_bytes{pool="direct"}` - Direct Memory 使用量
- `jvm_gc_pause_seconds_sum` - GC 暫停時間

## 性能影響評估

### Heap 降低 (4GB → 3GB) 影響

**優點**:
- 減少 GC 壓力（堆越大 GC 時間越長）
- 為 Direct Memory 預留更多空間
- 符合 Kafka 最佳實踐

**可能影響**:
- 如果 Heap 使用率原本就高，可能增加 GC 頻率
- 需觀察 GC 日誌確認

**緩解措施**:
- G1GC 配置已優化（MaxGCPauseMillis=20ms）
- 如 GC 頻繁可微調 InitiatingHeapOccupancyPercent

### 緩衝區降低影響

**Message Max (50MB → 10MB)**:
- 影響: 單條訊息不能超過 10MB
- 評估: forex-stg 環境大部分訊息 < 1MB，影響極小
- 如需大訊息: 可分批發送或使用外部存儲

**Socket/Fetch 緩衝區 (500MB → 100MB)**:
- 影響: 單次請求抓取資料量減少
- 評估: 測試環境吞吐量需求不高，影響可忽略
- 如需高吞吐: 可調整為 200MB

## 後續優化建議

1. **考慮持久化存儲**
   - 目前使用 emptyDir，Pod 重啟會丟失資料
   - 建議改用 PersistentVolumeClaim

2. **評估多節點部署**
   - 單節點無高可用性
   - 生產環境建議至少 3 節點

3. **定期審查配置**
   - 每季度檢查記憶體使用趨勢
   - 根據實際負載調整配置

4. **壓力測試**
   - 模擬高負載場景
   - 驗證配置穩定性

## 預期結果

✅ 消除 OOMKilled 問題
✅ 記憶體使用穩定在 6GB 以下
✅ Kafka 功能正常運作
✅ 性能影響最小化
✅ 系統穩定性提升

## 相關文件

- [根因分析](01-analysis.md)
- [README](README.md)
- [Plan 文件](/Users/user/.claude/plans/squishy-hatching-bonbon.md)
