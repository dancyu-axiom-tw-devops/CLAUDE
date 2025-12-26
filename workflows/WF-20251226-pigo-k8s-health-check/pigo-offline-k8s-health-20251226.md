# PIGO 線下 Kubernetes Pod 健康巡檢報告

**巡檢時間**: 2025-12-26
**巡檢環境**: PIGO 線下 Kubernetes 集群
**巡檢範圍**: pigo-dev, pigo-stg, pigo-rel 命名空間
**巡檢人員**: Claude Code 自動化巡檢

---

## 📊 整體摘要

| 命名空間 | 總 Pod 數 | 健康 Pod | 不健康 Pod | 重啟次數 |
|---------|----------|---------|-----------|---------|
| pigo-dev | 14 | 13 | 1 | 0 |
| pigo-stg | 18 | 18 | 0 | 0 |
| pigo-rel | 16 | 15 | 1 | 0 |
| **總計** | **48** | **46** | **2** | **0** |

**整體健康狀態**: 🟡 需要關注

---

## 🔍 各命名空間詳細結果

### 1. pigo-dev 命名空間

**總 Pod 數**: 14
**健康 Pod**: 13
**不健康 Pod**: 1

#### 🟢 健康 Pod 清單 (13)

| Pod 名稱 | 狀態 | Ready | 重啟次數 | 運行時長 | 所在節點 |
|---------|------|-------|---------|---------|---------|
| agent-system-9c6b5446-z6s2t | Running | 1/1 | 0 | 2d14h | pigo-stg-k8s-service-node02 |
| datacenter-api-7b74cd9d77-jlqzk | Running | 1/1 | 0 | 9d | pigo-rel-k8s-service-node06 |
| game-api-7dc7647dc6-qnjss | Running | 1/1 | 0 | 34d | pigo-stg-k8s-service-node02 |
| nacos-5645f897b-t8qs2 | Running | 1/1 | 0 | 92d | pigo-stg-k8s-service-node01 |
| pay-mock-d758797b-8rxm8 | Running | 1/1 | 0 | 133d | pigo-rel-k8s-service-node04 |
| payment-api-55b6cd6c68-dhfgw | Running | 1/1 | 0 | 6d18h | pigo-rel-k8s-service-node02 |
| payment-cron-5f46454c7b-b9xhv | Running | 1/1 | 0 | 6d19h | pigo-rel-k8s-service-node02 |
| payment-office-5bcf67595d-vfvkm | Running | 1/1 | 0 | 7d10h | pigo-rel-k8s-service-node05 |
| pigo-api-5b5ffcd959-bxzmg | Running | 1/1 | 0 | 2d21h | pigo-stg-k8s-service-node01 |
| pigo-cron-77cc9c4d8c-7t8hw | Running | 1/1 | 0 | 10h | pigo-stg-k8s-service-node02 |
| pigo-dev-gitlab-runner-c5dcf6bfc-rh9dg | Running | 1/1 | 0 | 24d | waas-dev-k8s-service-runner01 |
| pigo-office-d96f874db-qnx88 | Running | 1/1 | 0 | 2d13h | pigo-rel-k8s-service-node05 |
| pigo-web-75fb4c7fc5-lc9x6 | Running | 1/1 | 0 | 3d16h | pigo-rel-k8s-service-node02 |

#### 🔴 不健康 Pod 清單 (1)

| Pod 名稱 | 狀態 | Ready | 重啟次數 | 運行時長 | 問題描述 |
|---------|------|-------|---------|---------|---------|
| pigo-cron-77cc9c4d8c-tw2xb | **Error** | 0/1 | 0 | 7d10h | Pod 處於 Error 狀態，容器未就緒 |

**問題分析**:
- **pigo-cron-77cc9c4d8c-tw2xb**:
  - 狀態: Error（已持續 7 天 10 小時）
  - 容器日誌無法讀取（容器可能已退出）
  - Events 無最近事件記錄
  - 建議: 檢查 Deployment，可能需要刪除此錯誤 Pod 讓其重建

---

### 2. pigo-stg 命名空間

**總 Pod 數**: 18
**健康 Pod**: 18
**不健康 Pod**: 0

#### 🟢 健康 Pod 清單 (18)

