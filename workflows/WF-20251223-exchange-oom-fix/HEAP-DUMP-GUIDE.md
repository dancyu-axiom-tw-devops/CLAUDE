# Heap Dump 查詢與分析指南

**重要**: Heap dump 已自動儲存到 NAS，Pod 重啟不會消失！

## 📂 Heap Dump 儲存位置

### NAS 持久化儲存 ✅

Heap dump 會自動儲存到 NAS 持久化儲存：

**配置**:
```yaml
# deployment.yml
volumeMounts:
- name: log
  mountPath: /forex/log/
  subPath: exchange-service

volumes:
- name: log
  persistentVolumeClaim:
    claimName: forex-cnf-nas-log  # NAS 持久化儲存
```

**JVM 配置**:
```bash
# env/forex.env
-XX:HeapDumpPath=/forex/log/exchange-service/
```

**優點**:
- ✅ Pod 重啟後 heap dump 仍然存在
- ✅ 所有 Pod 共享同一個 NAS 目錄
- ✅ 可從任何 Pod 存取所有 heap dumps
- ✅ 不佔用容器本地儲存空間

## 🔍 快速查詢 Heap Dumps

### 使用自動化腳本（推薦）

```bash
cd /Users/user/CLAUDE/docs/workflows/WF-20251223-exchange-oom-fix/script

# 列出所有 heap dumps
./list-heapdumps.sh
```

**輸出範例**:
```
Heap Dumps on NAS:
─────────────────────────────────────────────────────────────────
-rw------- 1 app app 3.8G Dec 23 15:30 java_pid1.hprof
-rw------- 1 app app 3.5G Dec 22 10:15 java_pid1.hprof
─────────────────────────────────────────────────────────────────

Summary:
  Total heap dumps: 2
  Total disk usage: 7.3G
```

### 手動查詢

```bash
# 從任何運行中的 Pod 查詢
kubectl exec -n forex-prod deployment/exchange-service -- \
  ls -lh /forex/log/exchange-service/*.hprof

# 預期輸出:
# -rw------- 1 app app 3.8G Dec 23 15:30 java_pid1.hprof
```

## 📥 下載 Heap Dump

### 方法 1: 使用自動化腳本（推薦）

```bash
cd /Users/user/CLAUDE/docs/workflows/WF-20251223-exchange-oom-fix/script

# 列出可用的 heap dumps
./download-heapdump.sh

# 下載指定的 heap dump
./download-heapdump.sh java_pid1.hprof
```

腳本會自動：
- 檢查檔案是否存在
- 顯示檔案大小
- 確認下載
- 下載到 `../data/heap-dump-YYYYMMDD_HHMMSS.hprof`
- 提供分析工具使用說明

### 方法 2: 手動下載

```bash
# 獲取 Pod 名稱
POD_NAME=$(kubectl get pods -n forex-prod -l app=exchange-service -o jsonpath='{.items[0].metadata.name}')

# 下載 heap dump
kubectl cp forex-prod/$POD_NAME:/forex/log/exchange-service/java_pid1.hprof \
  ./heap-dump-$(date +%Y%m%d_%H%M%S).hprof
```

### 方法 3: 壓縮後下載（檔案很大時）

```bash
POD_NAME=$(kubectl get pods -n forex-prod -l app=exchange-service -o jsonpath='{.items[0].metadata.name}')

# 壓縮
kubectl exec -n forex-prod $POD_NAME -- \
  tar czf /tmp/heap-dump.tar.gz -C /forex/log/exchange-service java_pid1.hprof

# 下載壓縮檔（大小約為原本的 1/3）
kubectl cp forex-prod/$POD_NAME:/tmp/heap-dump.tar.gz ./heap-dump.tar.gz

# 解壓縮
tar xzf heap-dump.tar.gz
```

## 🔬 分析 Heap Dump

### 工具 1: Eclipse MAT（推薦）

**下載**:
- https://eclipse.dev/mat/downloads.php

**使用步驟**:

1. **開啟 heap dump**:
   ```
   File → Open Heap Dump → 選擇下載的 .hprof 檔案
   ```

2. **查看 Leak Suspects Report**:
   - MAT 會自動執行分析
   - 顯示可能的記憶體洩漏

3. **關鍵分析**:

   **a. Leak Suspects（洩漏懷疑）**:
   ```
   查看 "Problem Suspect" 區域
   - 顯示佔用最多記憶體的物件
   - 點擊 "Details" 查看詳細資訊
   ```

   **b. Dominator Tree（支配樹）**:
   ```
   工具列 → Dominator Tree 圖示
   - 按 "Retained Heap" 排序
   - 找出佔用最多記憶體的物件
   - 右鍵 → Path to GC Roots → exclude weak references
   ```

   **c. Histogram（直方圖）**:
   ```
   工具列 → Histogram 圖示
   - 查看各類別的實例數量
   - 按 "Shallow Heap" 或 "Retained Heap" 排序
   - 找出異常多的物件
   ```

