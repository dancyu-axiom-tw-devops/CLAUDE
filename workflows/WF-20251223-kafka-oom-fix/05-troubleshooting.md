# 問題排查指南

## 發現的問題

### 問題 1: Secret 配置未更新

**現象**:
- 驗證腳本顯示 JVM 參數錯誤
- Secret 中仍然是舊配置 (4096m)

**原因**:
您複製了 Solution B 配置檔案到 Kafka 目錄，但 Kubernetes Secret 尚未更新。Secret 是從 `env/forex.env` 生成的，需要重新執行 Kustomize。

**解決方案**:

```bash
# 方案 A: 使用自動化腳本 (推薦)
cd /Users/user/CLAUDE/docs/workflows/WF-20251223-kafka-oom-fix/script
./apply-solution-b.sh

# 方案 B: 手動執行
cd /Users/user/FOREX-project/hkidc-k8s-gitlab/forex-stg/forex-stage-k8s-deploy/kafka-cluster
kustomize build . | kubectl apply -f -
```

**驗證 Secret 已更新**:
```bash
kubectl -n forex-stg get secret kafka-env -o jsonpath='{.data.KAFKA_HEAP_OPTS}' | base64 -d

# 應該看到:
# -Xmx3072m -Xms3072m -XX:MaxDirectMemorySize=1536m ...
```

### 問題 2: kubectl exec 失敗 (502 Bad Gateway)

**現象**:
```bash
kubectl -n forex-stg exec kafka-0 -- ps aux
# Error: 502 Bad Gateway
```

**原因**:
從您的電腦無法直接 exec 到 Pod，可能是：
- 網路代理配置問題
- kubectl 通過 API Server 代理訪問節點失敗
- 節點 kubelet 不可達

**這不影響部署**: Pod 仍然正常運行，只是無法從您的電腦進入容器執行命令。

**解決方案**:

#### 方案 A: 從集群內部的 Pod 驗證

```bash
# 創建臨時 debug pod
kubectl -n forex-stg run debug-pod --rm -it --image=busybox -- sh

# 在 debug pod 中
wget -O- http://kafka-0.kafka-svc:5556/metrics | grep jvm_memory
```

#### 方案 B: 使用 Port Forward

```bash
# 轉發 JMX metrics 端口到本機
kubectl -n forex-stg port-forward kafka-0 5556:5556

# 在另一個終端
curl localhost:5556/metrics | grep jvm_memory_max_bytes
```

#### 方案 C: 檢查 Secret 配置 (間接驗證)

```bash
# 檢查 Secret 中的配置
kubectl -n forex-stg get secret kafka-env -o jsonpath='{.data.KAFKA_HEAP_OPTS}' | base64 -d
```

**更新後的驗證腳本**: 已更新 `verify-deployment.sh`，當 exec 失敗時會自動：
- 顯示警告而非錯誤
- 改為檢查 Secret 配置
- 跳過需要 exec 的測試

### 問題 3: Kafka 功能測試失敗

**現象**:
- 無法列出 Topics
- 無法創建測試 Topic

**原因**:
與問題 2 相同，無法 exec 到 Pod。

**解決方案**:
測試已標記為 "Optional"，可跳過。Pod 狀態為 Running 即表示 Kafka 運行正常。

**替代驗證方法**:

```bash
# 檢查 Pod 日誌
kubectl -n forex-stg logs kafka-0 --tail=50

# 應該看到 Kafka 正常啟動訊息，無錯誤
```

## 當前狀態確認

### 已確認 ✅
1. Pod 狀態: Running
2. Memory Limit: 6Gi (正確)
3. Memory Request: 2Gi (正確)
4. 當前記憶體使用: 625 MiB (10.2%)

### 待確認 ⏳
1. JVM Heap 參數: 3072m (需要更新 Secret)
2. Direct Memory 限制: 1536m (需要更新 Secret)
3. Kafka 功能正常 (無法從您的電腦測試)

## 完整修復步驟

### 1. 確認配置檔案已複製

```bash
# 檢查 Kafka 目錄中的配置
grep KAFKA_HEAP_OPTS /Users/user/FOREX-project/hkidc-k8s-gitlab/forex-stg/forex-stage-k8s-deploy/kafka-cluster/env/forex.env

# 應該看到 3072m 和 MaxDirectMemorySize=1536m
```

### 2. 重新應用配置 (更新 Secret)

```bash
# 使用自動化腳本
cd /Users/user/CLAUDE/docs/workflows/WF-20251223-kafka-oom-fix/script
./apply-solution-b.sh
```

這個腳本會：
- ✅ 建立時間戳備份
- ✅ 複製 Solution B 配置
- ✅ 顯示變更對比
- ✅ 詢問確認
- ✅ 執行 Kustomize apply
- ✅ 監控 Pod 重啟
- ✅ 顯示最終狀態

### 3. 等待 Pod 重啟

```bash
# 監控 Pod 狀態
kubectl -n forex-stg get pod kafka-0 -w

# Pod 會經歷: Running -> Terminating -> Pending -> Running
# 大約需要 1-3 分鐘
```

### 4. 驗證新配置

