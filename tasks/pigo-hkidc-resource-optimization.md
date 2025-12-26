任務名稱：
PIGO Kubernetes Pods 資源使用與配置優化分析（Resource Right-Sizing）

任務目標：
針對 PIGO 線下 Kubernetes 環境中的 Pods，
分析 CPU / Memory 的實際使用狀況與 request / limit 配置是否合理，
並提出「資源配置優化建議」，以提升資源利用率與叢集效率。

適用環境：
- 線下 Kubernetes 叢集（登入指令 tp-hkidc）
- namespaces：
  - pigo-dev
  - pigo-stg
  - pigo-rel

執行前提：
- 請假設 kubectl 已可正常存取叢集
- 本任務為「分析與建議」，不進行任何實際修改

分析對象：
- 所有 Running 狀態的 Pods
- 尤其關注：
  - 長期 CPU / Memory 使用率遠低於 request 的 Pods
  - request 與實際使用差距過大的 Pods
  - limit 設定可能過高或缺失的 Pods

分析項目與判斷原則：

一、CPU 資源分析
- 比較：
  - CPU avg usage vs CPU request
- 若出現以下情況，請列為「可優化」：
  - CPU avg < 20% of request（長期）
- 請說明：
  - 目前 request 設定
  - 實際使用狀況
  - 是否可能過度配置（over-provisioned）

二、Memory 資源分析
- 比較：
  - Memory avg / peak usage vs Memory request / limit
- 若出現以下情況，請列為「可優化」：
  - Memory 使用長期低於 request 明顯比例
- 若曾發生 OOMKilled，請標註為：
  - 不適合下修，需保守觀察

三、風險評估原則
- 本任務不將以下情況視為風險：
  - CPU 使用率低
  - Request 設定偏高
- 僅在以下情況才標註為「需特別注意」：
  - 曾有 OOMKilled
  - 使用量貼近 limit
  - 配置明顯不合理（例如無 limit）

四、優化建議（Right-Sizing）
- 建議請以「方向性」為主，例如：
  - 可考慮下修 CPU request
  - 建議觀察一段時間再調整
  - 建議與 RD 確認服務特性後調整
- 不直接給具體數值，除非依據明確

任務模組拆分（請依此邏輯執行）：
1. Pod resource usage collection
   - 蒐集 CPU / Memory 使用與 request / limit 資訊
2. Resource utilization analysis
   - 判斷使用率是否偏低或貼近上限
3. Optimization candidate identification
   - 標記「可優化 Pod」
4. Recommendation generation
   - 提出調整方向與注意事項
5. Markdown renderer
   - 整理為工程導向報告


請同時產出兩種格式：
1. Markdown 報告（適合 GitHub，允許表格）
2. Slack 訊息版本（不使用 Markdown 表格、不使用 emoji，採用條列與縮排）
對，**Slack 真的不支援 Markdown 表格**，你這句點到核心了 👍
所以做法不是「硬塞表格」，而是 **同一份巡檢結果 → 兩種輸出格式**。

我直接給你 **工程上可長期用、也好自動化的解法**。

---

## 一句話結論（先給你方向）

> **GitHub：表格版（工程記錄）**
> **Slack：條列版（人類快速掃描）**

同源資料，不同 renderer。

---

## 一、Slack 友善的「工程風格」格式（無表格、無 emoji）

👉 重點：**短、冷靜、可掃描**

```text
[PIGO] Daily K8s Health Check

Summary
- Namespaces: pigo-dev / pigo-stg / pigo-rel
- Pods checked: 15
- Unhealthy pods: 0
- Pods with restarts: 2

Resource Review Required
- service-setting
  - CPU avg 0.00 cores (2.2% of 0.10 request)
  - Status: Running / Ready
  - Note: CPU request likely over-provisioned

- service-tron
  - CPU avg 0.02 cores (17.8% of 0.10 request)
  - Status: Running / Ready
  - Note: Consider lowering CPU request

Services to Monitor
- nginx
  - Reason: Scaling behavior under observation

Healthy Services
- ilogtail-ds
- prod-waas2-tenant-runner-gitlab-runner
- service-admin
- service-api
- service-eth
- service-exchange
- service-gateway
- service-notice
- service-pol
- service-search
- service-user
- xxl-job
```

**為什麼這個好**

* Slack 原生可讀
* 不靠 emoji
* 一眼看出「需不需要動作」
* 不會被誤判成 incident

---

## 二、GitHub / Markdown 表格版（工程紀錄）

👉 同一份資料，另一個 renderer

```md
## Resource Configuration Review

| Service         | Status            | Observation                                   | Recommendation |
|-----------------|-------------------|-----------------------------------------------|----------------|
| service-setting | Running / Ready   | CPU avg 0.00 cores (2.2% of 0.10 request)     | Review CPU request sizing |
| service-tron    | Running / Ready   | CPU avg 0.02 cores (17.8% of 0.10 request)    | Consider lowering CPU request |
```

---

## 三、實務建議的「輸出架構」（給你後面自動化用）

### 資料模型（共用）

```json
{
  "summary": {...},
  "resource_review": [...],
  "monitoring": [...],
  "healthy": [...]
}
```

### Renderers

* `render_md()` → GitHub
* `render_slack()` → Slack

👉 **不要反過來用 Slack 格式硬塞 GitHub**

---

---


輸出格式與檔名規則：
- 請輸出一份 Markdown (.md) 檔案
- 檔名規則：
  pigo-k8s-resource-optimization-YYYYMMDD.md

Markdown 報告結構建議如下：
1. 分析摘要（Summary）
   - 分析 Pods 數量
   - 可優化 Pods 數量
   - 無需調整 Pods 數量
2. 可優化 Pods 清單
   - Namespace
   - Pod / Service 名稱
   - CPU 使用 vs request
   - Memory 使用 vs request / limit
   - 優化建議摘要
3. 無需調整 Pods（簡述即可）
4. 整體觀察與建議
   - 是否適合進行集中調整
   - 是否建議逐一與 RD 確認

請確保整體報告語氣為工程分析，
避免使用「高風險」「嚴重問題」等情緒性用語，
除非有實際穩定性或服務中斷風險。

slack channel and webhook:
- pigo-dev-devops-alert: https://hooks.slack.com/services/YOUR_WEBHOOK_URLavULzD12iKRjGbuMOiSmdb
- pigo-stg-devops-alert: https://hooks.slack.com/services/YOUR_WEBHOOK_URLmhVPi0PnD7WnQ8IVjTHPY
- pigo-rel-devops-alert: https://hooks.slack.com/services/YOUR_WEBHOOK_URLnEL17pVJLKvEVDSgaWJXVj

github app:
- App ID: 2539631
- Client ID: Iv23libLdZu21fUN9HzO
- secret: /Users/user/CLAUDE/credentials/gcr-juancash-prod.json

github : https://github.com/dancyu-axiom-tw-devops/k8s-daily-monitor.git
上傳存放方式參照：/Users/user/MONITOR/k8s-daily-monitor/README.md