### 工具 2: VisualVM（輕量級）

**啟動**:
```bash
jvisualvm
```

**載入 heap dump**:
```
File → Load → 選擇 .hprof 檔案
```

**查看**:
- Summary: 總記憶體、物件數量
- Classes: 按記憶體大小排序的類別
- Instances: 查看具體物件實例

### 工具 3: jhat（命令列）

```bash
# 啟動 jhat 伺服器（需要比 heap dump 更多記憶體）
jhat -J-Xmx4g heap-dump.hprof

# 瀏覽器開啟
open http://localhost:7000
```

**查看**:
- Heap Histogram
- All Classes
- Execute OQL queries

## 🗂️ Heap Dump 管理

### 清理舊的 Heap Dumps

**為什麼需要清理**:
- Heap dump 很大（3-4GB 每個）
- 可能佔用大量 NAS 空間
- 舊的 dump 通常不再需要

**使用自動化清理腳本**:
```bash
cd /Users/user/CLAUDE/docs/workflows/WF-20251223-exchange-oom-fix/script

# 清理舊 heap dumps（保留最近 3 個）
./cleanup-heapdumps.sh
```

腳本會：
- 列出所有 heap dumps
- 顯示將要刪除的檔案
- 要求確認
- 保留最近 3 個，刪除其他
- 顯示清理後狀態

**手動清理**:
```bash
# 列出 heap dumps（按時間排序）
kubectl exec -n forex-prod deployment/exchange-service -- \
  ls -lt /forex/log/exchange-service/*.hprof

# 刪除特定檔案
kubectl exec -n forex-prod deployment/exchange-service -- \
  rm /forex/log/exchange-service/java_pid1.hprof

# 保留最近 3 個，刪除其他
kubectl exec -n forex-prod deployment/exchange-service -- \
  bash -c 'cd /forex/log/exchange-service && ls -1t *.hprof | tail -n +4 | xargs rm -f'
```

### 監控磁碟使用

```bash
# 檢查 heap dump 目錄大小
kubectl exec -n forex-prod deployment/exchange-service -- \
  du -sh /forex/log/exchange-service/

# 檢查 NAS 總使用量
kubectl exec -n forex-prod deployment/exchange-service -- \
  df -h /forex/log/
```

## 🚨 OOM 發生後的處理流程

### 立即行動（發生 OOM 後）

1. **確認 OOM 事件**:
   ```bash
   kubectl get events -n forex-prod \
     --field-selector reason=OOMKilling \
     --sort-by='.lastTimestamp' | grep exchange-service
   ```

2. **檢查 Pod 日誌**:
   ```bash
   kubectl logs -n forex-prod -l app=exchange-service --tail=200 | grep -i "OutOfMemoryError"
   ```
   預期看到:
   ```
   java.lang.OutOfMemoryError: Java heap space
   Dumping heap to /forex/log/exchange-service/java_pid1.hprof ...
   Heap dump file created [3890123456 bytes in 5.123 secs]
   ```

3. **列出 heap dumps**:
   ```bash
   cd /Users/user/CLAUDE/docs/workflows/WF-20251223-exchange-oom-fix/script
   ./list-heapdumps.sh
   ```

4. **下載最新的 heap dump**:
   ```bash
   ./download-heapdump.sh java_pid1.hprof
   ```

### 分析階段

5. **使用 Eclipse MAT 分析**:
   - 開啟下載的 heap dump
   - 查看 Leak Suspects Report
   - 檢查 Dominator Tree
   - 查看 Histogram

6. **識別問題**:
   - 哪個類別佔用最多記憶體？
   - 是否有異常多的物件實例？
   - 是否有記憶體洩漏路徑？

