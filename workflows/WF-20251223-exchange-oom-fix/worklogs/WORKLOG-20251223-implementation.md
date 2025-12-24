# WORKLOG - Exchange Service OOM 修復實施

**日期**: 2025-12-23
**任務**: 修復 production exchange-service Java Heap OOM 問題
**狀態**: ✅ 配置修改完成，已 commit，待部署

---

## 實施摘要

### 完成事項 ✅

1. **配置修改**
   - 修改 [deployment.yml](../../../../FOREX-project/prod-cloud/forex-prod-k8s-deploy/exchange-service/deployment.yml)
     - replicas: 1 → 2
     - 新增 RollingUpdate strategy (maxSurge:1, maxUnavailable:0)
   - 確認 [env/forex.env](../../../../FOREX-project/prod-cloud/forex-prod-k8s-deploy/exchange-service/env/forex.env)
     - Xms: 256m → 3072m
     - 啟用 G1GC
     - 新增 heap dump on OOM
     - 新增 GC 日誌
   - 確認 [hpa.yml](../../../../FOREX-project/prod-cloud/forex-prod-k8s-deploy/exchange-service/hpa.yml)
     - minReplicas: 2, maxReplicas: 10
     - CPU 70%, Memory 75%
   - 確認 [kustomization.yml](../../../../FOREX-project/prod-cloud/forex-prod-k8s-deploy/exchange-service/kustomization.yml)
     - 包含 hpa.yml

2. **Git 版控**
   - Commit: a9dffc6
   - 包含所有配置變更
   - 完整 commit message

3. **備份**
   - 建立時間戳備份: 20251223_135549
   - 備份位置: `/Users/user/CLAUDE/docs/workflows/WF-20251223-exchange-oom-fix/data/backup/20251223_135549/`

4. **文檔**
   - ✅ [README.md](../README.md) - 概覽與快速索引
   - ✅ [01-analysis.md](../01-analysis.md) - 問題分析（4 頁詳細分析）
   - ✅ [02-deployment-plan.md](../02-deployment-plan.md) - 部署計畫（7 步驟）
   - ✅ [03-post-deployment-verification.md](../03-post-deployment-verification.md) - 驗證指南
   - ✅ [04-monitoring-setup.md](../04-monitoring-setup.md) - 監控設置

5. **自動化腳本**
   - ✅ [backup-config.sh](../script/backup-config.sh) - 備份配置
   - ✅ [apply-changes.sh](../script/apply-changes.sh) - 應用變更（帶安全檢查）
   - ✅ [verify-deployment.sh](../script/verify-deployment.sh) - 自動驗證
   - ✅ [monitor-resources.sh](../script/monitor-resources.sh) - 持續監控
   - ✅ [rollback.sh](../script/rollback.sh) - 回滾

### 待執行事項 ⏳

1. **部署到 Production**（需在能訪問 prod cluster 的環境）
   ```bash
   cd /Users/user/CLAUDE/docs/workflows/WF-20251223-exchange-oom-fix/script
   ./apply-changes.sh
   ```

2. **驗證部署**
   ```bash
   ./verify-deployment.sh
   ```

3. **啟動監控**（24 小時）
   ```bash
   ./monitor-resources.sh 300 288
   ```

---

## 實施時間線

### 2025-12-23 13:55 - 開始實施

**Phase 1: 探索與分析**
- 讀取 production deployment 配置
- 讀取 HPA 配置（發現未部署）
- 讀取 DEPLOY-GUIDE.md（發現之前的工作）
- 分析問題根因

**關鍵發現**:
1. JVM Xms 太小（256m），導致頻繁 GC
2. 使用 Parallel GC，Full GC 暫停 5-10 秒
3. HPA 配置存在但未應用（untracked）
4. Deployment 缺少 RollingUpdate strategy

### 2025-12-23 14:00 - 計畫設計

**Phase 2: 設計修復方案**
- 建立 plan file（完整修復計畫）
- 確定 3 大修復方向:
  1. JVM 優化（Xms 3GB, G1GC, heap dump）
  2. HPA 部署（2-10 replicas, auto-scaling）
  3. RollingUpdate 策略（零停機）

