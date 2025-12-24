# Exchange Service OOM 修復 Workflow

**建立日期**: 2025-12-23
**問題**: Production exchange-service 發生 Java Heap OutOfMemoryError
**狀態**: 已完成本地配置，待部署到 production cluster

## 快速索引

- [01-analysis.md](01-analysis.md) - 問題分析與根因
- [02-deployment-plan.md](02-deployment-plan.md) - 部署計畫與步驟
- [03-post-deployment-verification.md](03-post-deployment-verification.md) - 部署後驗證
- [04-monitoring-setup.md](04-monitoring-setup.md) - 監控設置
- [HEAP-DUMP-GUIDE.md](HEAP-DUMP-GUIDE.md) - **Heap Dump 查詢與分析指南** ⭐
- [worklogs/](worklogs/) - 工作日誌

## 問題摘要

Production 環境 exchange-service 頻繁發生 Java Heap OOM，導致：
- Pod 看起來存活（liveness probe 通過）
- 實際功能失效（OOM 後無法處理請求）
- 無自動擴展（HPA 未部署）

## 修復方案

### 1. JVM 優化
- Xms: 256m → 3072m（減少頻繁 GC）
- 啟用 G1GC（暫停時間 < 200ms）
- 新增 heap dump on OOM（問題診斷）
- 新增 GC 日誌（持續監控）

### 2. HPA 自動擴展
- minReplicas: 2（高可用）
- maxReplicas: 10（彈性擴展）
- CPU 閾值: 70%
- Memory 閾值: 75%

### 3. 滾動更新策略
- maxSurge: 1（最多 3 個 Pod）
- maxUnavailable: 0（確保 2 個 Pod 可用）
- 零停機部署

## 關鍵檔案

**Kubernetes 配置** (已修改，已 commit):
- [deployment.yml](../../../FOREX-project/prod-cloud/forex-prod-k8s-deploy/exchange-service/deployment.yml)
- [hpa.yml](../../../FOREX-project/prod-cloud/forex-prod-k8s-deploy/exchange-service/hpa.yml)
- [env/forex.env](../../../FOREX-project/prod-cloud/forex-prod-k8s-deploy/exchange-service/env/forex.env)
- [kustomization.yml](../../../FOREX-project/prod-cloud/forex-prod-k8s-deploy/exchange-service/kustomization.yml)

**部署指南**:
- [DEPLOY-GUIDE.md](../../../FOREX-project/prod-cloud/forex-prod-k8s-deploy/exchange-service/DEPLOY-GUIDE.md) - 詳細部署步驟

**自動化腳本**:
- [script/backup-config.sh](script/backup-config.sh) - 備份配置
- [script/apply-changes.sh](script/apply-changes.sh) - 應用變更
- [script/verify-deployment.sh](script/verify-deployment.sh) - 驗證部署
- [script/monitor-resources.sh](script/monitor-resources.sh) - 監控資源
- [script/rollback.sh](script/rollback.sh) - 回滾

**備份**:
- [data/backup/20251223_135549/](data/backup/20251223_135549/) - 修改前備份

## 部署狀態

- [x] ✅ 分析問題根因
- [x] ✅ 設計修復方案
- [x] ✅ 修改配置檔案
- [x] ✅ Git commit (a9dffc6)
- [ ] ⏳ 部署到 production cluster（待執行）
- [ ] ⏳ 驗證部署結果
- [ ] ⏳ 設置監控

## 部署注意事項

1. **時機**: 建議凌晨 2-4 點低峰時段
2. **權限**: 需要能訪問 forex-prod cluster
3. **監控**: 部署後需密集監控 1 小時
4. **回滾**: 如有問題可快速回滾（見 [script/rollback.sh](script/rollback.sh)）

## 預期效果

- 消除或大幅減少 OOM 事件
- 自動擴展生效（2-10 replicas）
- GC 暫停時間從 5-10s 降至 <200ms
- 零停機部署
- 完整診斷能力（GC logs, heap dumps）

## Git Commit

```
commit a9dffc6
Author: User + Claude AI
Date:   2025-12-23

Fix exchange-service OOM - JVM optimization + HPA

Changes:
- JVM: Xms 256m→3072m, enable G1GC, add heap dump
- HPA: minReplicas 2, maxReplicas 10, CPU 70%, Mem 75%
- Deployment: replicas 1→2, add RollingUpdate strategy
- Add monitoring: GC logs, heap dumps on OOM

Root cause: Frequent GC due to small Xms + no auto-scaling
Expected result: Reduce OOM events, auto-scale on load
```

## 聯絡資訊

**問題反饋**: 如部署時遇到問題，請保存：
1. Pod 狀態: `kubectl get pods -n forex-prod -l app=exchange-service`
2. Pod 日誌: `kubectl logs -n forex-prod -l app=exchange-service --tail=500`
3. HPA 狀態: `kubectl describe hpa exchange-service-hpa -n forex-prod`
4. 事件: `kubectl get events -n forex-prod --sort-by='.lastTimestamp' | head -50`

---

**最後更新**: 2025-12-23
**狀態**: 已完成配置修改與 Git commit，待部署
