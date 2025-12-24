# WF-20251223-kafka-oom-fix

## Workflow 資訊

- **建立日期**: 2025-12-23
- **狀態**: 準備中
- **負責人**: Claude AI + User
- **相關系統**: FOREX-STG Kafka Cluster

## 問題描述

Kafka 集群發生 Kubernetes OOMKilled，容器因超過 memory limit (5Gi) 被終止。

**影響範圍**:
- 環境: forex-stg
- Namespace: forex-stg
- 服務: kafka-0 Pod

## 目錄結構

```
WF-20251223-kafka-oom-fix/
├── README.md                          # 本文件
├── 01-analysis.md                     # OOM 根因分析
├── 02-implementation-guide.md         # 實施指南
├── script/
│   ├── backup-config.sh              # 配置備份腳本
│   └── rollback.sh                   # 回滾腳本
├── data/
│   ├── backup/                       # 原始配置備份
│   │   ├── statefulset.yml
│   │   └── forex.env
│   └── solution-b/                   # 方案 B 修改後配置
│       ├── statefulset.yml
│       └── forex.env
└── worklogs/
    └── WORKLOG-20251223-implementation.md
```

## 快速導航

1. [根因分析](01-analysis.md) - 詳細的記憶體分析與問題識別
2. [實施指南](02-implementation-guide.md) - 完整的修復步驟
3. [部署後驗證](03-post-deployment-verification.md) - 驗證與監控指引
4. [自動化指南](04-automation-guide.md) - 自動化監控腳本使用 ⭐
5. [配置對比](#配置變更摘要) - 修改前後對比

## 配置變更摘要

### JVM 記憶體參數
- Heap: 4GB → 3GB
- 新增 Direct Memory 限制: 1.5GB

### 容器資源
- Memory Request: 512Mi → 2Gi
- Memory Limit: 5Gi → 6Gi

### 緩衝區配置
- Message Max: 50MB → 10MB
- Socket Request Max: 500MB → 100MB
- Replica Fetch Max: 500MB → 100MB
- Consumer Fetch Max: 50MB → 10MB

## 相關檔案

### 原始配置
- [statefulset.yml](/Users/user/FOREX-project/hkidc-k8s-gitlab/forex-stg/forex-stage-k8s-deploy/kafka-cluster/statefulset.yml)
- [forex.env](/Users/user/FOREX-project/hkidc-k8s-gitlab/forex-stg/forex-stage-k8s-deploy/kafka-cluster/env/forex.env)

### 修改後配置
- [solution-b/statefulset.yml](data/solution-b/statefulset.yml)
- [solution-b/forex.env](data/solution-b/forex.env)

## 執行流程

1. **準備階段** ✅
   - 建立 WF 目錄結構
   - 備份當前配置
   - 準備修改後配置

2. **驗證階段** (待執行)
   - 檢查配置差異
   - 驗證修改正確性

3. **部署階段** (待執行)
   - 應用配置變更
   - 監控 Pod 重啟
   - 驗證功能正常

4. **監控階段** (待執行)
   - 觀察記憶體使用
   - 確認無 OOMKilled
   - 記錄實際使用量

## 參考文件

- [AGENTS.md](/Users/user/CLAUDE/AGENTS.md) - AI 協作規範
- [Plan 文件](/Users/user/.claude/plans/squishy-hatching-bonbon.md) - 完整實施計畫