### 2025-12-23 13:55 - 實施配置修改

**Phase 3: 配置修改**

**Action 1: 建立 WF 工作目錄**
```bash
mkdir -p /Users/user/CLAUDE/docs/workflows/WF-20251223-exchange-oom-fix/{script,data/{backup,current},worklogs}
```
結果: ✅ 成功

**Action 2: 備份當前配置**
```bash
TIMESTAMP=20251223_135549
cp deployment.yml env/forex.env kustomization.yml \
   /Users/user/CLAUDE/docs/workflows/WF-20251223-exchange-oom-fix/data/backup/$TIMESTAMP/
```
結果: ✅ 備份完成

**Action 3: 修改 deployment.yml**
- 位置: Line 8-17
- 變更:
  ```yaml
  # Before
  spec:
    replicas: 1

  # After
  spec:
    replicas: 2
    strategy:
      type: RollingUpdate
      rollingUpdate:
        maxSurge: 1
        maxUnavailable: 0
  ```
結果: ✅ 成功

**Action 4: Git commit**
```bash
git add hpa.yml DEPLOY-GUIDE.md deployment.yml.patch deployment.yml env/forex.env kustomization.yml ...
git commit -m "Fix exchange-service OOM - JVM optimization + HPA"
```
結果: ✅ Commit a9dffc6

### 2025-12-23 14:15 - 文檔建立

**Phase 4: 建立完整文檔**

**文檔 1: README.md**
- 內容: 快速索引、問題摘要、修復方案、部署狀態
- 結果: ✅ 完成

**文檔 2: 01-analysis.md**
- 內容: 根因分析、記憶體計算、GC 行為分析、修改前後對比
- 篇幅: ~300 行
- 結果: ✅ 完成

**文檔 3: 02-deployment-plan.md**
- 內容: 7 步驟部署流程、預檢查、驗證、回滾程序
- 篇幅: ~400 行
- 結果: ✅ 完成

**文檔 4: 03-post-deployment-verification.md**
- 內容: 10 項驗證檢查、問題排查
- 篇幅: ~300 行
- 結果: ✅ 完成

**文檔 5: 04-monitoring-setup.md**
- 內容: 監控策略、7 大監控指標、Prometheus 配置、告警設置
- 篇幅: ~350 行
- 結果: ✅ 完成

### 2025-12-23 14:30 - 自動化腳本

**Phase 5: 建立自動化工具**

**腳本 1: verify-deployment.sh**
- 功能: 自動驗證 7 項檢查（Pod, Deployment, HPA, JVM, Memory, OOM, GC log）
- 輸出: ✅/❌/⚠️ 彩色輸出
- 結果: ✅ 完成

**腳本 2: monitor-resources.sh**
- 功能: 持續監控（Pod, Memory, HPA, Restarts, OOM）
- 參數: interval, count
- 告警: 5000Mi / 5500Mi / 5900Mi 閾值
- 結果: ✅ 完成

**腳本 3: rollback.sh**
- 功能: 完整回滾（還原配置、刪除 HPA、應用）
- 安全: 確認提示、備份當前狀態
- 結果: ✅ 完成

**腳本 4: backup-config.sh**
- 功能: 時間戳備份配置檔案
- 額外: 保存集群狀態（deployment, hpa, pods）
- 結果: ✅ 完成

**腳本 5: apply-changes.sh**
- 功能: 安全部署（預檢查、備份、確認、應用、監控、驗證）
- 檢查: kubectl context, Metrics Server, 集群連接
- 結果: ✅ 完成

**設置權限**:
```bash
chmod +x /Users/user/CLAUDE/docs/workflows/WF-20251223-exchange-oom-fix/script/*.sh
```
結果: ✅ 完成

---

## 配置變更詳情

### 1. JVM 參數變更

**檔案**: `env/forex.env` Line 11

