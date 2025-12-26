# PIGO Memory Inspection Script

## 概述

對 PIGO pigo-rel namespace 的所有 Pod 進行記憶體巡視，生成詳細的記憶體使用分析報告。

## 功能特性

### 4 項記憶體檢查

1. **當前記憶體使用率**
   - 檢查記憶體使用 vs Limit
   - 閾值: 🟢 < 70%, 🟡 70-85%, 🔴 > 85%

2. **記憶體趨勢分析 (過去 24h)**
   - 使用 quarter-based 比較計算成長率
   - 閾值: 🟢 < 10%, 🟡 10-20%, 🔴 > 20% (洩漏風險)

3. **Request vs Limit 配置合理性**
   - 檢查資源配置是否合理
   - 提供調整建議

4. **記憶體使用排行**
   - Top 5 絕對使用量
   - Top 5 使用率

## 環境需求

- Python 3.7+
- kubectl (已配置 tp-hkidc-k8s context)
- 可訪問 PIGO 線下 Kubernetes 集群
- Prometheus 已部署在 monitoring namespace

## 配置參數

腳本中的關鍵配置（可在 `memory_inspection.py` 中修改）:

```python
NAMESPACE = "pigo-rel"
KUBE_CONTEXT = "tp-hkidc-k8s"
PROMETHEUS_URL = "http://monitoring-prometheus.monitoring.svc.cluster.local:9090"
TIME_WINDOW_HOURS = 24

# 閾值
USAGE_THRESHOLD_ATTENTION = 70.0   # 70%
USAGE_THRESHOLD_RISK = 85.0        # 85%
GROWTH_THRESHOLD_ATTENTION = 10.0  # 10%
GROWTH_THRESHOLD_RISK = 20.0       # 20%
```

## 使用方法

### 執行巡視

```bash
cd /Users/user/CLAUDE/workflows/WF-20251226-pigo-memory-inspection/script

# 直接執行
./memory_inspection.py

# 或使用 python3
python3 memory_inspection.py
```

### 輸出報告

報告自動保存至:
```
/Users/user/CLAUDE/workflows/WF-20251226-pigo-memory-inspection/data/pigo-rel-memory-inspection-YYYYMMDD.md
```

## 報告結構

生成的 Markdown 報告包含:

1. **整體摘要**
   - 總 Pod 數、健康/需關注/高風險數量
   - 記憶體洩漏風險統計

2. **記憶體使用排行榜**
   - Top 5 絕對使用量
   - Top 5 使用率

3. **逐一檢查詳情**
   - 每個 Pod 的 4 項檢查結果
   - 資源配置詳情
   - 實際使用率和百分比

4. **問題 Pod 匯總表**
   - 所有問題 Pod 的快速概覽
   - 建議處理措施

5. **結論與建議**
   - 整體健康評估
   - 緊急處理建議 (24h 內)
   - 需關注項目 (7天內)
   - 記憶體洩漏風險警告

## 模組說明

### prometheus_client.py

Prometheus 查詢客戶端，透過 kubectl exec 從 cluster 內部訪問 Prometheus API。

**主要方法**:
- `query_instant()` - 即時查詢
- `query_range()` - 範圍查詢 (時間序列)
- `get_memory_usage()` - 獲取當前記憶體使用
- `get_memory_limits()` - 獲取記憶體限制
- `get_memory_requests()` - 獲取記憶體請求
- `get_memory_trend()` - 獲取 24h 記憶體趨勢
- `get_jvm_heap_usage()` - 獲取 JVM Heap 使用 (如果可用)

### report_generator.py

Markdown 報告生成器。

**主要方法**:
- `generate_summary()` - 生成整體摘要
- `generate_ranking()` - 生成記憶體排行榜
- `generate_pod_detail()` - 生成單個 Pod 詳細檢查
- `generate_problem_summary()` - 生成問題 Pod 匯總表
- `generate_recommendations()` - 生成結論與建議
- `generate_full_report()` - 生成完整報告

### memory_inspection.py

主腳本，執行記憶體巡視邏輯。

**主要方法**:
- `discover_deployments()` - 發現所有 deployment
- `get_deployment_pods()` - 獲取 deployment 的 pod
- `analyze_memory_usage()` - 分析記憶體使用率
- `analyze_memory_trend()` - 分析記憶體趨勢 (quarter-based)
- `analyze_config_sanity()` - 分析配置合理性
- `check_deployment_memory()` - 對單個 deployment 執行 4 項檢查
- `run_inspection()` - 執行完整巡視
- `generate_report()` - 生成並保存報告

## PromQL 查詢

腳本使用的 Prometheus 查詢:

```promql
# 當前記憶體使用
container_memory_working_set_bytes{
  namespace="pigo-rel",
  pod=~"<pod_pattern>",
  container!="",
  container!="POD"
}

# 記憶體限制
kube_pod_container_resource_limits{
  namespace="pigo-rel",
  pod=~"<pod_pattern>",
  resource="memory"
}

# 記憶體請求
kube_pod_container_resource_requests{
  namespace="pigo-rel",
  pod=~"<pod_pattern>",
  resource="memory"
}

# JVM Heap 使用 (如果可用)
jvm_memory_used_bytes{
  namespace="pigo-rel",
  pod=~"<pod_pattern>",
  area="heap"
}
```

## 錯誤處理

- 如果無法連接 Prometheus，腳本會報錯並退出
- 如果某個 Pod 的 metrics 缺失，該 Pod 仍會包含在報告中，但相關數值為 0
- JVM metrics 是可選的，如果 ServiceMonitor 尚未採集到數據，不會影響基礎檢查

## 限制

- 需要 kubectl 對 pigo-rel namespace 有讀取權限
- 需要有 pigo-rel 中至少一個 Pod 可執行 wget 命令
- JVM metrics 需要 ServiceMonitor 已部署並開始採集（約 1-3 分鐘後可用）

## 範例輸出

```
PIGO Memory Inspection Script v1.0
================================================================================
開始巡視 pigo-rel namespace...
Prometheus: http://monitoring-prometheus.monitoring.svc.cluster.local:9090
時間範圍: 過去 24 小時
================================================================================
發現 15 個 deployment: nacos, pigo-api, game-api, ...

檢查 nacos...
  當前使用: 2017 Mi
  記憶體限制: 2000 Mi
  記憶體請求: 1000 Mi
  使用率分析: 🔴 使用率 100.8% >= 85.0%
  趨勢分析 (24h): 🟢 成長 +4.9%
  配置分析: 🔴 已超過 limit

...

================================================================================
巡視完成，共檢查 15 個 deployment
生成報告: /Users/user/CLAUDE/workflows/WF-20251226-pigo-memory-inspection/data/pigo-rel-memory-inspection-20251226.md
✅ 報告已保存
================================================================================
巡視結果摘要:
  🔴 高風險: 2
  🟡 需關注: 3
  🟢 健康: 10
================================================================================
```

## 相關文件

- 計畫文件: `/Users/user/.claude/plans/squishy-hatching-bonbon.md`
- 參考實現: `/Users/user/Waas2-project/gitlab.axiom-infra.com/waas2-tenant-k8s-deploy/infra/health-monitor/health-check.py`
- ServiceMonitor 配置: `/Users/user/K8S/k8s-devops/monitoring/env/hkidc-k8s/services/pigo-services-monitor-dev-stg-rel.yaml`
