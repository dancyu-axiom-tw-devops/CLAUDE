---
ref: [AGENTS.md](~/CLAUDE/AGENTS.md)
type: template
status: active
created: 2025-12-31
updated: 2026-01-02
---

# K8s Daily Monitor 處理流程 (範本)

## 使用方式

每個工作日開始時，執行以下指令：
```
執行今天的 daily monitor 處理
```

或引用此範本：
```
@/Users/user/CLAUDE/workflows/WF-20251231-1-k8s-daily-monitor-handler/PLAN.md
執行今天的 daily monitor 處理
```

Claude 會依據本範本自動執行健康檢查分析和問題處置。

## 目標

自動化處理 k8s-daily-monitor 健康檢查結果，分析問題並執行必要的配置調整。

## 專案資訊參考

**重要**: 執行處置前必須參考以下專案配置檔：

```
~/CLAUDE/profiles/
├── pigo.md      # PIGO 專案配置
├── jc.md        # JUANCASH 專案配置 & PSP 專案配置
├── waas.md      # WAAS 專案配置
└── forex.md     # FOREX 專案配置
```

## 監控環境

| 專案 | 環境 | Namespace | 報告路徑 |
|------|------|-----------|----------|
| PIGO | prod | pigo-prod | pigo/pigo-prod/YYYY/ |
| FOREX | prod | forex-prod | forex/forex-prod/YYYY/ |
| WAAS | prod | waas2-prod | waas/waas2-prod/YYYY/ |
| JC | prod | jc-prod | juancash/jc-prod/YYYY/ |

報告檔名格式: `YYMMDD-k8s-health.md`

## 執行流程

### 1. 同步數據
```bash
cd /Users/user/MONITOR/k8s-daily-monitor
git pull
```

### 2. 識別當日報告
讀取各環境的當日健康檢查報告。

### 3. 分析問題

根據報告的「問題與警告摘要」章節，識別需處置項目：

| 問題類型 | 閾值 | 處置方式 |
|----------|------|----------|
| OOMKill | 發生即處理 | 增加 memory limit |
| CPU Throttling (一般) | ≥ 10% | 增加 CPU limit |
| CPU Throttling (Runner) | > 20% | 增加 CPU limit |
| Memory P95 | > 75% | 觀察 / 增加 limit |
| Pod 重啟 | > 0 次 | 檢查原因 |
| Error logs | > 50 (24h) | 分析來源 |

### 4. 執行處置

**OOMKill 處置流程**:
1. 檢查是 Java heap 還是 container 資源問題
2. 若 Java: 檢查 `-Xmx` 設定 vs container limit
3. 調整 memory limit，確保非 heap 空間 ≥ 512Mi

**CPU Throttling 處置流程**:
1. 查看當前 CPU limit
2. 調高 limit (一般增加 50-100%)
3. 使用 kustomize 部署

**Error Logs 分析流程**:
1. 查看錯誤樣本來源
2. 判斷是應用錯誤還是外部攻擊
3. 決定處置優先級

### 5. 記錄變更

更新 `CHANGELOG.md`：
- 記錄問題描述
- 記錄根因分析
- 記錄修改內容
- 記錄部署結果

## 判斷標準 (v21 Anti-False-Positive)

| 狀態 | 符號 | 條件 | 行動 |
|------|------|------|------|
| 🟢 正常 | OK | 無異常指標 | 無需處理 |
| 🟡 Spike | SPIKE | Snapshot hit limit，無趨勢佐證 | DevOps 參考 |
| 🟠 Sustained | WATCH | 趨勢指標偏高，無行為異常 | 持續監控 |
| 🚨 Critical | CRITICAL | 符合條件組 A/B/C | 需立即處理 |

**原則**: 沒有趨勢證據，不得升級為 🚨

## 常用指令

```bash
# 查看 pod 資源
kubectl -n <namespace> get pod <pod> -o jsonpath='{.spec.containers[0].resources}' | jq

# 使用 kustomize 部署
cd <service-path>
kustomize build . | kubectl apply -f -

# 查看滾動更新狀態
kubectl -n <namespace> rollout status deployment/<name>
kubectl -n <namespace> rollout status statefulset/<name>

# 查看 nginx access log 分析
kubectl -n <namespace> exec <pod> -- cat /var/log/nginx/<log>.access.log | jq -r '.http_host' | sort | uniq -c | sort -rn
```

## 注意事項

1. **Git 規範**: 特定目錄使用 `git-tp` 而非 `git`
2. **確認環境**: 處置前確認目標環境（prod 需更謹慎）
3. **備份**: 修改前記錄原始值
4. **kustomize**: 使用 kustomize build 而非直接 apply yaml

## 執行歷史

詳見 [CHANGELOG.md](./CHANGELOG.md)