**修改前**:
```bash
ARGS1=-Xms256m -Xmx4096m -XX:MetaspaceSize=256m -XX:MaxMetaspaceSize=512m -XX:MaxNewSize=2048m -XX:NewRatio=2 -XX:MinHeapFreeRatio=10 -XX:MaxHeapFreeRatio=30 -XX:+UseContainerSupport
```

**修改後**:
```bash
ARGS1=-Xms3072m -Xmx4096m -XX:MetaspaceSize=256m -XX:MaxMetaspaceSize=512m -XX:+UseG1GC -XX:MaxGCPauseMillis=200 -XX:ParallelGCThreads=4 -XX:ConcGCThreads=2 -XX:InitiatingHeapOccupancyPercent=45 -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=/forex/log/exchange-service/ -XX:+PrintGCDetails -XX:+PrintGCDateStamps -Xloggc:/forex/log/exchange-service/gc.log -XX:+UseContainerSupport
```

**改動說明**:
- ✅ Xms: 256m → 3072m（減少啟動 GC）
- ✅ 移除 MaxNewSize, NewRatio（讓 G1GC 自動管理）
- ✅ 新增 UseG1GC（低延遲 GC）
- ✅ 新增 MaxGCPauseMillis=200（目標暫停 200ms）
- ✅ 新增 HeapDumpOnOutOfMemoryError（OOM 診斷）
- ✅ 新增 GC 日誌（持續監控）

### 2. Deployment 變更

**檔案**: `deployment.yml` Line 8-17

**修改前**:
```yaml
spec:
  replicas: 1
```

**修改後**:
```yaml
spec:
  replicas: 2
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
```

**改動說明**:
- ✅ replicas: 1 → 2（高可用）
- ✅ 新增 RollingUpdate 策略（零停機）
- ✅ maxUnavailable: 0（確保至少 2 個 Pod 可用）

### 3. HPA 新增

**檔案**: `hpa.yml`（新建）

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: exchange-service-hpa
  namespace: forex-prod
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: exchange-service
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 75
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 50
        periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 60
      policies:
      - type: Percent
        value: 100
        periodSeconds: 30
      - type: Pods
        value: 2
        periodSeconds: 30
      selectPolicy: Max
```

**改動說明**:
- ✅ minReplicas: 2（高可用）
- ✅ maxReplicas: 10（彈性擴展）
- ✅ CPU 閾值: 70%
- ✅ Memory 閾值: 75%
- ✅ ScaleDown 穩定窗口: 5 分鐘
- ✅ ScaleUp 穩定窗口: 1 分鐘

### 4. Kustomization 更新

**檔案**: `kustomization.yml`

**新增**:
```yaml
resources:
  - hpa.yml  # 新增這一行
```

---

## Git 提交記錄

**Commit**: a9dffc6
**Date**: 2025-12-23
**Author**: User + Claude AI

**Files Changed**: 9 files
- `exchange-service/DEPLOY-GUIDE.md` (new file, 324 lines)
- `exchange-service/hpa.yml` (new file)
- `exchange-service/deployment.yml.patch` (new file)
- `exchange-service/deployment.yml` (modified)
- `exchange-service/env/forex.env` (modified)
- `exchange-service/kustomization.yml` (modified)
- `exchange-service/deploy.sh` (mode change +x)
- `exchange-service/destroy.sh` (mode change +x)
- `exchange-service/get-pods.sh` (mode change +x)

**Commit Message**:
```
Fix exchange-service OOM - JVM optimization + HPA

Changes:
- JVM: Xms 256m→3072m, enable G1GC, add heap dump
- HPA: minReplicas 2, maxReplicas 10, CPU 70%, Mem 75%
- Deployment: replicas 1→2, add RollingUpdate strategy (maxSurge:1, maxUnavailable:0)
- Add monitoring: GC logs, heap dumps on OOM
- Add DEPLOY-GUIDE.md with deployment instructions

Root cause:
- Frequent GC due to small Xms (256m)
- No auto-scaling (HPA not deployed)
- No RollingUpdate strategy (risky deployments)

Expected result:
- Reduce/eliminate OOM events
- Auto-scale on load (2-10 replicas)
- Zero-downtime deployments
- GC pause time < 200ms