7. **產生分析報告**:
   使用 [分析報告範本](#分析報告範本)

### 修復階段

8. **根據分析結果修復**:
   - 修改程式碼（修復洩漏、優化邏輯）
   - 或調整 JVM 參數（增加 heap）
   - 或增加容器記憶體限制

9. **測試與驗證**:
   - 本地測試
   - Stage 環境驗證
   - Production 部署

10. **清理 heap dump**:
    ```bash
    ./cleanup-heapdumps.sh
    ```

## 📊 常見問題分析

### 問題 A: Java heap space

**症狀**:
```
java.lang.OutOfMemoryError: Java heap space
```

**MAT 分析**:
```
1. 開啟 Dominator Tree
2. 查看 Retained Heap 最大的物件
3. 右鍵 → Path to GC Roots
4. 找出是什麼在持有這些物件
```

**常見原因**:
- 快取無限增長（HashMap 未限制大小）
- 大集合未清理（ArrayList 累積資料）
- 靜態集合洩漏（static Map 永久持有）

**解決方案**:
- 使用 LRU cache（如 Guava Cache）
- 定期清理集合
- 檢查靜態變數使用
- 或增加 heap 大小（臨時方案）

### 問題 B: GC overhead limit exceeded

**症狀**:
```
java.lang.OutOfMemoryError: GC overhead limit exceeded
```

**說明**: GC 佔用超過 98% 時間，但回收不到 2% 記憶體

**MAT 分析**:
```
1. 查看 Histogram
2. 找出實例數量異常多的類別
3. 檢查是否有持續增長的物件
```

**解決方案**:
- 修復記憶體洩漏
- 增加 heap 大小
- 優化物件創建邏輯

### 問題 C: Metaspace

**症狀**:
```
java.lang.OutOfMemoryError: Metaspace
```

**說明**: 類別元數據空間不足（通常是動態類別載入）

**檢查**:
```bash
# 檢查 Metaspace 配置
kubectl exec -n forex-prod deployment/exchange-service -- \
  env | grep MetaspaceSize
```

**解決方案**:
- 增加 MaxMetaspaceSize
- 檢查是否有類別洩漏（ClassLoader leak）

## 📋 分析報告範本

```markdown
# Heap Dump 分析報告

**OOM 發生時間**: YYYY-MM-DD HH:MM:SS
**Heap Dump 檔案**: java_pid1.hprof
**Heap 大小**: X.X GB
**分析工具**: Eclipse MAT / VisualVM / jhat
**分析時間**: YYYY-MM-DD

## 1. 問題摘要

- **錯誤類型**: java.lang.OutOfMemoryError: Java heap space
- **Heap 使用率**: XX%
- **Pod 狀態**: OOMKilled / CrashLoopBackOff

## 2. MAT 分析結果

### Leak Suspects

**Problem Suspect 1**: [Class Name] retains X.X GB (XX%)
- **原因**: [簡要說明]
- **路徑**: [GC Root 路徑]
- **實例數**: XXX,XXX

### Top Memory Consumers

| Class | Instances | Shallow Heap | Retained Heap |
|-------|-----------|--------------|---------------|
| com.example.Class1 | 1,000,000 | 100 MB | 2.5 GB |
| byte[] | 500,000 | 1.2 GB | 1.2 GB |
| HashMap$Entry | 250,000 | 50 MB | 500 MB |

### Dominator Tree 分析

[截圖或描述最大物件的支配關係]

## 3. 根本原因

[詳細描述問題根因]

例如:
- CacheManager 中的靜態 HashMap 無限增長
- 每次請求創建 10MB byte[]，未及時回收
- ThreadLocal 未清理導致記憶體洩漏

## 4. 影響範圍

- **開始時間**: [何時開始出現]
- **頻率**: [多久發生一次]
- **影響服務**: [哪些功能受影響]

## 5. 修復建議

### 短期修復（立即）
1. 增加 heap 到 X GB（臨時緩解）
2. 重啟服務

### 長期修復（根治）
1. 修改 CacheManager 使用 Guava Cache（有大小限制）
2. 設置 TTL（X 小時過期）
3. 優化 byte[] 使用（使用 ByteBuffer pool）

### 代碼修改
```java
// Before
private static Map<String, Object> cache = new HashMap<>();

// After
private static LoadingCache<String, Object> cache = CacheBuilder.newBuilder()
    .maximumSize(10000)
    .expireAfterWrite(1, TimeUnit.HOURS)
    .build(...);
```

## 6. 驗證計畫

1. [ ] 本地測試修復代碼
2. [ ] Stage 環境壓力測試
3. [ ] 監控記憶體使用（24 小時）
4. [ ] Production 部署（低峰時段）
5. [ ] 持續監控（1 週）

## 7. 附件

- Heap dump 檔案位置: [NAS 路徑]
- MAT 報告: [連結或檔案]
- 相關 logs: [連結]

---

**分析人員**: [姓名]
**審核人員**: [姓名]
**狀態**: [分析中 / 已修復 / 待驗證]
```

## 🔗 參考資源

**工具下載**:
- Eclipse MAT: https://eclipse.dev/mat/downloads.php
- VisualVM: https://visualvm.github.io/

**文檔**:
- MAT 使用指南: https://eclipse.dev/mat/documentation/
- JVM OOM 類型: https://docs.oracle.com/javase/8/docs/technotes/guides/troubleshoot/memleaks002.html

**內部腳本**:
- [list-heapdumps.sh](script/list-heapdumps.sh) - 列出所有 heap dumps
- [download-heapdump.sh](script/download-heapdump.sh) - 下載 heap dump
- [cleanup-heapdumps.sh](script/cleanup-heapdumps.sh) - 清理舊 heap dumps

---

**文檔版本**: 1.0
**最後更新**: 2025-12-23
**維護人員**: User + Claude AI
