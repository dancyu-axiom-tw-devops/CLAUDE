# Kubernetes 上線服務健康檢查規範

> 本文件用於規範 Claude Code 協助檢查已部署在 K8s 上運行中服務的健康狀態。  
> 檢查任務透過 **K8s CronJob** 定時執行。  
> 檢查完成後產出兩份報告：**Slack Summary** 與 **Git Markdown 完整報告**。

---

## 📋 目錄

1. [輸出規範總覽](#1-輸出規範總覽)
2. [服務狀態檢查](#2-服務狀態檢查)
3. [Pod 健康檢查](#3-pod-健康檢查)
4. [資源使用檢查](#4-資源使用檢查)
5. [網路連線檢查](#5-網路連線檢查)
6. [日誌異常檢查](#6-日誌異常檢查)
7. [存儲與證書檢查](#7-存儲與證書檢查)
8. [Slack Summary 格式](#8-slack-summary-格式)
9. [Git Markdown 報告格式](#9-git-markdown-報告格式)
10. [自動化腳本範例](#10-自動化腳本範例)

---

## 1. 輸出規範總覽

### 1.1 雙軌輸出機制

```
┌─────────────────────────────────────────────────────────┐
│              K8s CronJob 定時觸發                        │
│              (每日 09:00 UTC+8)                          │
└─────────────────────────────────────────────────────────┘
                          │
                          ▼
              ┌───────────────────────┐
              │   k8s-health-checker  │
              │      Container        │
              └───────────────────────┘
                          │
                          ▼
              ┌───────────────────────┐
              │     執行各項檢查       │
              │  (kubectl get/top/logs)│
              └───────────────────────┘
                          │
            ┌─────────────┴─────────────┐
            ▼                           ▼
   ┌─────────────────┐        ┌─────────────────┐
   │  Slack Summary  │        │  Git MD Report  │
   │   (即時通知)     │        │   (完整記錄)    │
   └─────────────────┘        └─────────────────┘
            │                           │
            ▼                           ▼
   • Webhook POST             • git clone/pull
   • 3-5 行關鍵摘要            • 寫入報告檔案
   • 健康狀態 emoji            • git commit/push
   • 異常項目列表              
   • 報告連結                  
```

### 1.2 輸出檔案目錄結構

```
k8s-daily-monitor/
├── <project>/                          # 專案名稱
│   ├── 0-prod/                         # 環境 (數字前綴排序)
│   │   └── YYYY/
│   │       ├── YYMMDD-k8s-health.md
│   │       ├── YYMMDD-resource-optimization.md
│   │       └── YYMMDD-<other-checks>.md
│   ├── 1-dev/
│   │   └── YYYY/
│   ├── 2-stg/
│   │   └── YYYY/
│   └── 3-rel/
│       └── YYYY/
└── README.md                           # 總索引
```

### 1.3 環境代碼對照

| 代碼 | 環境名稱 | 說明 |
|------|----------|------|
| `0-prod` | Production | 正式環境 |
| `1-dev` | Development | 開發環境 |
| `2-stg` | Staging | 預備環境 |
| `3-rel` | Release | 發布環境 |

### 1.4 檢查報告類型

| 檔案名稱格式 | 用途 |
|--------------|------|
| `YYMMDD-k8s-health.md` | 服務健康狀態檢查 |
| `YYMMDD-resource-optimization.md` | 資源使用與優化建議 |
| `YYMMDD-security-audit.md` | 安全性稽核 |
| `YYMMDD-certificate-status.md` | 證書狀態檢查 |
| `YYMMDD-backup-status.md` | 備份狀態檢查 |

### 1.5 路徑範例

```bash
# 完整路徑範例 (2025年1月15日)
k8s-daily-monitor/my-app/0-prod/2025/250115-k8s-health.md
k8s-daily-monitor/my-app/0-prod/2025/250115-resource-optimization.md
k8s-daily-monitor/my-app/1-dev/2025/250115-k8s-health.md

# 檔名格式: YYMMDD-{check-type}.md
# 250115 = 2025年01月15日
```

---

## 2. 服務狀態檢查

### 2.1 檢查指令

```bash
# Deployment 狀態
kubectl get deployment -n <namespace> -o wide

# 副本狀態
kubectl get deployment <name> -n <namespace> \
  -o jsonpath='期望:{.spec.replicas} 就緒:{.status.readyReplicas} 可用:{.status.availableReplicas}'

# ReplicaSet 狀態
kubectl get rs -n <namespace> -l app=<app-name>
```

### 2.2 檢查項目與判斷標準

| 檢查項目 | 健康標準 | 警告標準 | 異常標準 |
|----------|----------|----------|----------|
| Deployment 狀態 | Available=True | Progressing | Available=False |
| 副本就緒率 | 100% | 80-99% | < 80% |
| ReplicaSet 數量 | 1-2 個 | 3-5 個 | > 5 個（需清理） |

---

## 3. Pod 健康檢查

### 3.1 檢查指令

```bash
# Pod 狀態總覽
kubectl get pods -n <namespace> -l app=<app-name> -o wide

# 重啟次數統計
kubectl get pods -n <namespace> -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.containerStatuses[0].restartCount}{"\n"}{end}'

# 異常 Pod
kubectl get pods -n <namespace> --field-selector=status.phase!=Running

# Pod 年齡
kubectl get pods -n <namespace> -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.startTime}{"\n"}{end}'
```

### 3.2 檢查項目與判斷標準

| 檢查項目 | 健康標準 | 警告標準 | 異常標準 |
|----------|----------|----------|----------|
| Pod 狀態 | 全部 Running | 有 Pending | CrashLoop/Error |
| Ready 狀態 | 全部 True | 部分 False | 全部 False |
| 重啟次數 (1h) | 0 | 1-3 | > 3 |
| 重啟次數 (24h) | < 3 | 3-10 | > 10 |

---

## 4. 資源使用檢查 (Anti-False-Positive Edition)

### 4.0 核心原則

> ⚠️ **Anti-False-Positive 原則**
> - **寧可少報，不可誤報**
> - **Snapshot ≠ 異常**
> - **沒有趨勢證據，不得判 🚨**

### 4.1 資料蒐集 Checklist（必須先完成）

對每一個 Pod / Container，需蒐集以下資料：

#### A. 類型判斷

| 項目 | 說明 |
|------|------|
| Pod name | Pod 名稱 |
| Namespace | 命名空間 |
| 是否為 Batch 類型 | 名稱或 label 含：`cron`、`job`、`batch`、`manual-test` |

#### B. 資源配置

| 項目 | 取得方式 |
|------|----------|
| CPU request | `spec.containers[].resources.requests.cpu` |
| CPU limit | `spec.containers[].resources.limits.cpu` |
| Memory limit | `spec.containers[].resources.limits.memory` |

#### C. 即時數值 (Snapshot)

| 項目 | 取得方式 |
|------|----------|
| current CPU usage | `kubectl top pod` |
| current Memory usage | `kubectl top pod` |

#### D. 趨勢 / 高百分位（若可取得）

| 項目 | 時間範圍 | 取得方式 | 備註 |
|------|----------|----------|------|
| CPU usage 10m average | 過去 10 分鐘 | Prometheus / Metrics Server | 若無則標註 N/A |
| CPU usage P95 | 過去 30 分鐘 | Prometheus | 若無則標註 N/A |
| Memory usage P95 | 過去 30 分鐘 | Prometheus | 若無則標註 N/A |

> ⏱️ **時間範圍說明 (方案 B - 保守)**:
> - 10 分鐘平均：過濾短期噪音，確認短期趨勢
> - 30 分鐘 P95：較長觀察期，大幅減少誤報

#### E. 行為指標

| 項目 | 取得方式 | 重要性 |
|------|----------|--------|
| CPU throttling ratio | `container_cpu_cfs_throttled_periods_total` | 關鍵指標 |
| OOMKill 發生 | Pod events / `lastState.terminated.reason` | 立即異常 |
| restart count | `status.containerStatuses[].restartCount` | 行為證據 |
| exit code | `lastState.terminated.exitCode` | 應用異常 |

### 4.2 檢查指令

```bash
# Pod 資源使用 (Snapshot)
kubectl top pods -n <namespace>

# 取得資源配置
kubectl get pods -n <namespace> -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[0].resources}{"\n"}{end}'

# 取得重啟次數與 exit code
kubectl get pods -n <namespace> -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}restarts:{.status.containerStatuses[0].restartCount}{"\t"}exitCode:{.status.containerStatuses[0].lastState.terminated.exitCode}{"\n"}{end}'

# 檢查 OOMKill (從 events)
kubectl get events -n <namespace> --field-selector reason=OOMKilled

# HPA 狀態
kubectl get hpa -n <namespace>

# Prometheus 查詢 (若有)
# CPU throttling ratio
# rate(container_cpu_cfs_throttled_periods_total[5m]) / rate(container_cpu_cfs_periods_total[5m])
```

### 4.3 Decision Tree（嚴格執行，不可跳步）

```
┌─────────────────────────────────────────────────────────────────┐
│          資源健康判斷流程 (Anti-False-Positive v10)             │
└─────────────────────────────────────────────────────────────────┘

Step 0: Batch 類型判斷（最高優先）
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Pod 名稱含 cron/job/batch/manual-test?
    │
   Yes ──► ❌ 完全不檢查 CPU 使用率
    │       ✅ 只檢查：OOMKill / 執行失敗 / restart > 0
    │       無上述問題 → 🟢 正常 (Batch 類型)
    │
   No ──► 繼續 Step 1

Step 1: Memory 異常（優先於 CPU）
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
OOMKill 發生?
    │
   Yes ──► 🚨 Resource pressure (Memory) [立即]
    │
   No ──► P95(memory_usage / memory_limit) > 85%?
              │
             Yes ──► 🚨 Resource pressure (Memory)
              │
             No ──► P95(memory_usage / memory_limit) > 75%?
                        │
                       Yes ──► 🟠 Memory pressure (Watch)
                        │
                       No ──► 繼續 Step 2

Step 2: Snapshot 檢查（只能是提示，永不產生 🚨）
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
current_cpu / cpu_limit ≥ 0.9?
OR current_cpu / cpu_request ≥ 0.8?
    │
   Yes ──► 🟡 Spike candidate (記錄，待驗證)
    │       ⚠️ 此條件本身「永遠不能」產生 🚨
    │
   No ──► 🟢 正常

Step 3: 趨勢驗證（沒有這一步，不准升級為 🚨）
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

3-A: CPU 趨勢壓力（非緊急）
┌────────────────────────────────────────────┐
│ 10m_avg(cpu/request) > 0.6                 │
│ OR P95(cpu/request) > 0.7    [30min window]│
│ AND throttling < 10%                       │
└────────────────────────────────────────────┘
    → 🟠 Sustained pressure (CPU) [Watch]

3-B: 真實 CPU 資源異常（唯一可 🚨 的條件）
┌────────────────────────────────────────────┐
│ 條件組 A（最優先）:                         │
│   P95(cpu/request) ≥ 0.8   [30min window]  │
│   AND 持續時間 ≥ 15 分鐘                   │
├────────────────────────────────────────────┤
│ 條件組 B:                                   │
│   CPU throttling ratio ≥ 10%               │
├────────────────────────────────────────────┤
│ 條件組 C:                                   │
│   current_cpu / cpu_limit ≥ 0.9            │
│   AND restart_count > 0                    │
└────────────────────────────────────────────┘
    → 🚨 Resource pressure (CPU)

Step 4: 沒有趨勢資料時的保守規則（非常重要）
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
只有 snapshot 資料?
AND 沒有 P95 / average / throttling?
AND 沒有 restart?
    │
   Yes ──► 🟡 Spike detected (一律降級)
            ⚠️ 標註：「因缺乏趨勢與行為指標，無法判定為持續性資源壓力」

Step 5: 重啟與程式異常（獨立於資源）
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
restart_count > 0 AND exit_code != 0?
    │
   Yes ──► 🚨 Application instability
            (即使 CPU / Memory 正常)
```

### 4.4 判斷標準總表

| 狀態 | 符號 | 條件 | 行動 |
|------|------|------|------|
| 🟢 正常 | OK | 無異常指標 | 無需處理 |
| 🟡 Spike detected | SPIKE | Snapshot hit limit，無趨勢佐證 | DevOps 參考，不需立即行動 |
| 🟠 Sustained pressure | WATCH | 趨勢指標偏高，無行為異常 | 持續監控，評估擴容 |
| 🚨 Resource pressure | CRITICAL | 符合條件組 A/B/C | 需立即處理 |
| 🚨 Application instability | CRITICAL | restart + exit_code != 0 | 需立即處理 |

### 4.5 🚨 異常必須包含的資訊

每一筆 🚨 輸出必須包含：

```markdown
**🚨 [Pod 名稱]: Resource pressure (CPU/Memory)**

| 項目 | 數值 |
|------|------|
| 觸發條件組 | A / B / C |
| 使用指標 | P95 / throttling / restart |
| P95 CPU (request) | 85% (≥ 10 分鐘) |
| Throttling ratio | 12% |
| Restart count | 2 |

📊 **為什麼不是 snapshot 誤判**:
- P95 數據顯示持續高位 (非瞬間尖峰)
- 伴隨 throttling / restart 行為指標

💡 **建議行動**:
- 增加 CPU request/limit
- 檢查應用是否有效能問題
- 考慮 HPA 水平擴展
```

### 4.6 標準輸出語句

#### 🟡 Spike 標準語句

```
觀測到瞬間 CPU 使用達上限，但缺乏趨勢與行為證據，判定為短暫尖峰。
因缺乏趨勢與行為指標，無法判定為持續性資源壓力。建議持續監控。
```

#### 🟠 Watch 標準語句

```
CPU 使用率趨勢偏高，但未達異常閾值且無行為指標，列入觀察清單。
Memory 使用率接近警戒值，建議評估是否需要擴容。
```

#### 🚨 Critical 標準語句

```
CPU 使用率於高百分位長時間維持高位，並伴隨 [throttling/restart] 行為指標，屬實際資源壓力。
發生 OOMKill，Memory 資源不足，需立即處理。
應用程式異常重啟，exit code 非零，需檢查應用狀態。
```

---

## 5. 網路連線檢查

### 5.1 檢查指令

```bash
# Service 端點
kubectl get endpoints <service> -n <namespace>

# Ingress 狀態
kubectl get ingress -n <namespace>

# 連通性測試
kubectl exec -it <pod> -n <namespace> -- curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/healthz
```

### 5.2 檢查項目與判斷標準

| 檢查項目 | 健康標準 | 警告標準 | 異常標準 |
|----------|----------|----------|----------|
| Endpoints 數量 | = Ready Pods | < Ready Pods | 0 |
| Health Check | HTTP 200 | HTTP 5xx 偶發 | 持續失敗 |
| Ingress | 正常運作 | 有錯誤日誌 | 無法訪問 |

---

## 6. 日誌異常檢查

### 6.1 檢查指令

```bash
# 錯誤日誌統計
kubectl logs -l app=<app-name> -n <namespace> --tail=10000 --since=1h | grep -ci "error"

# 警告日誌統計  
kubectl logs -l app=<app-name> -n <namespace> --tail=10000 --since=1h | grep -ci "warn"

# 最近錯誤樣本
kubectl logs -l app=<app-name> -n <namespace> --tail=5000 --since=1h | grep -i "error" | tail -5
```

### 6.2 檢查項目與判斷標準

| 檢查項目 | 健康標準 | 警告標準 | 異常標準 |
|----------|----------|----------|----------|
| Error 數量 (1h) | < 10 | 10-50 | > 50 |
| Warn 數量 (1h) | < 50 | 50-200 | > 200 |
| OOM/Panic | 0 | - | > 0 |

---

## 7. 存儲與證書檢查

### 7.1 檢查指令

```bash
# PVC 狀態
kubectl get pvc -n <namespace>

# 存儲使用量
kubectl exec -it <pod> -n <namespace> -- df -h | grep -E "^/dev|Filesystem"

# 證書到期
kubectl get secret <tls-secret> -n <namespace> -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -enddate
```

### 7.2 檢查項目與判斷標準

| 檢查項目 | 健康標準 | 警告標準 | 異常標準 |
|----------|----------|----------|----------|
| PVC 狀態 | Bound | - | Pending/Lost |
| 存儲使用率 | < 70% | 70-85% | > 85% |
| 證書有效期 | > 14 天 | 7-14 天 | < 7 天 |

---

## 8. Slack Summary 格式

### 8.1 格式規範

Slack 訊息應簡潔有力，包含：
- 整體健康狀態 emoji
- 關鍵數據摘要
- 異常項目列表
- 完整報告連結

### 8.2 訊息模板 (v9 格式)

**摘要欄位說明**:
- 每個摘要項目前都有對應的狀態 emoji (✅/⚠️/🚨)
- 當指標異常時會顯示補充說明

#### ✅ 健康狀態 - 全部正常

```
✅ *K8s 服務健康檢查報告*
━━━━━━━━━━━━━━━━━━━━━━━━━━
📍 *專案*: my-app
📍 *環境*: production (0-prod)
📍 *Namespace*: my-app-prod
🕐 *時間*: 2025-01-15 09:00:00 (UTC+8)
━━━━━━━━━━━━━━━━━━━━━━━━━━
*檢查結果*: 全部正常 ✅

📊 *摘要*
• Pods: ✅ 6/6 Running
• 資源: ✅ CPU 45% | Memory 62%
• 錯誤日誌: ✅ 3 (24h)
• 憑證: ✅ 2 certs, min 89 days

📎 <https://github.com/xxx/k8s-daily-monitor/my-app/0-prod/2025/250115-k8s-health.md|完整報告>
```

#### ⚠️ 健康狀態 - 有警告 (含 CPU Spike)

```
⚠️ *K8s 服務健康檢查報告*
━━━━━━━━━━━━━━━━━━━━━━━━━━
📍 *專案*: my-app
📍 *環境*: production (0-prod)
📍 *Namespace*: my-app-prod
🕐 *時間*: 2025-01-15 09:00:00 (UTC+8)
━━━━━━━━━━━━━━━━━━━━━━━━━━
*檢查結果*: 發現 3 項警告 ⚠️

📊 *摘要*
• Pods: ✅ 6/6 Running
• 資源: ⚠️ CPU 28% | Memory 32%
• 錯誤日誌: ✅ 0 (24h)
• 憑證: ✅ 2 certs, min 69 days

⚠️ *警告項目*
1. nacos-xxx: CPU 100% (approaching limit)
2. pigo-api-xxx: CPU 100% (approaching limit)
3. pigo-office-xxx: CPU 100% (approaching limit)

📎 <https://github.com/xxx/k8s-daily-monitor/my-app/0-prod/2025/250115-k8s-health.md|完整報告>
```

#### 🚨 健康狀態 - 有異常

```
🚨 *K8s 服務健康檢查報告*
━━━━━━━━━━━━━━━━━━━━━━━━━━
📍 *專案*: my-app
📍 *環境*: production (0-prod)
📍 *Namespace*: my-app-prod
🕐 *時間*: 2025-01-15 09:00:00 (UTC+8)
━━━━━━━━━━━━━━━━━━━━━━━━━━
*檢查結果*: 發現 2 項異常 🚨

📊 *摘要*
• Pods: 🚨 4/6 Running (2 個未 Running)
• 資源: 🚨 CPU 45% | Memory 78%
• 錯誤日誌: 🚨 156 (24h)
• 憑證: ⚠️ 2 certs, min 10 days

🚨 *異常項目*
1. api-server-xxx: OOMKill detected
2. worker-xxx: CPU 95% (limit) + 3 restarts

⚠️ *警告項目*
1. pigo-api-xxx: CPU 100% (approaching limit)
2. Certificate pigo-dev.com: expires in 10 days

📎 <https://github.com/xxx/k8s-daily-monitor/my-app/0-prod/2025/250115-k8s-health.md|完整報告>
```

### 8.3 Slack 摘要欄位狀態判斷規則 (Anti-False-Positive)

| 欄位 | ✅ 正常 | ⚠️ 警告 | 🚨 異常 | 備註 |
|------|---------|---------|---------|------|
| Pods | 全部 Running | 1 個未 Running | > 1 個未 Running | 顯示 (N 個未 Running) |
| 資源 | 無異常 | 🟡 Spike / 🟠 Watch | 🚨 Resource pressure | **見下方說明** |
| 錯誤日誌 | ≤ 10 (24h) | 10-50 (24h) | > 50 (24h) | 統計 24 小時 |
| 憑證 | ≥ 14 天 | 7-14 天 | < 7 天 | 顯示最短天數 |

**資源欄位判斷邏輯 (Anti-False-Positive)**:

```
Slack 資源狀態判斷：

🚨 異常 (顯示 🚨):
  - 任一 Pod 發生 OOMKill
  - 任一 Pod 符合 CPU 條件組 A/B/C
  - 任一 Pod 有 Application instability

⚠️ 警告 (顯示 ⚠️):
  - 有 🟡 Spike detected (snapshot hit, 無趨勢)
  - 有 🟠 Sustained pressure (趨勢偏高)
  - 有 🟠 Memory pressure (Watch)

✅ 正常 (顯示 ✅):
  - 所有 Pod 資源狀態正常
```

**重要**: Slack 摘要中 🟡/🟠 項目只顯示在警告區，不顯示在異常區。

### 8.4 Slack API 發送範例

```bash
# 使用 curl 發送 Slack 訊息
curl -X POST https://hooks.slack.com/services/YOUR/WEBHOOK/URL \
  -H 'Content-type: application/json' \
  -d '{
    "channel": "#k8s-alerts",
    "username": "K8s Health Bot",
    "icon_emoji": ":kubernetes:",
    "text": "✅ *K8s 服務健康檢查報告*\n...",
    "unfurl_links": false
  }'
```

---

## 9. Git Markdown 報告格式

### 9.1 報告模板 (v10 Anti-False-Positive)

````markdown
# K8s 服務健康檢查報告

## 基本資訊

| 項目 | 數值 |
|------|------|
| 專案 | my-app |
| 環境 | Production |
| 環境代碼 | 0-prod |
| Namespace | my-app-prod |
| 檢查時間 | 2025-01-15 09:00:00 (UTC+8) |
| 整體狀態 | ✅ 健康 / ⚠️ 警告 / 🚨 異常 |
| 報告路徑 | `k8s-daily-monitor/my-app/0-prod/2025/250115-k8s-health.md` |
| 工具版本 | pigo-health-monitor v10 |

---

## 檢查結果總覽

| 類別 | 狀態 | 摘要 |
|------|------|------|
| 服務狀態 | ✅ | 3 Deployments |
| Pod 健康 | ✅ | 6/6 Running, Restarts: 0 |
| 資源使用 | ⚠️ | 🟡 1 spike, 🚨 0 critical |
| 網路 | ✅ | 6 endpoints, 0 empty |
| 日誌 | ✅ | Error: 3, Warn: 15 (24h) |
| 儲存 | ✅ | 2 PVCs, 64% max |
| 憑證 | ✅ | 2 certs, min 89 days |

---

## 1. 服務狀態檢查

### Deployment 狀態

| Name | Ready | Up-to-date | Available | Age |
|------|-------|------------|-----------|-----|
| api-server | 3/3 | 3 | 3 | 15d |
| worker | 3/3 | 3 | 3 | 15d |

### 檢查結果
- ✅ 所有 Deployment 狀態正常
- ✅ 副本數量符合預期

---

## 2. Pod 健康檢查

### Pod 狀態

| Name | Status | Ready | Restarts | Age | Node |
|------|--------|-------|----------|-----|------|
| api-server-xxx-a1b2c | Running | 1/1 | 0 | 2d | node-1 |
| api-server-xxx-d3e4f | Running | 1/1 | 0 | 2d | node-2 |
| api-server-xxx-g5h6i | Running | 1/1 | 1 | 2d | node-3 |
| worker-xxx-j7k8l | Running | 1/1 | 0 | 2d | node-1 |
| worker-xxx-m9n0o | Running | 1/1 | 0 | 2d | node-2 |
| worker-xxx-p1q2r | Running | 1/1 | 0 | 2d | node-3 |

### 重啟統計
- 過去 1 小時: 0 次
- 過去 24 小時: 1 次

### 檢查結果
- ✅ 所有 Pod 狀態為 Running
- ✅ 所有 Pod Ready 狀態正常
- ✅ 重啟次數在正常範圍

---

## 3. 資源使用檢查 (Anti-False-Positive)

### 資源配置與即時數值

#### 服務類工作負載

| 名稱 | 類型 | CPU req | CPU limit | Mem limit | 狀態 |
|------|------|---------|-----------|-----------|------|
| api-server-xxx-a1b2c | Service | 100m | 500m | 512Mi | ✅ |
| api-server-xxx-d3e4f | Service | 100m | 500m | 512Mi | ✅ |
| worker-xxx-j7k8l | Service | 200m | 1000m | 1Gi | 🟡 |

#### Batch 類工作負載

| 名稱 | 類型 | 狀態 | 備註 |
|------|------|------|------|
| cron-job-xxx | Batch | ✅ | 不檢查 CPU，僅監控 OOMKill |

### Snapshot 數值 (即時)

| 名稱 | CPU | CPU % (req) | CPU % (limit) | Memory | Mem % | Snapshot 狀態 |
|------|-----|-------------|---------------|--------|-------|---------------|
| api-server-xxx-a1b2c | 120m | 120% | 24% | 256Mi | 50% | 🟢 |
| api-server-xxx-d3e4f | 135m | 135% | 27% | 280Mi | 55% | 🟢 |
| worker-xxx-j7k8l | 850m | 425% | 85% | 180Mi | 18% | 🟡 Spike |

### 趨勢與行為指標

| 名稱 | 10m Avg | P95 (30min) | Throttling | Restart | OOMKill | 趨勢判定 |
|------|---------|-------------|------------|---------|---------|----------|
| api-server-xxx-a1b2c | 45% | 52% | 0% | 0 | ❌ | 🟢 正常 |
| api-server-xxx-d3e4f | 48% | 55% | 0% | 0 | ❌ | 🟢 正常 |
| worker-xxx-j7k8l | 62% | 68% | 2% | 0 | ❌ | 🟡 Spike (無趨勢佐證) |

> ℹ️ **趨勢資料來源**: Prometheus metrics (若無趨勢資料則標註 N/A)
> ⏱️ **觀察時間**: 10m Avg = 過去 10 分鐘平均, P95 = 過去 30 分鐘第 95 百分位

### 資源分析摘要

| 項目 | 數值 |
|------|------|
| 服務類工作負載數 | 6 |
| Batch 工作負載數 | 1 |
| 🚨 Resource pressure (CPU) | 0 |
| 🚨 Resource pressure (Memory) | 0 |
| 🟠 Sustained pressure | 0 |
| 🟡 Spike detected | 1 |
| 🟢 正常 | 6 |

### 🟡 尖峰觀測區 (DevOps 參考，不需立即行動)

| Pod | Snapshot | 趨勢驗證 | 結論 |
|-----|----------|----------|------|
| worker-xxx-j7k8l | CPU 85% (limit) | 10m avg: 62%, P95(30m): 68%, throttling: 2% | 缺乏趨勢佐證，判定為短暫尖峰 |

> 📊 觀測到瞬間 CPU 使用達上限，但缺乏趨勢與行為證據，判定為短暫尖峰。因缺乏趨勢與行為指標，無法判定為持續性資源壓力。建議持續監控。

### HPA 狀態

| Name | Reference | Min | Max | Current | Target |
|------|-----------|-----|-----|---------|--------|
| api-server-hpa | Deployment/api-server | 3 | 10 | 3 | CPU 70% |
| worker-hpa | Deployment/worker | 3 | 8 | 3 | CPU 70% |

---

## 4. 網路連線檢查

### Service Endpoints

| Service | Type | Endpoints | Port |
|---------|------|-----------|------|
| api-server-svc | ClusterIP | 3 | 8080 |
| worker-svc | ClusterIP | 3 | 8080 |

### Ingress 狀態

| Name | Host | Path | Backend | Status |
|------|------|------|---------|--------|
| api-ingress | api.example.com | / | api-server-svc:8080 | ✅ |

### 健康檢查端點

| Endpoint | Response | Latency |
|----------|----------|---------|
| /healthz | 200 OK | 5ms |
| /ready | 200 OK | 8ms |

### 檢查結果
- ✅ 所有 Service Endpoints 正常
- ✅ Ingress 配置正確
- ✅ 健康檢查端點回應正常

---

## 5. 日誌異常檢查

### 日誌統計 (過去 1 小時)

| Level | Count | 趨勢 |
|-------|-------|------|
| ERROR | 8 | ↓ (昨日: 12) |
| WARN | 45 | → (昨日: 43) |
| INFO | 15,234 | → |

### 最近錯誤樣本

```
[2025-01-15 08:45:23] ERROR: Connection timeout to redis-master:6379
[2025-01-15 08:32:11] ERROR: Request timeout after 30s - /api/v1/reports
[2025-01-15 08:15:02] ERROR: Connection timeout to redis-master:6379
```

### 檢查結果
- ✅ 錯誤日誌數量在正常範圍
- ⚠️ 發現 Redis 連線超時，建議關注

---

## 6. 存儲狀態檢查

### PVC 狀態

| Name | Status | Volume | Capacity | Used |
|------|--------|--------|----------|------|
| api-data-pvc | Bound | pv-xxx-001 | 50Gi | 32Gi (64%) |
| worker-data-pvc | Bound | pv-xxx-002 | 100Gi | 68Gi (68%) |

### 檢查結果
- ✅ 所有 PVC 狀態為 Bound
- ✅ 存儲使用率在正常範圍

---

## 7. 證書狀態檢查

### TLS 證書

| Secret | Domain | Issuer | Expiry | Days Left |
|--------|--------|--------|--------|-----------|
| api-tls | api.example.com | Let's Encrypt | 2025-04-15 | 89 |

### 檢查結果
- ✅ 證書有效期充足

---

## 異常與警告彙整 (Anti-False-Positive)

### 🚨 異常摘要區 (需立即處理)

> ⚠️ 只允許以下類型出現在此區塊：
> - 🚨 Resource pressure (CPU)
> - 🚨 Resource pressure (Memory)
> - 🚨 Application instability

*本次檢查無異常項目*

<!-- 若有異常，格式如下：

**🚨 worker-xxx-j7k8l: Resource pressure (CPU)**

| 項目 | 數值 |
|------|------|
| 觸發條件組 | B |
| 關鍵指標 | CPU throttling ratio |
| Throttling | 15% (≥ 10% 閾值) |
| P95 CPU (request) | 82% |
| Restart count | 0 |
| OOMKill | ❌ |

📊 **為什麼不是 snapshot 誤判**:
- CPU throttling ratio 達 15%，超過 10% 閾值
- 表示 Pod 實際受到 CPU 資源限制影響

💡 **建議行動**:
1. 增加 CPU request/limit
2. 檢查應用是否有 CPU 密集運算
3. 考慮 HPA 水平擴展

📝 **標準結論**: CPU 使用率於高百分位長時間維持高位，並伴隨 throttling 行為指標，屬實際資源壓力。

-->

### 🟡 尖峰觀測區 (DevOps 參考，不需立即行動)

> 用途：記錄 snapshot hit limit 但無趨勢佐證者

| Pod | Snapshot 觸發 | 趨勢驗證結果 | 行為指標 | 結論 |
|-----|---------------|--------------|----------|------|
| worker-xxx-j7k8l | CPU 85% (limit) | 10m avg: 62%, P95(30m): 68% | throttling: 2%, restart: 0 | 🟡 Spike |

**worker-xxx-j7k8l 詳細分析**:

| 檢查項目 | 數值 | 閾值 | 結果 |
|----------|------|------|------|
| Snapshot CPU/limit | 85% | ≥ 90% | ❌ 未達 |
| Snapshot CPU/request | 425% | ≥ 80% | ✅ 觸發 |
| 10m avg CPU/request | 62% | > 60% | ⚠️ 接近 |
| P95 CPU/request (30m) | 68% | ≥ 80% | ❌ 未達 |
| Throttling ratio | 2% | ≥ 10% | ❌ 未達 |
| Restart count | 0 | > 0 | ❌ 未達 |

📝 **標準結論**: 觀測到瞬間 CPU 使用達上限，但缺乏趨勢與行為證據，判定為短暫尖峰。因缺乏趨勢與行為指標，無法判定為持續性資源壓力。

### 🟠 持續壓力觀察區 (需持續監控)

> 趨勢指標偏高但未達異常閾值，列入觀察

*本次檢查無持續壓力項目*

<!-- 若有，格式如下：

| Pod | 5m Avg | P95 | Throttling | 建議 |
|-----|--------|-----|------------|------|
| api-server-xxx | 65% | 72% | 5% | 持續監控，評估擴容 |

-->

### 📋 判斷條件參考表

| 條件組 | 觸發條件 | 狀態 |
|--------|----------|------|
| Memory OOM | OOMKill 發生 | 🚨 Resource pressure (Memory) |
| Memory P95 | P95(mem/limit) > 85% [30min] | 🚨 Resource pressure (Memory) |
| Memory Watch | P95(mem/limit) > 75% [30min] | 🟠 Memory pressure (Watch) |
| CPU 條件組 A | P95(cpu/req) ≥ 80% [30min] + 持續 ≥ 15min | 🚨 Resource pressure (CPU) |
| CPU 條件組 B | Throttling ≥ 10% | 🚨 Resource pressure (CPU) |
| CPU 條件組 C | Snapshot ≥ 90% (limit) + restart > 0 | 🚨 Resource pressure (CPU) |
| CPU 趨勢壓力 | 10m avg > 60% OR P95 > 70%, throttling < 10% | 🟠 Sustained pressure |
| CPU Spike | Snapshot hit limit, 無趨勢佐證 | 🟡 Spike detected |
| App 異常 | restart > 0 + exit_code != 0 | 🚨 Application instability |

---

## 建議事項

1. **短期 (本週)**
   - 監控 api-server CPU 使用趨勢
   - 排查 Redis 連線超時問題

2. **中期 (本月)**
   - 評估是否需要調整 HPA 閾值
   - 檢查 Redis 連線池配置

3. **長期**
   - 無

---

## 附錄：原始檢查數據

<details>
<summary>點擊展開完整指令輸出</summary>

### kubectl get pods -o wide
```
NAME                          READY   STATUS    RESTARTS   AGE   IP            NODE
api-server-xxx-a1b2c          1/1     Running   0          2d    10.0.1.15     node-1
api-server-xxx-d3e4f          1/1     Running   0          2d    10.0.2.22     node-2
...
```

### kubectl top pods
```
NAME                          CPU(cores)   MEMORY(bytes)
api-server-xxx-a1b2c          120m         256Mi
api-server-xxx-d3e4f          135m         280Mi
...
```

### kubectl get events
```
LAST SEEN   TYPE      REASON    OBJECT                MESSAGE
5m          Normal    Pulled    pod/api-server-xxx    Successfully pulled image
...
```

</details>

---

*報告產生時間: 2025-01-15 09:00:00 UTC+8*  
*檢查工具版本: k8s-health-check v1.0*
````

### 9.2 報告索引 README.md 格式

根目錄 `k8s-daily-monitor/README.md`:

```markdown
# K8s 日常監控報告索引

## 專案列表

| 專案 | 環境 | 最新檢查 | 狀態 |
|------|------|----------|------|
| my-app | 0-prod | 2025-01-15 | ✅ |
| my-app | 1-dev | 2025-01-15 | ✅ |
| my-app | 2-stg | 2025-01-15 | ⚠️ |
| api-service | 0-prod | 2025-01-15 | ✅ |

## 目錄結構

- [my-app](./my-app/)
  - [0-prod](./my-app/0-prod/)
  - [1-dev](./my-app/1-dev/)
  - [2-stg](./my-app/2-stg/)
- [api-service](./api-service/)
  - [0-prod](./api-service/0-prod/)
```

專案環境目錄 `k8s-daily-monitor/<project>/<env>/README.md`:

```markdown
# my-app - Production (0-prod) 檢查記錄

## 最新報告

| 日期 | 健康檢查 | 資源優化 | 狀態 |
|------|----------|----------|------|
| 2025-01-15 | [報告](./2025/250115-k8s-health.md) | [報告](./2025/250115-resource-optimization.md) | ✅ |
| 2025-01-14 | [報告](./2025/250114-k8s-health.md) | [報告](./2025/250114-resource-optimization.md) | ✅ |
| 2025-01-13 | [報告](./2025/250113-k8s-health.md) | [報告](./2025/250113-resource-optimization.md) | ⚠️ |

## 歷史記錄

- [2025](./2025/)
- [2024](./2024/)
```

年度目錄 `k8s-daily-monitor/<project>/<env>/YYYY/README.md`:

```markdown
# my-app - Production - 2025

## 1 月

| 日期 | 健康檢查 | 資源優化 | 狀態 |
|------|----------|----------|------|
| 15 | [✅](./250115-k8s-health.md) | [✅](./250115-resource-optimization.md) | ✅ |
| 14 | [✅](./250114-k8s-health.md) | [✅](./250114-resource-optimization.md) | ✅ |
| 13 | [⚠️](./250113-k8s-health.md) | [✅](./250113-resource-optimization.md) | ⚠️ |

## 統計

- 總檢查次數: 15
- 健康: 12 (80%)
- 警告: 2 (13%)
- 異常: 1 (7%)
```

---

## 10. 自動化腳本範例

### 10.1 完整檢查腳本

```bash
#!/bin/bash
# k8s-health-check.sh
# K8s 服務健康檢查腳本 - 輸出 Slack Summary + Git MD Report

set -e

# ====== 配置區 ======
PROJECT="${1:-my-app}"
ENV_NAME="${2:-production}"
NAMESPACE="${3:-}"
APP_LABEL="${4:-}"

SLACK_WEBHOOK="${SLACK_WEBHOOK_URL:-}"
BASE_DIR="${BASE_DIR:-./k8s-daily-monitor}"
GIT_PUSH="${GIT_PUSH:-false}"
GIT_REPO_URL="${GIT_REPO_URL:-}"

# ====== 環境代碼對照 ======
get_env_code() {
  case "$1" in
    production|prod) echo "0-prod" ;;
    development|dev) echo "1-dev" ;;
    staging|stg)     echo "2-stg" ;;
    release|rel)     echo "3-rel" ;;
    *)               echo "0-prod" ;;
  esac
}

ENV_CODE=$(get_env_code "$ENV_NAME")

# ====== 日期變數 ======
YEAR=$(date '+%Y')
YYMMDD=$(date '+%y%m%d')
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# ====== 報告路徑 ======
REPORT_DIR="${BASE_DIR}/${PROJECT}/${ENV_CODE}/${YEAR}"
REPORT_FILE="${REPORT_DIR}/${YYMMDD}-k8s-health.md"
REPORT_FILENAME="${YYMMDD}-k8s-health.md"

# ====== Namespace 預設值 ======
if [ -z "$NAMESPACE" ]; then
  NAMESPACE="${PROJECT}-${ENV_NAME}"
fi

OVERALL_STATUS="healthy"
WARNINGS=()
CRITICALS=()

# ====== 輔助函數 ======
log() { echo "[$(date '+%H:%M:%S')] $1"; }

add_warning() {
  WARNINGS+=("$1")
  if [ "$OVERALL_STATUS" = "healthy" ]; then
    OVERALL_STATUS="warning"
  fi
}

add_critical() {
  CRITICALS+=("$1")
  OVERALL_STATUS="critical"
}

# ====== 檢查函數 ======
check_pods() {
  log "檢查 Pod 狀態..."
  
  local total=$(kubectl get pods -n "$NAMESPACE" ${APP_LABEL:+-l app=$APP_LABEL} --no-headers 2>/dev/null | wc -l)
  local running=$(kubectl get pods -n "$NAMESPACE" ${APP_LABEL:+-l app=$APP_LABEL} --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
  local restarts=$(kubectl get pods -n "$NAMESPACE" ${APP_LABEL:+-l app=$APP_LABEL} -o jsonpath='{range .items[*]}{.status.containerStatuses[0].restartCount}{"\n"}{end}' 2>/dev/null | awk '{s+=$1} END {print s}')
  
  POD_TOTAL=$total
  POD_RUNNING=$running
  POD_RESTARTS=${restarts:-0}
  
  POD_DETAIL=$(kubectl get pods -n "$NAMESPACE" ${APP_LABEL:+-l app=$APP_LABEL} -o wide 2>/dev/null)
  
  if [ "$running" -lt "$total" ]; then
    add_critical "Pod 狀態異常: $running/$total Running"
  fi
  
  if [ "${restarts:-0}" -gt 10 ]; then
    add_critical "Pod 重啟次數過高: $restarts"
  elif [ "${restarts:-0}" -gt 3 ]; then
    add_warning "Pod 有重啟: $restarts 次"
  fi
}

check_resources() {
  log "檢查資源使用..."
  
  if kubectl top pods -n "$NAMESPACE" &>/dev/null; then
    RESOURCE_DETAIL=$(kubectl top pods -n "$NAMESPACE" ${APP_LABEL:+-l app=$APP_LABEL} 2>/dev/null)
    
    local cpu_usage=$(echo "$RESOURCE_DETAIL" | tail -n +2 | awk '{gsub(/m/,"",$2); sum+=$2; count++} END {if(count>0) print int(sum/count); else print 0}')
    local mem_usage=$(echo "$RESOURCE_DETAIL" | tail -n +2 | awk '{gsub(/Mi/,"",$3); sum+=$3; count++} END {if(count>0) print int(sum/count); else print 0}')
    
    CPU_AVG="${cpu_usage}m"
    MEM_AVG="${mem_usage}Mi"
    
    # 計算使用率 (假設 limit: 500m CPU, 512Mi Memory)
    local cpu_pct=$((cpu_usage * 100 / 500))
    local mem_pct=$((mem_usage * 100 / 512))
    
    CPU_PCT="$cpu_pct%"
    MEM_PCT="$mem_pct%"
    
    if [ "$cpu_pct" -gt 90 ]; then
      add_critical "CPU 使用率過高: $cpu_pct%"
    elif [ "$cpu_pct" -gt 70 ]; then
      add_warning "CPU 使用率偏高: $cpu_pct%"
    fi
    
    if [ "$mem_pct" -gt 90 ]; then
      add_critical "Memory 使用率過高: $mem_pct%"
    elif [ "$mem_pct" -gt 80 ]; then
      add_warning "Memory 使用率偏高: $mem_pct%"
    fi
  else
    RESOURCE_DETAIL="metrics-server 未安裝"
    CPU_PCT="N/A"
    MEM_PCT="N/A"
  fi
  
  HPA_DETAIL=$(kubectl get hpa -n "$NAMESPACE" 2>/dev/null || echo "無 HPA")
}

check_logs() {
  log "檢查日誌異常..."
  
  local error_count=$(kubectl logs -n "$NAMESPACE" ${APP_LABEL:+-l app=$APP_LABEL} --tail=10000 --since=1h 2>/dev/null | grep -ci "error" || echo 0)
  local warn_count=$(kubectl logs -n "$NAMESPACE" ${APP_LABEL:+-l app=$APP_LABEL} --tail=10000 --since=1h 2>/dev/null | grep -ci "warn" || echo 0)
  
  LOG_ERRORS=$error_count
  LOG_WARNS=$warn_count
  
  LOG_ERROR_SAMPLES=$(kubectl logs -n "$NAMESPACE" ${APP_LABEL:+-l app=$APP_LABEL} --tail=5000 --since=1h 2>/dev/null | grep -i "error" | tail -5 || echo "無")
  
  if [ "$error_count" -gt 100 ]; then
    add_critical "錯誤日誌過多: $error_count (1h)"
  elif [ "$error_count" -gt 50 ]; then
    add_warning "錯誤日誌偏多: $error_count (1h)"
  fi
}

check_endpoints() {
  log "檢查 Service Endpoints..."
  
  ENDPOINT_DETAIL=$(kubectl get endpoints -n "$NAMESPACE" 2>/dev/null)
  
  local empty_eps=$(kubectl get endpoints -n "$NAMESPACE" -o jsonpath='{range .items[?(@.subsets==null)]}{.metadata.name}{"\n"}{end}' 2>/dev/null | wc -l)
  
  EMPTY_ENDPOINTS=$empty_eps
  
  if [ "$empty_eps" -gt 0 ]; then
    add_critical "存在無端點的 Service: $empty_eps 個"
  fi
}

check_events() {
  log "檢查最近事件..."
  
  EVENT_DETAIL=$(kubectl get events -n "$NAMESPACE" --sort-by='.lastTimestamp' 2>/dev/null | tail -15)
  WARNING_EVENTS=$(kubectl get events -n "$NAMESPACE" --field-selector type=Warning --sort-by='.lastTimestamp' 2>/dev/null | tail -10)
}

# ====== Slack 輸出 ======
generate_slack_message() {
  local status_emoji status_text
  
  case "$OVERALL_STATUS" in
    healthy)  status_emoji="✅"; status_text="全部正常 ✅" ;;
    warning)  status_emoji="⚠️"; status_text="發現 ${#WARNINGS[@]} 項警告 ⚠️" ;;
    critical) status_emoji="🚨"; status_text="發現 ${#CRITICALS[@]} 項異常 🚨" ;;
  esac
  
  local report_url="${GIT_REPO_URL}/blob/main/k8s-daily-monitor/${PROJECT}/${ENV_CODE}/${YEAR}/${REPORT_FILENAME}"
  
  local message="${status_emoji} *K8s 服務健康檢查報告*
━━━━━━━━━━━━━━━━━━━━━━━━━━
📍 *專案*: ${PROJECT}
📍 *環境*: ${ENV_NAME} (${ENV_CODE})
📍 *Namespace*: ${NAMESPACE}
🕐 *時間*: ${TIMESTAMP}
━━━━━━━━━━━━━━━━━━━━━━━━━━
*檢查結果*: ${status_text}

📊 *摘要*
• Pods: ${POD_RUNNING}/${POD_TOTAL} Running
• CPU: ${CPU_PCT} | Memory: ${MEM_PCT}
• 錯誤日誌: ${LOG_ERRORS} (1h)
• 重啟次數: ${POD_RESTARTS}"

  if [ ${#CRITICALS[@]} -gt 0 ]; then
    message+=$'\n\n🚨 *異常項目*'
    local i=1
    for item in "${CRITICALS[@]}"; do
      message+=$'\n'"${i}. ${item}"
      ((i++))
    done
  fi
  
  if [ ${#WARNINGS[@]} -gt 0 ]; then
    message+=$'\n\n⚠️ *警告項目*'
    local i=1
    for item in "${WARNINGS[@]}"; do
      message+=$'\n'"${i}. ${item}"
      ((i++))
    done
  fi
  
  message+=$'\n\n'"📎 <${report_url}|完整報告>"
  
  echo "$message"
}

send_slack() {
  if [ -z "$SLACK_WEBHOOK" ]; then
    log "未設定 SLACK_WEBHOOK_URL，跳過 Slack 通知"
    return
  fi
  
  local message=$(generate_slack_message)
  local escaped_message=$(echo "$message" | sed 's/"/\\"/g')
  
  curl -s -X POST "$SLACK_WEBHOOK" \
    -H 'Content-type: application/json' \
    -d "{
      \"username\": \"K8s Health Bot\",
      \"icon_emoji\": \":kubernetes:\",
      \"text\": \"${escaped_message}\"
    }" > /dev/null
    
  log "Slack 通知已發送"
}

# ====== Git 報告輸出 ======
generate_report() {
  mkdir -p "$REPORT_DIR"
  
  local status_text
  case "$OVERALL_STATUS" in
    healthy)  status_text="✅ 健康" ;;
    warning)  status_text="⚠️ 警告" ;;
    critical) status_text="🚨 異常" ;;
  esac

  # 生成警告和異常列表
  local critical_list=""
  if [ ${#CRITICALS[@]} -eq 0 ]; then
    critical_list="*本次檢查無異常項目*"
  else
    for item in "${CRITICALS[@]}"; do
      critical_list+="- ${item}"$'\n'
    done
  fi
  
  local warning_list=""
  if [ ${#WARNINGS[@]} -eq 0 ]; then
    warning_list="*本次檢查無警告項目*"
  else
    for item in "${WARNINGS[@]}"; do
      warning_list+="- ${item}"$'\n'
    done
  fi
  
  cat > "$REPORT_FILE" << EOF
# K8s 服務健康檢查報告

## 基本資訊

| 項目 | 值 |
|------|-----|
| 專案 | ${PROJECT} |
| 環境 | ${ENV_NAME} |
| 環境代碼 | ${ENV_CODE} |
| Namespace | ${NAMESPACE} |
| 檢查時間 | ${TIMESTAMP} |
| 整體狀態 | ${status_text} |
| 報告路徑 | \`k8s-daily-monitor/${PROJECT}/${ENV_CODE}/${YEAR}/${REPORT_FILENAME}\` |

---

## 檢查結果總覽

| 檢查類別 | 狀態 | 摘要 |
|----------|------|------|
| Pod 健康 | $([ "$POD_RUNNING" -eq "$POD_TOTAL" ] && echo "✅" || echo "❌") | ${POD_RUNNING}/${POD_TOTAL} Running, 重啟 ${POD_RESTARTS} 次 |
| 資源使用 | $([ "$OVERALL_STATUS" != "critical" ] && echo "✅" || echo "⚠️") | CPU ${CPU_PCT}, Memory ${MEM_PCT} |
| 日誌異常 | $([ "$LOG_ERRORS" -lt 50 ] && echo "✅" || echo "⚠️") | Error: ${LOG_ERRORS}, Warn: ${LOG_WARNS} |
| 網路連線 | $([ "$EMPTY_ENDPOINTS" -eq 0 ] && echo "✅" || echo "❌") | 空端點 Service: ${EMPTY_ENDPOINTS} |

---

## 1. Pod 狀態詳情

\`\`\`
${POD_DETAIL}
\`\`\`

---

## 2. 資源使用詳情

\`\`\`
${RESOURCE_DETAIL}
\`\`\`

### HPA 狀態

\`\`\`
${HPA_DETAIL}
\`\`\`

---

## 3. 日誌異常

### 統計 (過去 1 小時)
- ERROR: ${LOG_ERRORS}
- WARN: ${LOG_WARNS}

### 最近錯誤樣本

\`\`\`
${LOG_ERROR_SAMPLES}
\`\`\`

---

## 4. Service Endpoints

\`\`\`
${ENDPOINT_DETAIL}
\`\`\`

---

## 5. 最近事件

\`\`\`
${EVENT_DETAIL}
\`\`\`

### 警告事件

\`\`\`
${WARNING_EVENTS}
\`\`\`

---

## 異常與警告彙整

### 🚨 異常項目 (需立即處理)

${critical_list}

### ⚠️ 警告項目 (需關注)

${warning_list}

---

*報告產生時間: ${TIMESTAMP}*
EOF

  log "報告已產生: $REPORT_FILE"
}

update_readme() {
  local env_readme="${BASE_DIR}/${PROJECT}/${ENV_CODE}/README.md"
  local year_readme="${BASE_DIR}/${PROJECT}/${ENV_CODE}/${YEAR}/README.md"
  local status_emoji
  
  case "$OVERALL_STATUS" in
    healthy)  status_emoji="✅" ;;
    warning)  status_emoji="⚠️" ;;
    critical) status_emoji="🚨" ;;
  esac
  
  # 確保目錄存在
  mkdir -p "$(dirname "$env_readme")"
  mkdir -p "$(dirname "$year_readme")"
  
  # 更新環境 README
  if [ ! -f "$env_readme" ]; then
    cat > "$env_readme" << EOF
# ${PROJECT} - ${ENV_NAME} (${ENV_CODE}) 檢查記錄

## 最新報告

| 日期 | 健康檢查 | 狀態 |
|------|----------|------|
EOF
  fi
  
  # 插入新行到環境 README
  local date_display=$(date '+%Y-%m-%d')
  local new_row="| ${date_display} | [報告](./${YEAR}/${REPORT_FILENAME}) | ${status_emoji} |"
  sed -i "/^| 日期 | 健康檢查/a\\${new_row}" "$env_readme" 2>/dev/null || \
    sed -i '' "/^| 日期 | 健康檢查/a\\
${new_row}" "$env_readme"

  # 更新年度 README
  if [ ! -f "$year_readme" ]; then
    cat > "$year_readme" << EOF
# ${PROJECT} - ${ENV_NAME} - ${YEAR}

| 日期 | 健康檢查 | 狀態 |
|------|----------|------|
EOF
  fi
  
  local year_row="| ${date_display} | [${status_emoji}](./${REPORT_FILENAME}) | ${status_emoji} |"
  sed -i "/^| 日期 | 健康檢查/a\\${year_row}" "$year_readme" 2>/dev/null || \
    sed -i '' "/^| 日期 | 健康檢查/a\\
${year_row}" "$year_readme"
  
  log "README 索引已更新"
}

commit_report() {
  if [ "$GIT_PUSH" != "true" ]; then
    log "GIT_PUSH 未啟用，跳過 Git 提交"
    return
  fi
  
  cd "$BASE_DIR"
  git add .
  git commit -m "chore(${PROJECT}): ${ENV_CODE} health report ${YEAR}/${MONTH}/${DAY} [${OVERALL_STATUS}]"
  git push
  
  log "報告已提交至 Git"
}

# ====== 主程式 ======
main() {
  log "========================================="
  log "K8s 服務健康檢查開始"
  log "專案: $PROJECT"
  log "環境: $ENV_NAME ($ENV_CODE)"
  log "Namespace: $NAMESPACE"
  log "報告路徑: $REPORT_DIR"
  log "========================================="
  
  check_pods
  check_resources
  check_logs
  check_endpoints
  check_events
  
  log "========================================="
  log "產出報告..."
  log "========================================="
  
  generate_report
  update_readme
  send_slack
  commit_report
  
  log "========================================="
  log "檢查完成！整體狀態: $OVERALL_STATUS"
  log "報告位置: $REPORT_FILE"
  log "========================================="
  
  # 設定退出碼
  case "$OVERALL_STATUS" in
    healthy)  exit 0 ;;
    warning)  exit 0 ;;
    critical) exit 1 ;;
  esac
}

main
```

### 10.2 使用方式

```bash
# 基本使用 (預設 production 環境)
./k8s-health-check.sh my-app production

# 指定完整參數
./k8s-health-check.sh <project> <env> <namespace> <app-label>

# 範例
./k8s-health-check.sh my-app production my-app-prod app=my-app
./k8s-health-check.sh my-app dev my-app-dev
./k8s-health-check.sh api-service staging api-stg

# 完整配置
SLACK_WEBHOOK_URL="https://hooks.slack.com/services/xxx" \
GIT_PUSH=true \
GIT_REPO_URL="https://github.com/yourorg/yourrepo" \
BASE_DIR="./k8s-daily-monitor" \
./k8s-health-check.sh my-app production my-app-prod

# 環境名稱對照
# production / prod  -> 0-prod
# development / dev  -> 1-dev
# staging / stg      -> 2-stg
# release / rel      -> 3-rel
```

### 10.3 K8s CronJob 部署

#### CronJob YAML

```yaml
# k8s-health-check-cronjob.yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: k8s-health-check
  namespace: monitoring
spec:
  schedule: "0 1 * * *"  # 每天 09:00 UTC+8
  concurrencyPolicy: Forbid
  successfulJobsHistoryLimit: 7
  failedJobsHistoryLimit: 3
  jobTemplate:
    spec:
      backoffLimit: 2
      activeDeadlineSeconds: 600
      template:
        spec:
          serviceAccountName: k8s-health-checker
          restartPolicy: OnFailure
          containers:
          - name: health-check
            image: your-registry/k8s-health-checker:latest
            imagePullPolicy: Always
            env:
            - name: PROJECT
              value: "my-app"
            - name: ENV_NAME
              value: "production"
            - name: NAMESPACE
              value: "my-app-prod"
            - name: SLACK_WEBHOOK_URL
              valueFrom:
                secretKeyRef:
                  name: k8s-health-check-secrets
                  key: slack-webhook-url
            - name: GIT_REPO_URL
              value: "https://github.com/yourorg/k8s-daily-monitor"
            - name: GIT_USER
              valueFrom:
                secretKeyRef:
                  name: k8s-health-check-secrets
                  key: git-user
            - name: GIT_TOKEN
              valueFrom:
                secretKeyRef:
                  name: k8s-health-check-secrets
                  key: git-token
            resources:
              requests:
                cpu: 100m
                memory: 128Mi
              limits:
                cpu: 500m
                memory: 256Mi
---
# 多環境檢查 - 使用多個 CronJob 或單一 Job 執行多次
apiVersion: batch/v1
kind: CronJob
metadata:
  name: k8s-health-check-all-envs
  namespace: monitoring
spec:
  schedule: "0 1 * * *"
  concurrencyPolicy: Forbid
  jobTemplate:
    spec:
      template:
        spec:
          serviceAccountName: k8s-health-checker
          restartPolicy: OnFailure
          containers:
          - name: health-check
            image: your-registry/k8s-health-checker:latest
            command: ["/bin/bash", "-c"]
            args:
            - |
              # 檢查多個專案/環境
              /scripts/k8s-health-check.sh my-app production my-app-prod
              /scripts/k8s-health-check.sh my-app dev my-app-dev
              /scripts/k8s-health-check.sh api-service production api-prod
            envFrom:
            - secretRef:
                name: k8s-health-check-secrets
            resources:
              requests:
                cpu: 100m
                memory: 128Mi
              limits:
                cpu: 500m
                memory: 256Mi
```

#### ServiceAccount & RBAC

```yaml
# rbac.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: k8s-health-checker
  namespace: monitoring
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: k8s-health-checker
rules:
# Pod 相關權限
- apiGroups: [""]
  resources: ["pods", "pods/log"]
  verbs: ["get", "list"]
# Deployment, ReplicaSet 權限
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["get", "list"]
# Service, Endpoints 權限
- apiGroups: [""]
  resources: ["services", "endpoints", "events"]
  verbs: ["get", "list"]
# ConfigMap, Secret (僅檢查存在性)
- apiGroups: [""]
  resources: ["configmaps", "secrets"]
  verbs: ["get", "list"]
# PVC 權限
- apiGroups: [""]
  resources: ["persistentvolumeclaims"]
  verbs: ["get", "list"]
# HPA 權限
- apiGroups: ["autoscaling"]
  resources: ["horizontalpodautoscalers"]
  verbs: ["get", "list"]
# Ingress 權限
- apiGroups: ["networking.k8s.io"]
  resources: ["ingresses"]
  verbs: ["get", "list"]
# Node 權限 (用於 kubectl top)
- apiGroups: [""]
  resources: ["nodes"]
  verbs: ["get", "list"]
# Metrics 權限
- apiGroups: ["metrics.k8s.io"]
  resources: ["pods", "nodes"]
  verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: k8s-health-checker
subjects:
- kind: ServiceAccount
  name: k8s-health-checker
  namespace: monitoring
roleRef:
  kind: ClusterRole
  name: k8s-health-checker
  apiGroup: rbac.authorization.k8s.io
```

#### Secrets 配置

```yaml
# secrets.yaml (建議使用 SealedSecrets 或 External Secrets)
apiVersion: v1
kind: Secret
metadata:
  name: k8s-health-check-secrets
  namespace: monitoring
type: Opaque
stringData:
  slack-webhook-url: "https://hooks.slack.com/services/xxx/yyy/zzz"
  git-user: "health-check-bot"
  git-token: "ghp_xxxxxxxxxxxx"
```

#### ConfigMap - 檢查配置

```yaml
# configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: k8s-health-check-config
  namespace: monitoring
data:
  # 要檢查的專案列表
  projects.yaml: |
    projects:
      - name: my-app
        environments:
          - name: production
            code: 0-prod
            namespace: my-app-prod
            app_label: app=my-app
          - name: dev
            code: 1-dev
            namespace: my-app-dev
            app_label: app=my-app
      - name: api-service
        environments:
          - name: production
            code: 0-prod
            namespace: api-prod
            app_label: app=api
  
  # 閾值配置
  thresholds.yaml: |
    thresholds:
      cpu:
        warning: 70
        critical: 90
      memory:
        warning: 80
        critical: 95
      restarts:
        warning: 3
        critical: 10
      error_logs:
        warning: 50
        critical: 100
```

### 10.4 Docker Image

#### Dockerfile

```dockerfile
FROM alpine:3.19

# 安裝必要工具
RUN apk add --no-cache \
    bash \
    curl \
    git \
    jq \
    openssl \
    ca-certificates

# 安裝 kubectl
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
    && chmod +x kubectl \
    && mv kubectl /usr/local/bin/

# 複製腳本
COPY scripts/ /scripts/
RUN chmod +x /scripts/*.sh

WORKDIR /workspace

ENTRYPOINT ["/scripts/k8s-health-check.sh"]
```

#### 腳本更新 (支援 K8s 環境)

```bash
#!/bin/bash
# k8s-health-check.sh - K8s CronJob 版本

set -e

# ====== 配置區 ======
PROJECT="${PROJECT:-${1:-my-app}}"
ENV_NAME="${ENV_NAME:-${2:-production}}"
NAMESPACE="${NAMESPACE:-${3:-}}"
APP_LABEL="${APP_LABEL:-${4:-}}"

SLACK_WEBHOOK="${SLACK_WEBHOOK_URL:-}"
GIT_REPO="${GIT_REPO_URL:-}"
GIT_USER="${GIT_USER:-}"
GIT_TOKEN="${GIT_TOKEN:-}"

WORKSPACE="/workspace"
BASE_DIR="${WORKSPACE}/k8s-daily-monitor"

# ====== 環境代碼對照 ======
get_env_code() {
  case "$1" in
    production|prod) echo "0-prod" ;;
    development|dev) echo "1-dev" ;;
    staging|stg)     echo "2-stg" ;;
    release|rel)     echo "3-rel" ;;
    *)               echo "0-prod" ;;
  esac
}

ENV_CODE=$(get_env_code "$ENV_NAME")

# ====== 日期變數 ======
YEAR=$(date '+%Y')
YYMMDD=$(date '+%y%m%d')
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# ====== 報告路徑 ======
REPORT_DIR="${BASE_DIR}/${PROJECT}/${ENV_CODE}/${YEAR}"
REPORT_FILE="${REPORT_DIR}/${YYMMDD}-k8s-health.md"
REPORT_FILENAME="${YYMMDD}-k8s-health.md"

# ====== Namespace 預設值 ======
if [ -z "$NAMESPACE" ]; then
  NAMESPACE="${PROJECT}-${ENV_NAME}"
fi

OVERALL_STATUS="healthy"
WARNINGS=()
CRITICALS=()

# ====== 輔助函數 ======
log() { echo "[$(date '+%H:%M:%S')] $1"; }

add_warning() {
  WARNINGS+=("$1")
  if [ "$OVERALL_STATUS" = "healthy" ]; then
    OVERALL_STATUS="warning"
  fi
}

add_critical() {
  CRITICALS+=("$1")
  OVERALL_STATUS="critical"
}

# ====== Git 操作 ======
setup_git() {
  if [ -z "$GIT_REPO" ] || [ -z "$GIT_TOKEN" ]; then
    log "Git 配置不完整，跳過 Git 操作"
    return 1
  fi
  
  # 設定 Git 認證
  git config --global user.name "${GIT_USER:-k8s-health-bot}"
  git config --global user.email "${GIT_USER:-bot}@example.com"
  
  # Clone repo (使用 token 認證)
  local repo_with_auth=$(echo "$GIT_REPO" | sed "s|https://|https://${GIT_USER}:${GIT_TOKEN}@|")
  
  if [ -d "$BASE_DIR/.git" ]; then
    cd "$BASE_DIR"
    git pull origin main
  else
    git clone "$repo_with_auth" "$BASE_DIR"
    cd "$BASE_DIR"
  fi
  
  return 0
}

commit_and_push() {
  if [ -z "$GIT_REPO" ] || [ -z "$GIT_TOKEN" ]; then
    log "Git 配置不完整，跳過提交"
    return
  fi
  
  cd "$BASE_DIR"
  git add .
  
  if git diff --staged --quiet; then
    log "無變更需要提交"
    return
  fi
  
  git commit -m "chore(${PROJECT}): ${ENV_CODE} health report ${YYMMDD} [${OVERALL_STATUS}]"
  git push origin main
  
  log "報告已提交至 Git"
}

# ... (其餘檢查函數同前) ...

# ====== 主程式 ======
main() {
  log "========================================="
  log "K8s 服務健康檢查開始 (CronJob)"
  log "專案: $PROJECT"
  log "環境: $ENV_NAME ($ENV_CODE)"
  log "Namespace: $NAMESPACE"
  log "========================================="
  
  # 設定 Git
  setup_git || log "Git 設定失敗，報告將不會提交"
  
  # 確保報告目錄存在
  mkdir -p "$REPORT_DIR"
  
  # 執行檢查
  check_pods
  check_resources
  check_logs
  check_endpoints
  check_events
  
  log "========================================="
  log "產出報告..."
  log "========================================="
  
  generate_report
  update_readme
  send_slack
  commit_and_push
  
  log "========================================="
  log "檢查完成！整體狀態: $OVERALL_STATUS"
  log "報告位置: $REPORT_FILE"
  log "========================================="
  
  # 設定退出碼
  case "$OVERALL_STATUS" in
    healthy)  exit 0 ;;
    warning)  exit 0 ;;
    critical) exit 1 ;;
  esac
}

main
```

### 10.5 部署步驟

```bash
# 1. 建立 namespace
kubectl create namespace monitoring

# 2. 部署 RBAC
kubectl apply -f rbac.yaml

# 3. 建立 Secrets (建議使用 sealed-secrets)
kubectl apply -f secrets.yaml

# 4. 建立 ConfigMap
kubectl apply -f configmap.yaml

# 5. 建置並推送 Docker image
docker build -t your-registry/k8s-health-checker:latest .
docker push your-registry/k8s-health-checker:latest

# 6. 部署 CronJob
kubectl apply -f k8s-health-check-cronjob.yaml

# 7. 手動觸發測試
kubectl create job --from=cronjob/k8s-health-check k8s-health-check-manual -n monitoring

# 8. 查看執行結果
kubectl logs -f job/k8s-health-check-manual -n monitoring
```

### 10.6 監控 CronJob

```yaml
# prometheus-rules.yaml (選用)
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: k8s-health-check-alerts
  namespace: monitoring
spec:
  groups:
  - name: k8s-health-check
    rules:
    - alert: K8sHealthCheckFailed
      expr: |
        kube_job_failed{job_name=~"k8s-health-check.*"} > 0
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "K8s 健康檢查 Job 失敗"
        description: "Job {{ $labels.job_name }} 執行失敗"
    
    - alert: K8sHealthCheckMissing
      expr: |
        time() - kube_cronjob_status_last_successful_time{cronjob="k8s-health-check"} > 90000
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "K8s 健康檢查超過 25 小時未執行"
```

---

## 📋 Claude Code 執行指引

當使用者要求設定 K8s 服務檢查時，Claude Code 應：

### 步驟 1：確認檢查配置

詢問或確認：
- **專案名稱** (project)
- **環境列表** (production/dev/staging/release)
- **各環境的 Namespace**
- **應用 Label** (可選)
- **Slack Webhook URL**
- **Git Repo URL 及認證**

### 步驟 2：產生部署檔案

需要產生的檔案：
1. `rbac.yaml` - ServiceAccount 和權限配置
2. `secrets.yaml` - Slack/Git 認證 (建議用 SealedSecrets)
3. `configmap.yaml` - 專案和閾值配置
4. `cronjob.yaml` - CronJob 定義
5. `Dockerfile` - 檢查腳本容器映像
6. `k8s-health-check.sh` - 主檢查腳本

### 步驟 3：報告路徑規劃

根據配置計算報告路徑：
```
k8s-daily-monitor/{project}/{env-code}/{YYYY}/{YYMMDD}-k8s-health.md
```

環境代碼對照：
| 輸入 | 代碼 |
|------|------|
| production / prod | 0-prod |
| development / dev | 1-dev |
| staging / stg | 2-stg |
| release / rel | 3-rel |

檔名格式：`YYMMDD-{check-type}.md`
- 例：`250115-k8s-health.md` (2025年1月15日)

### 步驟 4：部署指引

提供部署步驟：
```bash
# 1. 建立 namespace
kubectl create namespace monitoring

# 2. 部署 RBAC
kubectl apply -f rbac.yaml

# 3. 建立 Secrets
kubectl apply -f secrets.yaml

# 4. 建立 ConfigMap  
kubectl apply -f configmap.yaml

# 5. 建置並推送 Docker image
docker build -t registry/k8s-health-checker:latest .
docker push registry/k8s-health-checker:latest

# 6. 部署 CronJob
kubectl apply -f cronjob.yaml

# 7. 手動測試
kubectl create job --from=cronjob/k8s-health-check test-run -n monitoring
```

### 範例對話

```
User: 幫我設定 K8s 服務檢查的 CronJob

Claude Code:
1. 請確認以下資訊：
   - 要檢查的專案名稱？
   - 要檢查哪些環境？(prod/dev/stg)
   - 各環境的 Namespace 名稱？
   - Slack Webhook URL？
   - Git Repo 存放報告？

2. 我將產生：
   - K8s 部署 YAML (RBAC, CronJob, Secrets, ConfigMap)
   - Dockerfile
   - 檢查腳本
   
3. 報告將存放於：
   k8s-daily-monitor/{project}/{env-code}/{YYYY}/{YYMMDD}-k8s-health.md
```

---

## 🔧 維運指令

### 查看 CronJob 狀態

```bash
# 列出 CronJob
kubectl get cronjob -n monitoring

# 查看最近執行的 Job
kubectl get jobs -n monitoring --sort-by=.metadata.creationTimestamp

# 查看 Job 日誌
kubectl logs -f job/<job-name> -n monitoring
```

### 手動觸發檢查

```bash
# 從 CronJob 建立一次性 Job
kubectl create job --from=cronjob/k8s-health-check manual-check-$(date +%s) -n monitoring
```

### 調整排程時間

```bash
# 修改 CronJob schedule
kubectl patch cronjob k8s-health-check -n monitoring \
  -p '{"spec":{"schedule":"0 */6 * * *"}}'  # 每 6 小時執行
```

---

> **文件版本**: 2.6 (v11 Prometheus Integration)
> **最後更新**: 2025-12-29
> **用途**: Claude Code K8s 上線服務檢查規範
> **執行方式**: K8s CronJob
> **輸出**: Slack Summary + Git MD Report
> **目錄結構**: `{project}/{env-code}/{YYYY}/{YYMMDD}-{check-type}.md`
> **當前實現版本**: pigo-health-monitor v10 (v11 規劃中)

---

## 版本歷程

| 版本 | 日期 | 變更內容 |
|------|------|----------|
| v11 | 2025-12-29 | **Prometheus Integration**: 整合 Prometheus 趨勢資料 (10m avg / 30m P95 / throttling)，完整實現 Anti-False-Positive Decision Tree |
| v10 | 2025-12-29 | **Anti-False-Positive Edition**: 完整 Decision Tree、趨勢/行為證據必填、🚨 條件組 A/B/C、🟡 尖峰觀測區、**方案 B 保守時間參數 (10m avg / 30m P95)** |
| v9 | 2025-12-29 | Slack 摘要加入各項目狀態 emoji，錯誤日誌改為 24h |
| v8 | 2025-12-29 | CPU hit limit 不再直接判異常，需有行為指標；憑證閾值 < 14 天 |
| v7 | 2025-12-29 | 加入 Decision Tree 判斷邏輯、Batch 工作負載識別 |
| v6 | 2025-12-29 | RBAC 修正、OOMKill 偵測、UTC+8 時區 |
| v5 | 2025-12-29 | 7 大檢查類別完整實現 |

---

## 附錄：Anti-False-Positive 快速參考卡

### 核心原則

```
⚠️ 寧可少報，不可誤報
⚠️ Snapshot ≠ 異常
⚠️ 沒有趨勢證據，不得判 🚨
```

### 狀態速查表

| 狀態 | 符號 | 說明 | 行動 |
|------|------|------|------|
| 🟢 正常 | OK | 所有指標正常 | 無 |
| 🟡 Spike | SPIKE | Snapshot hit, 無趨勢 | 觀察 |
| 🟠 Watch | WATCH | 趨勢偏高, 無行為異常 | 監控 |
| 🚨 Critical | CRITICAL | 符合條件組 A/B/C | 立即處理 |

### 🚨 唯一可判異常的條件

```
條件組 A: P95(cpu/req) ≥ 80% [30min] + 持續 ≥ 15min
條件組 B: Throttling ≥ 10%
條件組 C: Snapshot ≥ 90% (limit) + restart > 0
Memory:   OOMKill 或 P95(mem/limit) > 85% [30min]
App:      restart > 0 + exit_code != 0
```

### ⏱️ 時間參數 (方案 B - 保守)

| 指標 | 時間範圍 | 說明 |
|------|----------|------|
| Snapshot | 當下 | `kubectl top` 即時值 |
| 10m Avg | 過去 10 分鐘 | 短期趨勢，過濾噪音 |
| P95 | 過去 30 分鐘 | 中期趨勢，確認持續性 |
| 持續時間 | ≥ 15 分鐘 | 條件組 A 額外要求 |

### 標準語句

**🟡 Spike**:
> 觀測到瞬間 CPU 使用達上限，但缺乏趨勢與行為證據，判定為短暫尖峰。

**🚨 Critical**:
> CPU 使用率於高百分位長時間維持高位，並伴隨行為指標，屬實際資源壓力。

---

## v11: Prometheus Integration (規劃中)

### 11.1 背景與目標

v10 Anti-False-Positive 設計了完整的 Decision Tree，但目前缺乏趨勢資料來源：
- `has_trend_data = False` - 無法取得 10m avg / 30m P95 / throttling
- 所有 snapshot hit limit 都降級為 🟡 Spike (保守處理)
- 無法真正實現 🚨 條件組 A/B

**v11 目標**: 整合 Prometheus，取得真實趨勢資料，完整實現 Anti-False-Positive Decision Tree。

### 11.2 Prometheus 環境資訊

**hkidc-k8s 集群 Prometheus 配置**:

| 項目 | 值 |
|------|-----|
| Service | `monitoring-prometheus` |
| Namespace | `monitoring` |
| Endpoint | `http://monitoring-prometheus.monitoring.svc.cluster.local:9090` |
| Stack | kube-prometheus-stack v0.86.2 (Helm) |
| ServiceMonitor Label | `release: monitoring` |

### 11.3 PromQL 查詢設計

#### A. CPU 10 分鐘平均 (request-based)

```promql
# CPU 使用率 vs request (過去 10 分鐘平均)
100 * avg_over_time(
  (
    sum(rate(container_cpu_usage_seconds_total{namespace="pigo-dev", pod=~"<pod-name>.*", container!=""}[5m])) by (pod)
    /
    sum(kube_pod_container_resource_requests{namespace="pigo-dev", pod=~"<pod-name>.*", resource="cpu"}) by (pod)
  )[10m:]
)
```

#### B. CPU P95 (request-based, 30 分鐘)

```promql
# CPU 使用率 P95 vs request (過去 30 分鐘)
100 * quantile_over_time(0.95,
  (
    sum(rate(container_cpu_usage_seconds_total{namespace="pigo-dev", pod=~"<pod-name>.*", container!=""}[5m])) by (pod)
    /
    sum(kube_pod_container_resource_requests{namespace="pigo-dev", pod=~"<pod-name>.*", resource="cpu"}) by (pod)
  )[30m:]
)
```

#### C. Memory P95 (limit-based, 30 分鐘)

```promql
# Memory 使用率 P95 vs limit (過去 30 分鐘)
100 * quantile_over_time(0.95,
  (
    sum(container_memory_working_set_bytes{namespace="pigo-dev", pod=~"<pod-name>.*", container!=""}) by (pod)
    /
    sum(kube_pod_container_resource_limits{namespace="pigo-dev", pod=~"<pod-name>.*", resource="memory"}) by (pod)
  )[30m:]
)
```

#### D. CPU Throttling Ratio

```promql
# CPU Throttling 比率 (過去 10 分鐘)
100 * (
  sum(rate(container_cpu_cfs_throttled_periods_total{namespace="pigo-dev", pod=~"<pod-name>.*", container!=""}[10m])) by (pod)
  /
  sum(rate(container_cpu_cfs_periods_total{namespace="pigo-dev", pod=~"<pod-name>.*", container!=""}[10m])) by (pod)
)
```

### 11.4 整合架構

```
┌────────────────────────────────────────────────────────────────┐
│                    CronJob Pod (pigo-dev)                      │
└────────────────────────────────────────────────────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        ▼                     ▼                     ▼
┌──────────────┐    ┌─────────────────┐    ┌──────────────┐
│ kubectl top  │    │ Prometheus API  │    │ kubectl get  │
│   (Snapshot) │    │  (趨勢資料)      │    │  (Pod Info)  │
└──────────────┘    └─────────────────┘    └──────────────┘
        │                     │                     │
        └─────────────────────┼─────────────────────┘
                              ▼
              ┌───────────────────────────────┐
              │   health-check-full.py        │
              │   - collect_snapshot()        │
              │   - collect_trend_from_prom() │
              │   - apply_decision_tree()     │
              └───────────────────────────────┘
                              │
                              ▼
              ┌───────────────────────────────┐
              │   report_generator.py         │
              │   - 趨勢資料表格              │
              │   - 完整判斷依據              │
              └───────────────────────────────┘
```

### 11.5 Python 實作規劃

#### A. Prometheus 查詢模組

```python
# prometheus_client.py (新增)
import requests
from typing import Optional, Dict

class PrometheusClient:
    def __init__(self, url: str = "http://monitoring-prometheus.monitoring.svc.cluster.local:9090"):
        self.base_url = url
        self.api_path = "/api/v1/query"

    def query(self, promql: str) -> Optional[Dict]:
        """執行 PromQL 查詢"""
        try:
            response = requests.get(
                f"{self.base_url}{self.api_path}",
                params={"query": promql},
                timeout=10
            )
            if response.status_code == 200:
                return response.json()
            return None
        except Exception as e:
            print(f"[WARN] Prometheus query failed: {e}")
            return None

    def get_cpu_10m_avg(self, namespace: str, pod_prefix: str) -> Optional[float]:
        """取得 CPU 10 分鐘平均 (vs request)"""
        query = f'''
        100 * avg_over_time(
          (
            sum(rate(container_cpu_usage_seconds_total{{namespace="{namespace}", pod=~"{pod_prefix}.*", container!=""}}[5m])) by (pod)
            /
            sum(kube_pod_container_resource_requests{{namespace="{namespace}", pod=~"{pod_prefix}.*", resource="cpu"}}) by (pod)
          )[10m:]
        )
        '''
        return self._extract_value(self.query(query))

    def get_cpu_p95_30m(self, namespace: str, pod_prefix: str) -> Optional[float]:
        """取得 CPU P95 (vs request, 30 分鐘)"""
        # ... 類似實作

    def get_memory_p95_30m(self, namespace: str, pod_prefix: str) -> Optional[float]:
        """取得 Memory P95 (vs limit, 30 分鐘)"""
        # ... 類似實作

    def get_cpu_throttling_ratio(self, namespace: str, pod_prefix: str) -> Optional[float]:
        """取得 CPU Throttling 比率"""
        # ... 類似實作

    def _extract_value(self, result: Optional[Dict]) -> Optional[float]:
        """從 Prometheus 回應中提取數值"""
        if not result or result.get("status") != "success":
            return None
        data = result.get("data", {}).get("result", [])
        if data:
            return float(data[0].get("value", [None, None])[1])
        return None
```

#### B. 趨勢資料結構

```python
@dataclass
class TrendData:
    cpu_10m_avg: Optional[float] = None      # CPU 10 分鐘平均 (%)
    cpu_p95_30m: Optional[float] = None      # CPU P95 30 分鐘 (%)
    memory_p95_30m: Optional[float] = None   # Memory P95 30 分鐘 (%)
    cpu_throttling: Optional[float] = None   # CPU Throttling 比率 (%)

    @property
    def has_data(self) -> bool:
        """是否有趨勢資料"""
        return any([
            self.cpu_10m_avg is not None,
            self.cpu_p95_30m is not None,
            self.memory_p95_30m is not None,
            self.cpu_throttling is not None
        ])
```

### 11.6 報告格式更新

#### 趨勢資料表格 (新增)

```markdown
### Pod 趨勢資料 (Prometheus)

| 名稱 | CPU 10m Avg | CPU P95 (30m) | Mem P95 (30m) | Throttling | 判斷 |
|------|-------------|---------------|---------------|------------|------|
| pigo-api-xxx | 45% | 62% | 55% | 2% | 🟢 正常 |
| nacos-xxx | 78% | 85% | 60% | 12% | 🚨 條件組 B (throttling) |
| game-api-xxx | 35% | 48% | 70% | 0% | 🟢 正常 |

> ℹ️ **資料來源**: Prometheus (`monitoring-prometheus.monitoring.svc.cluster.local:9090`)
> ⏱️ **觀察時間**: 10m Avg = 過去 10 分鐘平均, P95 = 過去 30 分鐘第 95 百分位
```

### 11.7 CronJob 配置更新

需確認 CronJob Pod 可存取 Prometheus：

1. **網路存取**: `pigo-dev` namespace 可存取 `monitoring` namespace 的 Service
2. **無需額外 RBAC**: 透過 HTTP API 查詢，無需 ServiceAccount 權限
3. **環境變數**: 新增 `PROMETHEUS_URL` 環境變數

```yaml
# cronjob-docker.yml 更新
env:
  - name: PROMETHEUS_URL
    value: "http://monitoring-prometheus.monitoring.svc.cluster.local:9090"
```

### 11.8 實作步驟

| 步驟 | 說明 | 狀態 |
|------|------|------|
| 1 | 更新文檔 (K8S-SERVICE-HEALTH-CHECK-2.md) | ✅ 完成 |
| 2 | 更新 workflow 狀態 | 🔲 進行中 |
| 3 | 新增 prometheus_client.py | 🔲 待實作 |
| 4 | 更新 health-check-full.py 加入趨勢查詢 | 🔲 待實作 |
| 5 | 更新 report_generator.py 加入趨勢表格 | 🔲 待實作 |
| 6 | 更新 Dockerfile 加入 requests 依賴 | 🔲 待實作 |
| 7 | 更新 cronjob-docker.yml 加入環境變數 | 🔲 待實作 |
| 8 | 建置 Docker image v11 | 🔲 待實作 |
| 9 | 部署並測試 | 🔲 待實作 |

### 11.9 預期效果

**v10 (現況)**:
```
nacos-5645f897b-t8qs2: CPU 100% (approaching limit)
判斷: 🟡 Spike detected
原因: 因缺乏趨勢與行為指標，無法判定為持續性資源壓力
```

**v11 (整合後)**:
```
nacos-5645f897b-t8qs2: CPU 100% (approaching limit)
趨勢資料:
  - CPU 10m Avg: 78%
  - CPU P95 (30m): 85%
  - Throttling: 12%
判斷: 🚨 Resource pressure (CPU)
觸發: 條件組 B (Throttling ≥ 10%)
```

---