🤖 Generated with Claude Code
Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
```

---

## 預期效果

### 記憶體使用

**修改前**:
- 啟動: ~1GB（Xms 256m）
- 穩態: 3-4GB（heap 不斷擴展）
- 峰值: 可能達 6-8GB（OOM 風險）

**修改後**:
- 啟動: ~3.5GB（Xms 3GB 立即分配）
- 穩態: 3.5-4.5GB（穩定）
- 峰值: < 5.5GB（安全緩衝 1GB）

### GC 行為

**修改前**:
- Young GC: 頻繁（heap 擴展）
- Full GC: 5-10 秒暫停
- 影響: 嚴重性能下降

**修改後**:
- Young GC: 低頻，< 50ms
- Mixed GC: < 200ms
- Full GC: 極少發生
- 影響: 幾乎無感

### 高可用

**修改前**:
- Replicas: 1（單點故障）
- 擴展: 手動
- 更新: 有停機風險

**修改後**:
- Replicas: 2-10（自動）
- 擴展: 自動（HPA）
- 更新: 零停機（RollingUpdate）

---

## 下一步行動

### 立即行動（需在 prod cluster 環境）

1. **部署配置**
   ```bash
   cd /Users/user/CLAUDE/docs/workflows/WF-20251223-exchange-oom-fix/script
   ./apply-changes.sh
   ```
   - 預計時間: 5-10 分鐘
   - 建議時段: 凌晨 2-4 點

2. **驗證部署**
   ```bash
   ./verify-deployment.sh
   ```
   - 預計時間: 2 分鐘
   - 檢查: 7 項驗證

3. **啟動監控**
   ```bash
   # 每 5 分鐘，持續 24 小時
   ./monitor-resources.sh 300 288
   ```

### 短期監控（24 小時）

**檢查項**:
- [ ] 記憶體使用穩定（3.5-4.5GB）
- [ ] 無 OOM 事件
- [ ] 無 Pod 重啟
- [ ] HPA 正常工作
- [ ] GC 暫停 < 200ms

### 長期觀察（1-2 週）

**評估項**:
- OOM 頻率（目標: 0）
- GC 日誌分析（是否需微調）
- HPA 擴展行為（峰值副本數）
- 性能基準（響應時間、吞吐量）

---

## 風險與緩解

### 已識別風險

1. **Heap 3GB 可能不足** - 低風險
   - 緩解: 監控實際使用，必要時調整
   - 回滾: 可快速回滾

2. **Metrics Server 問題** - 低風險
   - 緩解: 部署前驗證 Metrics Server
   - 影響: HPA 無法自動擴展，但固定 2 replicas 可用

3. **滾動更新失敗** - 極低風險
   - 緩解: maxUnavailable:0，至少保持 2 個 Pod
   - 回滾: 自動回滾機制

### 緩解措施

- ✅ 完整備份（20251223_135549）
- ✅ 自動化回滾腳本（rollback.sh）
- ✅ 詳細文檔（4 份 + DEPLOY-GUIDE.md）
- ✅ 自動化驗證（verify-deployment.sh）
- ✅ 持續監控（monitor-resources.sh）

---

## 參考資料

**內部文檔**:
- [README.md](../README.md)
- [01-analysis.md](../01-analysis.md)
- [02-deployment-plan.md](../02-deployment-plan.md)
- [03-post-deployment-verification.md](../03-post-deployment-verification.md)
- [04-monitoring-setup.md](../04-monitoring-setup.md)
- [DEPLOY-GUIDE.md](../../../../FOREX-project/prod-cloud/forex-prod-k8s-deploy/exchange-service/DEPLOY-GUIDE.md)

**外部參考**:
- [G1GC Tuning Guide](https://docs.oracle.com/javase/8/docs/technotes/guides/vm/gctuning/g1_gc_tuning.html)
- [Kubernetes HPA](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)
- [Kubernetes RollingUpdate](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/#rolling-update-deployment)

---

**記錄人**: User + Claude AI
**最後更新**: 2025-12-23 14:35
**狀態**: ✅ 配置完成，已 commit，待部署
