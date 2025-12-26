# Prometheus 整合說明

## Aliyun Prometheus (ARMS) 配置

### 連接資訊

**公網地址**:
```
https://workspace-default-cms-5886645564773850-cn-hongkong.cn-hongkong-intranet.log.aliyuncs.com/prometheus/workspace-default-cms-5886645564773850-cn-hongkong/aliyun-prom-c61392b504d1742f1954f31dea08f7869
```

**內網地址** (推薦用於 K8s Pod):
```
https://workspace-default-cms-5886645564773850-cn-hongkong.cn-hongkong.log.aliyuncs.com/prometheus/workspace-default-cms-5886645564773850-cn-hongkong/aliyun-prom-c61392b504d1742f1954f31dea08f7869
```

### 認證資訊

**類型**: HTTP Basic Authentication

**憑證**:
- Username (AccessKeyId): `YOUR_ALIYUN_ACCESS_KEY_ID`
- Password (AccessKeySecret): `YOUR_ALIYUN_ACCESS_KEY_SECRET`
- UserPrincipalName: `k8s-prometheus-api@prod-waas2-tenant.onaliyun.com`

## 可用的檢查項目

整合 Prometheus 後，以下檢查項目將從 ⚪ (無資料) 變為實際狀態：

### 3️⃣ 記憶體使用 (Memory Usage)

**PromQL 查詢**:
```promql
# 平均記憶體使用
avg_over_time(container_memory_working_set_bytes{
  namespace="waas2-prod",
  pod=~"service-admin-.*",
  container="service-admin"
}[24h])

# 最大記憶體使用
max_over_time(container_memory_working_set_bytes{
  namespace="waas2-prod",
  pod=~"service-admin-.*",
  container="service-admin"
}[24h])

# P95 記憶體使用
quantile_over_time(0.95, container_memory_working_set_bytes{
  namespace="waas2-prod",
  pod=~"service-admin-.*",
  container="service-admin"
}[24h])
```

**判定規則**:
- 🟢: max < 70% of limit
- 🟡: 70% ≤ max < 85%
- 🔴: max ≥ 85% or 無 limit 設定

### 4️⃣ 記憶體趨勢 (Memory Trend)

**PromQL 查詢**:
```promql
# 時間序列查詢（用於趨勢分析）
container_memory_working_set_bytes{
  namespace="waas2-prod",
  pod=~"service-admin-.*",
  container="service-admin"
}
```

**判定方式**:
- 比較最後 1/4 時間段平均值 vs 前 1/4 時間段平均值
- 計算成長百分比

**判定規則**:
- 🟢: 成長 < 10%
- 🟡: 10% ≤ 成長 < 20%
- 🔴: 成長 ≥ 20% (可能記憶體洩漏)

### 5️⃣ CPU 使用 (CPU Usage)

**PromQL 查詢**:
```promql
# 平均 CPU 使用率
avg_over_time(
  rate(container_cpu_usage_seconds_total{
    namespace="waas2-prod",
    pod=~"service-admin-.*",
    container="service-admin"
  }[5m])
[24h:5m])
```

**判定規則**:
- 🟢: avg < 80% of request
- 🟡: 80% ≤ avg < 100%
- 🔴: 長時間 ≥ 100% (CPU 瓶頸)

### 8️⃣ Pod 數量合理性 (Scaling Sanity)

**結合 Prometheus 數據判定**:
- 🟡: replicas ≥ 3 但 memory < 30% 且 CPU < 30% (過度配置)
- 🟢: 其他情況

## 測試連接性

### 方法 1: 使用測試腳本

```bash
cd /Users/user/CLAUDE/workflows/WF-20251225-waas2-health-monitor/scripts
python3 test-prometheus.py
```

測試腳本會檢查:
1. 基本連通性 (`up` metric)
2. Container memory metrics 可用性
3. 特定服務 (service-admin) 的 metrics
4. CPU metrics 可用性
5. 可用的 namespaces

### 方法 2: 手動 curl 測試

```bash
# 設定變數
PROM_URL="https://workspace-default-cms-5886645564773850-cn-hongkong.cn-hongkong.log.aliyuncs.com/prometheus/workspace-default-cms-5886645564773850-cn-hongkong/aliyun-prom-c61392b504d1742f1954f31dea08f7869"
PROM_USER="YOUR_ALIYUN_ACCESS_KEY_ID"
PROM_PASS="YOUR_ALIYUN_ACCESS_KEY_SECRET"

# 測試 API 可用性
curl -u "$PROM_USER:$PROM_PASS" \
  "$PROM_URL/api/v1/query?query=up" | jq

# 測試 waas2-prod namespace metrics
curl -u "$PROM_USER:$PROM_PASS" \
  "$PROM_URL/api/v1/query?query=container_memory_working_set_bytes{namespace=\"waas2-prod\"}" | jq
```

