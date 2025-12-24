# Phase 2: JMX Exporter Integration Guide

## Overview

Phase 1 使用 Prometheus 的 container metrics（memory, CPU）已足夠監控基本健康狀況。

**Phase 2** 添加 JMX Exporter 可獲取更詳細的 JVM 指標：
- Heap memory 使用詳情（Young Gen, Old Gen）
- GC 事件統計（Minor GC, Full GC 頻率和暫停時間）
- Thread 狀態（active, waiting, blocked）
- Class loading 統計

## 何時需要 Phase 2？

**觸發條件**（滿足任一即可考慮）：
1. Phase 1 檢測到持續的記憶體洩漏但需要更詳細的 heap 分析
2. 頻繁的 Full GC 導致性能問題
3. 需要深入分析 JVM 調優效果
4. 運維團隊明確要求 JVM 級別的可見性

**不需要 Phase 2 的情況**：
- Phase 1 運行良好，無重大記憶體問題
- OOM 事件罕見且容易通過調整 limit 解決
- 團隊對當前監控粒度滿意

## Implementation Steps

### Step 1: 準備 JMX Exporter

#### 1.1 下載 JMX Exporter JAR

```bash
# 下載 jmx_prometheus_javaagent (使用與 Kafka 相同版本)
wget https://repo1.maven.org/maven2/io/prometheus/jmx/jmx_prometheus_javaagent/0.20.0/jmx_prometheus_javaagent-0.20.0.jar \
  -O jmx_prometheus_javaagent.jar
```

#### 1.2 創建 JMX 配置文件

參考 Kafka 的配置，創建 `exchange-jmx-config.yml`：

```yaml
# exchange-jmx-config.yml
lowercaseOutputName: true
lowercaseOutputLabelNames: true
rules:
# JVM Memory
- pattern: 'java.lang<type=Memory><HeapMemoryUsage>(\w+)'
  name: jvm_memory_heap_$1
  type: GAUGE
- pattern: 'java.lang<type=Memory><NonHeapMemoryUsage>(\w+)'
  name: jvm_memory_nonheap_$1
  type: GAUGE

# GC metrics
- pattern: 'java.lang<type=GarbageCollector, name=(\w+)><>CollectionCount'
  name: jvm_gc_collection_count
  labels:
    gc: "$1"
  type: COUNTER
- pattern: 'java.lang<type=GarbageCollector, name=(\w+)><>CollectionTime'
  name: jvm_gc_collection_time_ms
  labels:
    gc: "$1"
  type: COUNTER

# Thread metrics
- pattern: 'java.lang<type=Threading><>ThreadCount'
  name: jvm_threads_current
  type: GAUGE
- pattern: 'java.lang<type=Threading><>DaemonThreadCount'
  name: jvm_threads_daemon
  type: GAUGE
- pattern: 'java.lang<type=Threading><>PeakThreadCount'
  name: jvm_threads_peak
  type: GAUGE

# Class loading
- pattern: 'java.lang<type=ClassLoading><>LoadedClassCount'
  name: jvm_classes_loaded
  type: GAUGE
```

#### 1.3 將 JMX Exporter 加入容器映像

**Option A: 修改 Dockerfile（推薦）**

```dockerfile
# In exchange-service Dockerfile
FROM openjdk:11-jre-slim

# Add JMX Exporter
RUN mkdir -p /opt/jmx_exporter
COPY jmx_prometheus_javaagent.jar /opt/jmx_exporter/
COPY exchange-jmx-config.yml /opt/jmx_exporter/exchange.yml

# ... rest of Dockerfile
```

**Option B: 使用 InitContainer 下載（不推薦，增加啟動時間）**

```yaml
initContainers:
- name: download-jmx-exporter
  image: busybox:1.36
  command:
  - sh
  - -c
  - |
    wget -O /jmx/jmx_prometheus_javaagent.jar \
      https://repo1.maven.org/maven2/io/prometheus/jmx/jmx_prometheus_javaagent/0.20.0/jmx_prometheus_javaagent-0.20.0.jar
  volumeMounts:
  - name: jmx-exporter
    mountPath: /jmx
```

### Step 2: 修改 exchange-service Deployment

```yaml
# deployment.yml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: exchange-service
  namespace: forex-prod
spec:
  template:
    spec:
      containers:
      - name: exchange-service
        image: asia-east2-docker.pkg.dev/uu-prod/uu-prod/forex/exchange-service/exchange-service-rel
        ports:
        - containerPort: 10320
          name: exchange-port
        - containerPort: 5556      # 新增：JMX Exporter metrics port
          name: metrics
        env:
        # 新增：JMX 配置
        - name: JAVA_OPTS
          value: >-
            -javaagent:/opt/jmx_exporter/jmx_prometheus_javaagent.jar=5556:/opt/jmx_exporter/exchange.yml
            -Dcom.sun.management.jmxremote=true
            -Dcom.sun.management.jmxremote.authenticate=false
            -Dcom.sun.management.jmxremote.ssl=false
            -Dcom.sun.management.jmxremote.port=5555
            -Dcom.sun.management.jmxremote.rmi.port=5555
        # ... existing env vars
```

### Step 3: 創建 Service 暴露 Metrics

```yaml
# service.yml
apiVersion: v1
kind: Service
metadata:
  name: exchange-service-metrics
  namespace: forex-prod
  labels:
    app: exchange-service
spec:
  ports:
  - port: 5556
    targetPort: 5556
    name: metrics
  selector:
    app: exchange-service
```

### Step 4: 創建 ServiceMonitor（如果使用 Prometheus Operator）

