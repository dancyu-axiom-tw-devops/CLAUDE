---
ref: [AGENTS.md](~/CLAUDE/AGENTS.md)
status: 已完成
created: 2025-12-30
updated: 2025-12-30
---

# waas2-prod 健康檢查異常處理

基於 2025-12-30 健康檢查報告，處理 waas2-prod 的異常項目。

## 問題摘要

來源: `k8s-daily-monitor/waas2/waas2-prod/2025/251230-k8s-health.md`

### 需立即處理 (3 項)

| # | Pod | 問題 | 原因 | 建議 |
|---|-----|------|------|------|
| 1 | ilogtail-ds-7cfb65487c-mxp6r | 2 次重啟 | Error (exit code: 1) | 檢查 OOM、liveness probe |
| 2 | ilogtail-ds-7cfb65487c-mxp6r | CPU 100% + 重啟 | 條件組 C | 調整 CPU limits |
| 3 | prod-waas2-tenant-runner-gitlab-runner | CPU throttling 44.1% | Runner 類型突發負載 | 調高 CPU limit |

### 需關注 (11 項 - 皆為瞬間尖峰)

- kafka-broker-0/1/2: CPU 100% snapshot (P95: 2-3%)
- kafka-controller-0/1/2: CPU 100% snapshot (P95: 2-4%)
- nacos-0: CPU 100% snapshot (P95: 0%)
- nginx (4 pods): CPU 100% snapshot (P95: 0%)

> 判定為短暫尖峰，無需立即處理，持續監控。

---

## 優化方案

### 方案 1: ilogtail-ds CPU/重啟問題

**現狀分析**:
- CPU 使用 16m，但顯示 100% (limit 偏低)
- 2 次重啟，exit code 1
- P95 CPU 5%，非持續壓力

**處理方式**:
1. 檢查 ilogtail-ds deployment 的 CPU limit 設定
2. 適當調高 CPU limit (建議 100m → 200m)
3. 檢查 liveness probe 設定

### 方案 2: GitLab Runner CPU Throttling

**現狀分析**:
- CPU throttling 44.1% (> 20% 閾值)
- Runner 類型有突發性 CPU 使用模式
- CI/CD job 執行時間增加約 44%

**處理方式**:
1. 調高 CPU limit (建議 500m → 1000m 或更高)
2. 考慮 limit = request * 4~5 倍
3. 或不設 limit 使用 burstable QoS

### 方案 3: 基礎設施 CPU Spike (觀察)

**現狀分析**:
- kafka/nacos/nginx 皆為瞬間尖峰
- P95 指標顯示無持續壓力
- 判定為正常突發行為

**處理方式**:
- 暫不處理，持續監控
- 若連續多天出現可考慮調整 limit

---

## 現狀分析結果

### ilogtail-ds

| 項目 | 現值 | 狀態 |
|------|------|------|
| CPU request | 300m | OK |
| CPU limit | 1000m | OK |
| Memory request | 384Mi | OK |
| Memory limit | 1Gi | OK |
| 重啟原因 | Error (exit code 1) | 應用程式問題，非資源不足 |

**結論**: 資源配置足夠，重啟是應用程式本身問題，暫不需調整 K8s 資源。

### GitLab Runner (Helm managed)

| 項目 | 現值 | 建議值 | 狀態 |
|------|------|--------|------|
| CPU request | 100m | 100m | OK |
| CPU limit | **200m** | **1000m** | 需調整 |
| Memory request | 100Mi | 100Mi | OK |
| Memory limit | 200Mi | 256Mi | 可調整 |

**結論**: CPU limit 200m 太低，造成 44.1% throttling，需調高至 1000m。

---

## 執行計畫

### Step 1: 修改 Helm values (已完成)

已更新以下檔案：
- `/Users/user/K8S/k8s-devops/helm/gitlab-runner/prod-waas2-tenant-runner/values.yaml`

變更：
- CPU limit: 200m → 1000m
- Memory limit: 200Mi → 256Mi

### Step 2: 部署 (已完成)

Deployment 已更新：
```
resources:
  limits:
    cpu: "1"           # 1000m
    memory: 256Mi
  requests:
    cpu: 100m
    memory: 100Mi
```

### Step 3: 觀察

等待下次健康檢查報告 (08:20) 確認 throttling 改善。

---

## K8s 腳本位置

- waas2-tenant-k8s-deploy: `/Users/user/Waas2-project/gitlab.axiom-infra.com/waas2-tenant-k8s-deploy/`

---

## 變更紀錄

| 時間 | 項目 | 變更 |
|------|------|------|
| 2025-12-30 | 初始化 | 建立優化計畫 |
