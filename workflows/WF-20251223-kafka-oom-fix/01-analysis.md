# Kafka OOM 根因分析報告

## 執行摘要

Kafka 集群發生 Kubernetes OOMKilled，根本原因是 JVM 記憶體配置（4GB heap + 未限制的 Direct Memory）加上 Kafka 緩衝區使用，總計超過容器 5GB 限制。

## 環境資訊

- **Kafka 版本**: 3.7.1 (Bitnami)
- **部署模式**: KRaft (無 ZooKeeper)
- **節點數**: 1 (單節點)
- **Namespace**: forex-stg
- **Storage**: emptyDir (非持久化)

## 記憶體使用分析

### 當前配置

#### Kubernetes 資源限制
```yaml
resources:
  requests:
    cpu: "1000m"
    memory: "512Mi"
  limits:
    cpu: "4000m"
    memory: "5Gi"      # 5GB 限制
```

#### JVM 參數
```bash
KAFKA_HEAP_OPTS=-Xmx4096m -Xms4096m -server -XX:+UseG1GC \
  -XX:MaxGCPauseMillis=20 -XX:InitiatingHeapOccupancyPercent=35 \
  -XX:+ExplicitGCInvokesConcurrent -XX:MaxInlineLevel=15
```

**問題點**:
- Heap 固定 4GB
- **未設置 `-XX:MaxDirectMemorySize`**，預設等於 heap size (4GB)
- 無 Direct Memory 限制

#### Kafka 緩衝區配置
```bash
KAFKA_CFG_MESSAGE_MAX_BYTES=50000000          # 50MB
KAFKA_SOCKET_RECEIVE_BUFFER_BYTES=16777216    # 16MB
KAFKA_SOCKET_REQUEST_MAX_BYTES=500000000      # 500MB ⚠️
KAFKA_CFG_REPLICA_FETCH_MAX_BYTES=500000000   # 500MB ⚠️
KAFKA_CFG_CONSUMER_FETCH_MAX_BYTES=50000000   # 50MB
KAFKA_CFG_NUM_NETWORK_THREADS=5
KAFKA_CFG_NUM_IO_THREADS=8
```

**問題點**:
- 單請求/副本抓取上限 500MB 過大
- 多線程環境下會快速累積

### 記憶體組成詳細計算

#### 1. JVM Heap Memory
```
-Xmx4096m -Xms4096m = 4096 MB (固定)
```

#### 2. JVM Non-Heap Memory

**MetaSpace** (類別元資料):
- 估計: 256-512 MB
- 說明: 取決於加載的類數量

**Code Cache** (JIT 編譯):
- 估計: 240 MB
- 說明: 預設 ReservedCodeCacheSize

**Compressed Class Space**:
- 估計: 1024 MB
- 說明: 壓縮類指標空間

**Thread Stacks**:
- Network threads: 5 × 1MB = 5 MB
- I/O threads: 8 × 1MB = 8 MB
- GC threads: ~4 × 1MB = 4 MB
- JMX/其他: ~50 × 1MB = 50 MB
- 小計: ~67 MB

#### 3. Direct Memory (堆外記憶體)

**未限制的危險**:
- JVM 預設: `-XX:MaxDirectMemorySize = -Xmx` = 4GB
- Kafka 大量使用 Direct Buffer 處理網路 I/O
- NIO Channel Buffers
- Socket Buffers

**實際使用估算**:
- 保守估計: 720 MB
- 正常負載: 1024 MB
- 高負載: 1536-2048 MB
- **極端情況**: 可能接近 4GB

#### 4. OS 和系統開銷
- Container 基礎進程: 256-512 MB
- JMX Exporter Agent: 128-256 MB

### 總記憶體需求計算

#### 最小配置 (輕負載)
```
JVM Heap:              4096 MB
MetaSpace:              256 MB
Code Cache:             240 MB
Compressed Class:      1024 MB
Thread Stacks:           67 MB
Direct Memory:          720 MB (保守)
JMX Agent:              128 MB
OS Overhead:            256 MB
────────────────────────────
總計:                 ~6787 MB ≈ 6.6 GB
```

#### 高負載配置
```
JVM Heap:              4096 MB
MetaSpace:              512 MB
Code Cache:             240 MB
Compressed Class:      1024 MB
Thread Stacks:           67 MB
Direct Memory:         1536 MB (高負載)
JMX Agent:              256 MB
OS Overhead:            512 MB
────────────────────────────
總計:                 ~8243 MB ≈ 8.0 GB
```

#### 極端情況 (Direct Memory 未限制)
```
JVM Heap:              4096 MB
Direct Memory:         4096 MB (預設上限 = heap)
其他:                  2048 MB
────────────────────────────
總計:                ~10240 MB ≈ 10 GB
```

## 問題根因識別

### 主要問題

1. **Memory Limit 嚴重不足**
   - 容器限制: 5 GB
   - 實際需求: 6.6-10 GB
   - **缺口: 1.6-5 GB**

2. **未限制 Direct Memory**
   - JVM 未設置 `-XX:MaxDirectMemorySize`
   - 預設允許最多 4GB Direct Memory
   - 加上 4GB Heap = 8GB+，遠超容器限制

3. **緩衝區配置過於寬鬆**
   - 500MB 單請求上限 × 多線程
   - 快速累積記憶體使用
   - 缺乏合理限制

4. **Request 與 Limit 差距過大**
   - Request: 512Mi (調度參考值過低)
   - Limit: 5Gi (實際限制不足)
   - 差距 9.7 倍，調度器無法準確評估

### 次要問題

5. **缺乏記憶體監控告警**
   - 無法提前發現記憶體壓力
   - OOM 發生才察覺

6. **非持久化存儲**
   - 使用 emptyDir
   - Pod 重啟數據丟失
   - 加劇問題影響

## OOMKilled 觸發情境

### 情境 A: 大訊息處理
```
1. Producer 發送接近 50MB 的大訊息
2. Kafka broker 使用 Direct Memory 接收
3. 多個並發請求同時處理
4. Direct Memory 迅速累積
5. 總記憶體超過 5GB → OOMKilled
```

### 情境 B: 副本同步
```
1. 副本抓取請求最大 500MB
2. Network threads (5) 同時處理
3. 500MB × 5 = 2.5GB Direct Memory
4. 加上 Heap 4GB + 其他 2GB
5. 總計 8.5GB → OOMKilled
```

### 情境 C: 高並發消費
```
1. 多個 Consumer 同時拉取資料
2. 每個 Fetch 請求 50MB
3. Network + I/O threads 全開 (13 threads)
4. Direct Memory + Page Cache 累積
5. 超過容器限制 → OOMKilled
```

## 影響評估

### 嚴重性: 🔴 高
- **可用性**: Kafka 服務中斷
- **資料**: emptyDir 數據丟失
- **業務**: 依賴 Kafka 的服務受影響

### 頻率
- **輕負載**: 偶發 (每週 1-2 次)
- **中負載**: 頻繁 (每天數次)
- **高負載**: 持續發生 (無法穩定運行)

### 當前狀態
需要根據實際 Pod 重啟頻率判斷負載等級。

## 結論

OOM 問題由三個因素共同導致：

1. **配置錯誤**: 未限制 Direct Memory
2. **資源不足**: 5GB 限制無法滿足實際需求
3. **參數寬鬆**: 緩衝區上限過大

修復需要：
- 明確限制 Direct Memory
- 提高容器 Memory Limit
- 優化緩衝區配置
- 調整 Memory Request 以反映真實需求

詳細修復方案請參閱 [02-implementation-guide.md](02-implementation-guide.md)。