```yaml
# servicemonitor.yml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: exchange-service
  namespace: forex-prod
  labels:
    app: exchange-service
spec:
  selector:
    matchLabels:
      app: exchange-service
  endpoints:
  - port: metrics
    interval: 30s
    path: /metrics
```

### Step 5: 驗證 JMX Metrics

```bash
# Port-forward to pod
kubectl port-forward -n forex-prod pod/exchange-service-xxx 5556:5556

# Check metrics locally
curl http://localhost:5556/metrics | grep jvm_

# Expected output:
# jvm_memory_heap_used{...} 3500000000
# jvm_gc_collection_count{gc="G1 Young Generation"} 42
# jvm_threads_current 150
```

### Step 6: 更新 Health Check 腳本

添加新的 PromQL 查詢到 `config/promql_queries.yaml`：

```yaml
# JVM metrics (requires JMX Exporter)
jvm:
  # Heap usage
  heap_used: |
    jvm_memory_heap_used{
      namespace="{namespace}",
      pod=~"{pod_pattern}"
    }

  heap_max: |
    jvm_memory_heap_max{
      namespace="{namespace}",
      pod=~"{pod_pattern}"
    }

  # GC count
  gc_count: |
    rate(jvm_gc_collection_count{
      namespace="{namespace}",
      pod=~"{pod_pattern}"
    }[{lookback}])

  # GC time
  gc_time: |
    rate(jvm_gc_collection_time_ms{
      namespace="{namespace}",
      pod=~"{pod_pattern}"
    }[{lookback}])
```

更新 `scripts/analyzer.py` 添加 GC 分析：

```python
def analyze_gc_performance(
    self,
    gc_count_rate: float,
    gc_time_rate: float,
    lookback_hours: int = 24
) -> Dict[str, Any]:
    """Analyze GC efficiency"""
    issues = []

    # High GC frequency
    if gc_count_rate > 1.0:  # > 1 GC/second
        issues.append({
            'severity': 'HIGH',
            'category': 'HIGH_GC_FREQUENCY',
            'message': f'GC frequency {gc_count_rate:.2f}/s is high',
            'suggestion': 'Consider increasing heap size or optimizing object allocation'
        })

    # High GC time
    if gc_time_rate > 100:  # > 100ms/s = 10% time in GC
        issues.append({
            'severity': 'CRITICAL',
            'category': 'HIGH_GC_PAUSE',
            'message': f'GC pause time {gc_time_rate:.0f}ms/s (>10% of time)',
            'suggestion': 'Urgent: Review GC tuning, consider G1GC or ZGC'
        })

    return {
        'gc_count_rate': round(gc_count_rate, 2),
        'gc_time_rate': round(gc_time_rate, 2),
        'gc_overhead_pct': round(gc_time_rate / 10, 2),
        'issues': issues,
    }
```

## Rollback Plan

如果 JMX Exporter 導致問題：

```bash
# 1. 快速 rollback：移除 JAVA_OPTS
kubectl set env deployment/exchange-service -n forex-prod JAVA_OPTS-

# 2. 或者回滾到前一個版本
kubectl rollout undo deployment/exchange-service -n forex-prod

# 3. 刪除 ServiceMonitor
kubectl delete servicemonitor exchange-service -n forex-prod
```

## Cost-Benefit Analysis

### Costs
- **開發時間**: 1-2 天（修改 Dockerfile, deployment, 測試）
- **風險**: 中等（修改 JVM 啟動參數可能影響性能）
- **維護成本**: 額外的 metrics 增加 Prometheus 存儲需求（~5-10%）

### Benefits
- **深入可見性**: Heap, GC, Thread 詳細指標
- **更精確診斷**: 可區分 memory leak 類型（heap vs off-heap）
- **GC 調優**: 數據驅動的 GC 參數優化

## Decision Framework

```
Phase 1 運行 2 週後評估：

├─ 檢測到記憶體洩漏？
│  ├─ 是 → 需要 heap 詳情？
│  │      ├─ 是 → 實施 Phase 2
│  │      └─ 否 → 繼續 Phase 1
│  └─ 否 → 檢查 OOM 頻率
│         ├─ 頻繁（>1次/週）→ 實施 Phase 2
│         └─ 罕見 → 繼續 Phase 1，3 個月後重新評估
```

## Reference: Kafka JMX Configuration

參考 Kafka 的成功配置：

```bash
# 查看 Kafka JMX 配置
cat /Users/user/FOREX-project/hkidc-k8s-gitlab/forex-stg/forex-stage-k8s-deploy/kafka-cluster/statefulset.yml | grep -A 5 KAFKA_JMX_OPTS
```

Key takeaways:
- Port 5556 for metrics exposure
- Port 5555 for JMX remote
- Disable authentication for internal use
- Set hostname for RMI

## Monitoring Phase 2 Effectiveness

After implementation, track:

1. **Metric Completeness**: Are all expected JVM metrics available?
2. **Performance Impact**: Any noticeable overhead from JMX Exporter?
3. **Diagnostic Value**: Did JVM metrics help resolve issues faster?
4. **False Positive Reduction**: More accurate leak detection with heap metrics?

## Conclusion

**Recommendation**:
- **立即**: 使用 Phase 1（container metrics）部署並運行
- **2-4 週後**: 根據實際需求評估是否需要 Phase 2
- **條件觸發**: 如果遇到複雜的記憶體問題，隨時可啟動 Phase 2

Phase 2 不是必需的，但當需要時，本文檔提供了完整的實施路徑。
