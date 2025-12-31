---
ref: [AGENTS.md](~/CLAUDE/AGENTS.md)
status: 進行中
created: 2025-12-31
updated: 2025-12-31
---

# K8s Daily Monitor 處理流程

## 目標

自動化處理 k8s-daily-monitor 健康檢查結果，分析問題並執行必要的配置調整，最後更新 CHANGELOG.md

## 專案資訊參考

**重要**: 執行處置前必須參考以下專案配置檔：

```
~/CLAUDE/profiles/
├── pigo.md      # PIGO 專案配置（環境、資源限制、部署路徑）
├── waas.md      # WAAS 專案配置
└── forex.md     # FOREX 專案配置
```

各 profile 包含：
- 環境清單（prod/rel/stg/dev）
- K8s 部署路徑
- Git 倉庫位置

## 專案路徑

```
健康檢查報告: /Users/user/MONITOR/k8s-daily-monitor
```

## 任務分解

| # | 任務 | 說明 |
|---|------|------|
| 1 | 同步數據 | git pull 取得最新健康檢查結果 |
| 2 | 分析問題 | 解析報告，識別需處置的問題項目 |
| 3 | 執行處置 | 依據 profiles 調整配置（資源、replicas 等） |
| 4 | 記錄變更 | 更新 CHANGELOG.md，commit 變更 |

## 處置決策流程

```
健康檢查報告
    │
    ▼
┌─────────────────────────────────────────────────────────┐
│ 問題類型判斷                                             │
├─────────────────────────────────────────────────────────┤
│ CPU Throttling > 20%     → 調高 CPU limit               │
│ Memory 使用率 > 80%      → 調高 Memory limit            │
│ Pod Restart > 3 次/天    → 檢查 liveness probe / 資源   │
│ PVC 使用率 > 85%         → 告警 / 擴容建議              │
│ Replica 不足             → 調整 replicas                │
└─────────────────────────────────────────────────────────┘
    │
    ▼
參考 ~/CLAUDE/profiles/{project}.md 取得：
  - 該環境的資源配置基準
  - 部署檔案路徑
  - 調整上限值
    │
    ▼
執行配置調整 → 記錄 CHANGELOG → git commit
```

## 執行方式

由 Claude 依序執行：

1. **同步數據**
   ```bash
   cd /Users/user/MONITOR/k8s-daily-monitor
   git pull
   ```

2. **分析報告**
   - 讀取當天健康檢查 JSON/YAML
   - 識別超過閾值的項目
   - 列出需要處置的問題清單

3. **執行處置**
   - 參考 `~/CLAUDE/profiles/{project}.md`
   - 修改對應的 K8s 配置檔（values.yaml / kustomization.yaml）
   - 例如：調整 CPU limit、Memory limit、replicas

4. **記錄變更**
   - 更新專案的 CHANGELOG.md
   - git commit 變更
   - （如需要）git push

## CHANGELOG 格式

```markdown
## 📆 YYYY/MM

* YYYY/MM/DD
  * **🔧 資源配置調整**
    * fix: `path/to/values.yaml`, 調整 Pod 資源配置
      * 📈 **CPU Limit**: 200m → 500m
      * 🎯 **解決問題**: CPU throttling 47.6%
      * 📊 **判斷依據**: k8s-health-monitor 報告
```

## 注意事項

1. **Git 規範**: 對特定目錄使用 `git-tp` 而非 `git`（參考 CLAUDE.md）
2. **Credentials**: 不要將敏感資訊寫入 git
3. **確認環境**: 處置前確認目標環境（prod 需更謹慎）
4. **備份**: 修改前記錄原始值

## 預期產出

- `summary/YYYY-MM-DD.md` - 當日健康檢查摘要
- `CHANGELOG.md` - 更新變更日誌

---

## 任務一：同步數據

**目標**: 從 Git 拉取最新的健康檢查結果

**步驟**:
1. 切換至專案目錄
2. 執行 `git pull`
3. 記錄同步結果

---

## 任務二：識別新報告

**目標**: 找出當天新增或修改的報告檔案

**步驟**:
1. 檢查 `reports/` 目錄
2. 根據檔名或修改時間篩選當天報告
3. 輸出待處理檔案清單

---

## 任務三：分析處理

**目標**: 解析健康檢查報告，統計各環境狀態

**步驟**:
1. 讀取各報告檔案
2. 統計健康/警告/異常數量
3. 產生 `summary/YYYY-MM-DD.md` 摘要

---

## 任務四：更新 CHANGELOG

**目標**: 依 CLAUDE.md 規範更新 CHANGELOG.md