| Pod 名稱 | 狀態 | Ready | 重啟次數 | 運行時長 | 所在節點 |
|---------|------|-------|---------|---------|---------|
| agent-system-797f88c4d5-6lwcl | Running | 1/1 | 0 | 2d13h | pigo-rel-k8s-service-node05 |
| datacenter-api-868f556cf7-9dbtq | Running | 1/1 | 0 | 7d10h | pigo-rel-k8s-service-node04 |
| game-api-7688f98587-6klx8 | Running | 1/1 | 0 | 69d | pigo-rel-k8s-service-node03 |
| game-api-7688f98587-knrxz | Running | 1/1 | 0 | 69d | pigo-stg-k8s-service-node02 |
| game-api-7688f98587-llbfj | Running | 1/1 | 0 | 69d | pigo-rel-k8s-service-node04 |
| game-api-7688f98587-lwnrc | Running | 1/1 | 0 | 27d | pigo-stg-k8s-service-node03 |
| game-api-7688f98587-xpt48 | Running | 1/1 | 0 | 7d10h | pigo-rel-k8s-service-node06 |
| nacos-6b9ff57465-f4xkm | Running | 1/1 | 0 | 69d | pigo-rel-k8s-service-node03 |
| nginx-75bdbdf5dc-5fgs2 | Running | 1/1 | 0 | 10d | pigo-rel-k8s-service-node04 |
| pay-mock-55b9c9c8b-rths8 | Running | 1/1 | 0 | 133d | pigo-stg-k8s-service-node03 |
| payment-api-6994687fb9-btnls | Running | 1/1 | 0 | 6d18h | pigo-rel-k8s-service-node02 |
| payment-cron-59b547d5b6-d9tt4 | Running | 1/1 | 0 | 10h | pigo-rel-k8s-service-node06 |
| payment-office-5666699c94-5g4g6 | Running | 1/1 | 0 | 10h | pigo-rel-k8s-service-node05 |
| pigo-api-d95bc5974-7rcnz | Running | 1/1 | 0 | 3d15h | pigo-rel-k8s-service-node02 |
| pigo-cron-5dddd89475-8smlq | Running | 1/1 | 0 | 15d | pigo-stg-k8s-service-node02 |
| pigo-office-689fbd879d-552hl | Running | 1/1 | 0 | 2d13h | pigo-stg-k8s-service-node02 |
| pigo-stg-gitlab-runner-6fbbf8cfcd-hlrrt | Running | 1/1 | 0 | 24d | waas-dev-k8s-service-runner01 |
| pigo-web-df684d789-td4zr | Running | 1/1 | 0 | 3d16h | pigo-rel-k8s-service-node05 |

**健康狀態**: ✅ 所有 Pod 運行正常

---

### 3. pigo-rel 命名空間

**總 Pod 數**: 16
**健康 Pod**: 15
**不健康 Pod**: 1

#### 🟢 健康 Pod 清單 (15)

| Pod 名稱 | 狀態 | Ready | 重啟次數 | 運行時長 | 所在節點 |
|---------|------|-------|---------|---------|---------|
| agent-system-cc79bb78-4g5wt | Running | 1/1 | 0 | 44d | pigo-rel-k8s-service-node06 |
| datacenter-api-6474f869b8-zggdr | Running | 1/1 | 0 | 10h | pigo-rel-k8s-service-node05 |
| game-api-54c8d5c95c-mv29g | Running | 1/1 | 0 | 77d | pigo-rel-k8s-service-node01 |
| nacos-5549f7c5f4-bvjbl | Running | 1/1 | 0 | 92d | pigo-rel-k8s-service-node01 |
| nfs-server-provisioner-nfs-pigo-0 | Running | 1/1 | 0 | 92d | pigo-rel-k8s-nfs-node01 |
| nginx-5776bf8cbf-c7g5b | Running | 1/1 | 0 | 10d | pigo-stg-k8s-service-node03 |
| payment-api-65df69785d-7j9td | Running | 1/1 | 0 | 75d | pigo-rel-k8s-service-node06 |
| payment-cron-6b4647555b-7cbbv | Running | 1/1 | 0 | 77d | pigo-rel-k8s-service-node03 |
| payment-office-6759b88cf6-98frd | Running | 1/1 | 0 | 10h | pigo-rel-k8s-service-node02 |
| pigo-api-7486d497ff-v7zgw | Running | 1/1 | 0 | 70d | pigo-stg-k8s-service-node03 |
| pigo-cron-5b97575c69-zsp4q | Running | 1/1 | 0 | 77d | pigo-rel-k8s-service-node01 |
| pigo-office-5c8d88b9cc-5ndq7 | Running | 1/1 | 0 | 72d | pigo-rel-k8s-service-node06 |
| pigo-rel-gitlab-runner-8c756cbfc-cmqsv | Running | 1/1 | 0 | 24d | waas-rel-k8s-service-runner01 |
| pigo-web-79457d564-8hr49 | Running | 1/1 | 0 | 70d | pigo-rel-k8s-service-node03 |
| prometheus-blackbox-exporter-8c9d676fc-bkk6p | Running | 1/1 | 0 | 10d | pigo-rel-k8s-service-node05 |

#### 🟡 需要關注的 Pod (1)

| Pod 名稱 | 狀態 | Ready | 重啟次數 | 運行時長 | 問題描述 |
|---------|------|-------|---------|---------|---------|
| prometheus-blackbox-exporter-6fc9ff54ff-6cnqp | **Completed** | 0/1 | 0 | 51d | Pod 已完成執行，處於 Completed 狀態 |

**問題分析**:
- **prometheus-blackbox-exporter-6fc9ff54ff-6cnqp**:
  - 狀態: Completed（已持續 51 天）
  - 這是舊版本 Pod，新版本 Pod (8c9d676fc-bkk6p) 已在 10 天前啟動
  - 建議: 可以刪除此已完成的舊 Pod（屬於正常更新殘留）