### 預期結果

成功連接應該返回:
```json
{
  "status": "success",
  "data": {
    "resultType": "vector",
    "result": [
      {
        "metric": {
          "namespace": "waas2-prod",
          "pod": "service-admin-xxx",
          "container": "service-admin"
        },
        "value": [1735123456, "123456789"]
      }
    ]
  }
}
```

## K8s Secret 配置

### 創建 Secret

```bash
kubectl create secret generic waas2-health-monitor-secret \
  --from-literal=slack-webhook-url='https://hooks.slack.com/services/YOUR_WEBHOOK_URLoIcwzw1I4l8yOb9VILrSZNhA' \
  --from-literal=prometheus-username='YOUR_ALIYUN_ACCESS_KEY_ID' \
  --from-literal=prometheus-password='YOUR_ALIYUN_ACCESS_KEY_SECRET' \
  -n waas2-prod
```

### 或使用 YAML

```bash
kubectl apply -f deployment/secret-v2-template.yml
```

## CronJob 環境變數

CronJob 會自動注入以下環境變數：

```yaml
env:
- name: PROMETHEUS_URL
  value: "https://workspace-default-cms-5886645564773850-cn-hongkong.cn-hongkong.log.aliyuncs.com/prometheus/workspace-default-cms-5886645564773850-cn-hongkong/aliyun-prom-c61392b504d1742f1954f31dea08f7869"
- name: PROMETHEUS_USERNAME
  valueFrom:
    secretKeyRef:
      name: waas2-health-monitor-secret
      key: prometheus-username
- name: PROMETHEUS_PASSWORD
  valueFrom:
    secretKeyRef:
      name: waas2-health-monitor-secret
      key: prometheus-password
```

## 常見問題

### Q: 為什麼查詢沒有返回數據？

可能原因：
1. **Metric 名稱錯誤**: 確認 metric 名稱正確
2. **Label 不匹配**: 檢查 namespace, pod, container label
3. **時間範圍問題**: 確認服務在查詢時間範圍內有運行
4. **數據採集延遲**: Prometheus 可能有 1-2 分鐘延遲

### Q: 如何確認 Prometheus 有收集 waas2-prod 的數據？

```bash
# 列出所有可用的 namespace
curl -u "$PROM_USER:$PROM_PASS" \
  "$PROM_URL/api/v1/query?query=count%20by%20(namespace)%20(kube_pod_info)" | jq

# 列出 waas2-prod 中的所有 pod
curl -u "$PROM_USER:$PROM_PASS" \
  "$PROM_URL/api/v1/query?query=kube_pod_info{namespace=\"waas2-prod\"}" | jq
```

### Q: Container metrics 和 kube metrics 有什麼區別？

- **Container metrics** (`container_memory_working_set_bytes`):
  - 來自 cAdvisor/kubelet
  - 實際容器資源使用情況
  - 用於記憶體/CPU 檢查

- **Kube metrics** (`kube_pod_info`, `kube_deployment_status_replicas`):
  - 來自 kube-state-metrics
  - K8s 資源狀態
  - 用於可用性檢查

### Q: 如何調整記憶體/CPU 閾值？

編輯 `health-check-v2.py` 中的判定函數：

```python
def check_memory_usage(memory_metrics: Dict, deployment: Dict) -> str:
    # 調整這些閾值
    if usage_pct < 70:  # 改為 80
        return "🟢"
    elif usage_pct < 85:  # 改為 90
        return "🟡"
    else:
        return "🔴"
```

## 未來改進

### 可能的擴展

1. **記憶體洩漏檢測（線性回歸）**:
   ```python
   from scipy import stats
   slope, _, r_value, p_value, _ = stats.linregress(timestamps, memory_values)

   if slope > 10 and r_value**2 > 0.7 and p_value < 0.05:
       return "🔴"  # Detected memory leak
   ```

2. **GC 效率分析** (需 JVM metrics):
   ```promql
   jvm_gc_pause_seconds_sum / jvm_gc_pause_seconds_count
   ```

3. **應用層 Metrics** (需應用暴露):
   ```promql
   # 錯誤率
   rate(http_requests_total{status=~"5.."}[5m]) / rate(http_requests_total[5m])

   # 延遲 P95
   histogram_quantile(0.95, http_request_duration_seconds_bucket)
   ```

## 參考資料

- [Aliyun ARMS Prometheus 文檔](https://help.aliyun.com/document_detail/182038.html)
- [Prometheus Query API](https://prometheus.io/docs/prometheus/latest/querying/api/)
- [PromQL 基礎](https://prometheus.io/docs/prometheus/latest/querying/basics/)

---

**更新時間**: 2025-12-25
**版本**: v2 (with Prometheus integration)