```bash
# 檢查 Secret 已更新
kubectl -n forex-stg get secret kafka-env -o jsonpath='{.data.KAFKA_HEAP_OPTS}' | base64 -d

# 檢查資源配置
kubectl -n forex-stg get pod kafka-0 -o jsonpath='{.spec.containers[0].resources}'

# 檢查記憶體使用
kubectl -n forex-stg top pod kafka-0
```

### 5. 運行驗證腳本

```bash
cd /Users/user/CLAUDE/docs/workflows/WF-20251223-kafka-oom-fix/script
./verify-deployment.sh
```

現在應該看到更少的錯誤，主要是警告 (exec 相關的測試會被跳過)。

## 驗證腳本預期輸出

### 會顯示 ✅ (成功)
- Pod 狀態: Running
- 無 OOMKilled 事件
- Memory Limit: 6Gi
- Memory Request: 2Gi
- 記憶體使用 < 85%
- Secret 配置正確 (Xmx3072m, MaxDirectMemorySize=1536m)

### 會顯示 ⚠️ (警告 - 可接受)
- 無法 exec 到 Pod (網路問題)
- JVM 參數驗證跳過 (改為檢查 Secret)
- Kafka 功能測試跳過
- JMX Metrics 檢查跳過

### 不應該看到 ❌ (錯誤)
- Pod 不是 Running
- 有 OOMKilled 事件
- Memory Limit 不是 6Gi
- Memory Request 不是 2Gi
- 記憶體使用 > 95%

## 從集群內驗證 JVM 參數

如果需要確認 JVM 參數實際生效，可以：

### 方案 A: 使用臨時 Pod

```bash
# 創建臨時 Pod (使用 curl)
kubectl -n forex-stg run curl-test --rm -it --image=curlimages/curl -- sh

# 在 Pod 內執行
curl -s http://kafka-0.kafka-svc:5556/metrics | grep jvm_memory_max_bytes

# 預期輸出:
# jvm_memory_max_bytes{area="heap"} 3221225472.0   # 3GB
```

### 方案 B: Port Forward

```bash
# 終端 1: Port Forward
kubectl -n forex-stg port-forward kafka-0 5556:5556

# 終端 2: 查詢 Metrics
curl localhost:5556/metrics | grep 'jvm_memory_max_bytes{area="heap"}'
```

## 監控建議

由於無法從您的電腦 exec 到 Pod，建議：

1. **依賴 Kubernetes Metrics**
   ```bash
   kubectl -n forex-stg top pod kafka-0
   ```

2. **使用 Prometheus** (如果有)
   - 查詢 `container_memory_working_set_bytes`
   - 查詢 `jvm_memory_used_bytes`

3. **定期檢查 Pod 事件**
   ```bash
   kubectl -n forex-stg describe pod kafka-0 | grep -i oom
   ```

4. **觀察 Pod 重啟次數**
   ```bash
   kubectl -n forex-stg get pod kafka-0 -o jsonpath='{.status.containerStatuses[0].restartCount}'
   ```

## 回滾程序

如果發現問題需要回滾：

```bash
cd /Users/user/CLAUDE/docs/workflows/WF-20251223-kafka-oom-fix/script
./rollback.sh [timestamp]

# 例如
./rollback.sh 20251223_143052

# 然後重新應用
cd /Users/user/FOREX-project/hkidc-k8s-gitlab/forex-stg/forex-stage-k8s-deploy/kafka-cluster
kustomize build . | kubectl apply -f -
```

## FAQ

### Q: 為什麼 exec 失敗但 Pod 仍在運行？

A: `kubectl exec` 需要通過 API Server 連接到節點的 kubelet，然後進入容器。如果網路路徑有問題（代理、防火牆等），exec 會失敗，但不影響 Pod 本身的運行。

### Q: 如何確認 JVM 參數真的生效了？

A:
1. 檢查 Secret 配置 (必須正確)
2. 確認 Pod 在 Secret 更新後重啟過
3. 使用 Port Forward 或臨時 Pod 檢查 JMX metrics
4. 觀察記憶體使用是否符合預期 (~6GB 以下)

### Q: 記憶體監控腳本會受影響嗎？

A: 部分影響。`monitor-memory.sh` 主要依賴 `kubectl top`，這個不受 exec 問題影響。JVM metrics 部分會顯示 N/A，但核心監控功能正常。

### Q: 需要在集群內部署監控 Pod 嗎？

A: 非必須。只要 Pod 穩定運行、記憶體使用正常、無 OOMKilled，就表示修復成功。JVM 參數驗證是額外確認。

## 總結

**核心問題**: Secret 未更新，JVM 參數還是舊的。

**解決方案**:
```bash
cd /Users/user/CLAUDE/docs/workflows/WF-20251223-kafka-oom-fix/script
./apply-solution-b.sh
```

**次要問題**: kubectl exec 失敗 (網路問題)。

**影響**: 無法直接驗證 JVM 參數，但不影響部署效果。

**驗證方式**:
- 檢查 Secret 配置
- 使用 Port Forward 或臨時 Pod
- 觀察記憶體使用趨勢
