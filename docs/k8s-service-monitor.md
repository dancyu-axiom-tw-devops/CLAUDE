# 📋 Kubernetes 服務層巡檢規則表（公版規範）

> 適用範圍：
>
> * Kubernetes 上所有服務（Deployment / StatefulSet）
> * 不綁定語言、不綁定框架
> * 僅做觀察與分析，不做任何自動修復

---

## 一、巡檢基本原則（Claude 必須遵守）

1. **只讀（Read-only）**
2. **不修改任何線上資源**
3. **所有判斷必須有明確依據**
4. **無資料時標示為 `Insufficient Data`，不得猜測**
5. **每個服務必須且只能有一個整體狀態**

---

## 二、巡檢時間範圍（Time Window）

* 預設：最近 **24 小時**
* 可由設定調整（如 6h / 48h）

---

## 三、服務整體狀態分級（Global Status）

| 等級           | 定義         |
| ------------ | ---------- |
| 🟢 Healthy   | 無重大風險      |
| 🟡 Attention | 有潛在問題，需關注  |
| 🔴 Risk      | 高風險，可能影響服務 |

---

## 四、巡檢項目與規則表（核心）

### 1️⃣ 可用性（Availability）

#### 檢查項目：Ready Replicas

| 條件               | 狀態 |
| ---------------- | -- |
| ready == desired | 🟢 |
| ready < desired  | 🔴 |

---

### 2️⃣ 穩定性（Stability）

#### 檢查項目：Pod Restart

| 條件（24h）      | 狀態 |
| ------------ | -- |
| restart == 0 | 🟢 |
| restart > 0  | 🟡 |
| OOMKilled 發生 | 🔴 |

---

### 3️⃣ 記憶體使用（Memory Usage）

#### 檢查項目：Usage vs Limit

| 條件              | 狀態 |
| --------------- | -- |
| 無 limit 設定      | 🔴 |
| max < 70% limit | 🟢 |
| 70% ≤ max < 85% | 🟡 |
| max ≥ 85%       | 🔴 |

---

### 4️⃣ 記憶體趨勢（Memory Trend）

#### 檢查項目：是否只升不降

| 條件       | 狀態 |
| -------- | -- |
| 使用量有回落   | 🟢 |
| 長時間維持高水位 | 🟡 |
| 持續上升無回落  | 🔴 |

---

### 5️⃣ CPU 使用（CPU Usage）

#### 檢查項目：Usage vs Request

| 條件                | 狀態 |
| ----------------- | -- |
| avg < 80% request | 🟢 |
| avg ≥ 80% request | 🟡 |
| 長時間 100%          | 🔴 |

---

### 6️⃣ 錯誤率（Error Rate）

#### 檢查項目：5xx Rate

| 條件      | 狀態 |
| ------- | -- |
| < 1%    | 🟢 |
| 1% – 5% | 🟡 |
| > 5%    | 🔴 |

---

### 7️⃣ 延遲（Latency）

#### 檢查項目：P95 / P99

| 條件          | 狀態 |
| ----------- | -- |
| 無明顯上升       | 🟢 |
| 高於 baseline | 🟡 |
| 明顯惡化        | 🔴 |

---

### 8️⃣ Pod 數量合理性（Scaling Sanity）

#### 檢查項目：Pod Count vs Usage

| 條件             | 狀態 |
| -------------- | -- |
| Pod 數合理        | 🟢 |
| Pod 多但 usage 低 | 🟡 |
| Pod 少但 usage 高 | 🔴 |

---

## 五、整體狀態判定規則（Critical）

Claude **必須依此合併結果**：

1. **任一 🔴 → 整體 🔴**
2. 若無 🔴，但有 🟡 → 整體 🟡
3. 全部 🟢 → 整體 🟢
4. 若關鍵項目資料不足 → 整體 🟡（需標示）

---

## 六、輸出格式規範（Output Contract）

### 每個服務必須輸出：

```yaml
service: <name>
namespace: <namespace>
status: 🟢|🟡|🔴
checks:
  availability: 🟢
  stability: 🟡
  memory_usage: 🟢
  memory_trend: 🟢
  cpu_usage: 🟡
  error_rate: 🟢
  latency: 🟢
  scaling: 🟢
notes:
  - restart detected: 1 time in 24h
```

---

## 七、Slack 顯示規範（摘要）

### Slack 僅顯示：

* 🔴 服務清單
* 🟡 服務數量
* Top 3 問題原因

---

## 八、Claude 明確禁止事項（一定要寫進任務）

❌ 不允許：

* 嘗試自動修復
* 修改 YAML
* 建議立即執行指令
* 隱藏資料不足狀態

---

## 九、你可以直接貼給 Claude 的一句話

> 請依照「Kubernetes 服務層巡檢規則表」實作巡檢邏輯。
> 所有判斷必須完全遵守規則表，不得自行新增或調整判斷條件。
> 若資料不足，必須明確標示，不得推測。