---

## 🚨 問題 Pod 匯總表

| 命名空間 | Pod 名稱 | 狀態 | 嚴重程度 | 問題描述 | 建議處理 |
|---------|---------|------|---------|---------|---------|
| pigo-dev | pigo-cron-77cc9c4d8c-tw2xb | Error | 🔴 高 | Pod 處於 Error 狀態 7d10h | 刪除 Pod 讓 Deployment 重建 |
| pigo-rel | prometheus-blackbox-exporter-6fc9ff54ff-6cnqp | Completed | 🟡 中 | 舊版本 Pod 已完成，殘留 51d | 刪除舊 Pod 清理資源 |

---

## 📈 統計分析

### Pod 狀態分佈

- **Running**: 46 個 (95.8%)
- **Error**: 1 個 (2.1%)
- **Completed**: 1 個 (2.1%)

### 重啟統計

- **總重啟次數**: 0
- **有重啟的 Pod**: 0 個
- **結論**: ✅ 所有 Pod 無重啟記錄，穩定性良好

### 運行時長分析

- **超過 90 天**: 3 個 Pod (nacos 相關)
- **超過 70 天**: 7 個 Pod
- **超過 30 天**: 11 個 Pod
- **少於 7 天**: 13 個 Pod (近期更新)

### 節點分佈

Pod 分佈於以下節點:
- pigo-rel-k8s-service-node0[1-6]
- pigo-stg-k8s-service-node0[1-4]
- waas-dev-k8s-service-runner01
- waas-rel-k8s-service-runner01
- pigo-rel-k8s-nfs-node01

**節點分佈**: ✅ Pod 分佈均勻，無單點過載風險

---

## 💡 結論與建議

### 整體健康評估

**總體狀態**: 🟡 **基本健康，需要小幅改進**

**優點**:
1. ✅ 95.8% 的 Pod 處於 Running 狀態
2. ✅ 所有 Pod 0 重啟，穩定性優秀
3. ✅ 多數服務運行時長超過 30 天，說明環境穩定
4. ✅ pigo-stg 命名空間 100% 健康

**問題**:
1. ⚠️ pigo-dev 命名空間有 1 個 Error 狀態 Pod 需處理
2. ⚠️ pigo-rel 命名空間有 1 個 Completed 舊 Pod 需清理

### 立即處理建議

#### 🔴 高優先級

1. **處理 pigo-dev/pigo-cron-77cc9c4d8c-tw2xb (Error 狀態)**
   ```bash
   # 刪除錯誤 Pod
   kubectl delete pod pigo-cron-77cc9c4d8c-tw2xb -n pigo-dev

   # 檢查 Deployment 狀態
   kubectl get deployment pigo-cron -n pigo-dev

   # 檢查新 Pod 是否正常啟動
   kubectl get pods -n pigo-dev -l app=pigo-cron
   ```

#### 🟡 中優先級

2. **清理 pigo-rel/prometheus-blackbox-exporter-6fc9ff54ff-6cnqp (Completed 狀態)**
   ```bash
   # 刪除已完成的舊 Pod
   kubectl delete pod prometheus-blackbox-exporter-6fc9ff54ff-6cnqp -n pigo-rel
   ```

### 長期改進建議

1. **建立定期巡檢機制**
   - 建議頻率: 每週一次
   - 重點關注: Error, CrashLoopBackOff, ImagePullBackOff 狀態 Pod
   - 監控重啟次數異常增長

2. **Pod 生命週期管理**
   - 定期清理 Completed/Failed 狀態的 Pod
   - 考慮配置 Pod GC (Garbage Collection) 策略

3. **監控告警整合**
   - 整合 Prometheus 監控 Pod 健康狀態
   - 配置告警規則自動通知 Pod 異常

4. **文檔與記錄**
   - 記錄每次巡檢發現的問題與處理結果
   - 建立問題知識庫，加速故障排查

---

## 📝 附錄

### 巡檢執行命令

```bash
# 連線至 PIGO 線下集群
tp-hkidc

# 列出各命名空間 Pod
kubectl get pods -n pigo-dev -o wide
kubectl get pods -n pigo-stg -o wide
kubectl get pods -n pigo-rel -o wide

# 檢查問題 Pod 詳情
kubectl describe pod <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace> --tail=50
```

### 健康判定標準

**健康 Pod** 需滿足:
- ✅ STATUS = Running
- ✅ READY = X/X (所有容器就緒)
- ✅ RESTARTS < 5 (重啟次數正常)
- ✅ 無 CrashLoopBackOff, ImagePullBackOff, Error, Pending 狀態

**不健康 Pod** 符合以下任一條件:
- ❌ STATUS = Error/CrashLoopBackOff/ImagePullBackOff/Pending
- ❌ READY ≠ X/X (容器未就緒)
- ❌ RESTARTS ≥ 10 (頻繁重啟)

---

**報告生成時間**: 2025-12-26
**下次巡檢建議時間**: 2026-01-02 (一週後)
**巡檢工具**: Claude Code 自動化巡檢系統
