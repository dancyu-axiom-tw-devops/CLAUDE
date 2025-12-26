# 自動化監控指南

## 概述

已建立兩個自動化腳本，無需手動操作即可完成驗證和監控。

## 可用腳本

### 1. verify-deployment.sh - 部署驗證腳本

**功能**: 自動執行完整的部署驗證檢查

**檢查項目**:
- ✅ Pod 狀態
- ✅ OOMKilled 檢查
- ✅ 資源配置驗證
- ✅ 記憶體使用檢查
- ✅ JVM 參數驗證
- ✅ Kafka 功能測試
- ✅ JMX Metrics 檢查

**使用方式**:
```bash
cd /Users/user/CLAUDE/docs/workflows/WF-20251223-kafka-oom-fix/script
./verify-deployment.sh
```

**輸出**:
- 彩色終端輸出（即時查看）
- 驗證報告保存至 `data/verification-reports/verification_YYYYMMDD_HHMMSS.txt`

**執行時間**: 約 10-30 秒

### 2. monitor-memory.sh - 持續記憶體監控

**功能**: 持續監控記憶體使用並記錄到 CSV

**使用方式**:
```bash
# 基本用法 (預設: 每5分鐘檢查，持續24小時)
./monitor-memory.sh

# 自訂間隔和持續時間
./monitor-memory.sh [間隔秒數] [持續分鐘數]

# 範例: 每1分鐘檢查，持續6小時
./monitor-memory.sh 60 360

# 範例: 每30秒檢查，持續1小時
./monitor-memory.sh 30 60
```

**監控指標**:
- 容器記憶體使用 (Mi 和 %)
- CPU 使用
- Pod 重啟次數
- JVM Heap 使用量
- JVM Non-Heap 使用量
- Direct Buffer 使用量

**輸出**:
- 即時終端輸出
- CSV 記錄保存至 `data/monitoring/memory_monitor_YYYYMMDD_HHMMSS.csv`
- 異常事件記錄至 `data/monitoring/monitor_YYYYMMDD_HHMMSS.log`

**告警**:
- 記憶體使用 > 85%: 自動顯示警告
- OOMKilled 事件: 自動記錄並告警

## 快速開始

### 立即驗證部署

```bash
cd /Users/user/CLAUDE/docs/workflows/WF-20251223-kafka-oom-fix/script
./verify-deployment.sh
```

### 背景運行監控 (24 小時)

```bash
# 在背景運行，每5分鐘檢查一次，持續24小時
nohup ./monitor-memory.sh 300 1440 > monitor.out 2>&1 &

# 查看監控進程
ps aux | grep monitor-memory

# 即時查看輸出
tail -f monitor.out
```

### 停止背景監控

```bash
# 找到進程 ID
ps aux | grep monitor-memory.sh | grep -v grep

# 終止進程
kill [PID]
```

## 排程自動化

### 使用 cron 定時執行驗證

```bash
# 編輯 crontab
crontab -e

# 每小時執行驗證
0 * * * * /Users/user/CLAUDE/docs/workflows/WF-20251223-kafka-oom-fix/script/verify-deployment.sh >> /tmp/kafka-verify.log 2>&1

# 每6小時執行驗證
0 */6 * * * /Users/user/CLAUDE/docs/workflows/WF-20251223-kafka-oom-fix/script/verify-deployment.sh >> /tmp/kafka-verify.log 2>&1
```

### 查看 cron 執行記錄

```bash
tail -f /tmp/kafka-verify.log
```

## 數據分析

### 查看驗證報告

```bash
# 列出所有報告
ls -lt /Users/user/CLAUDE/docs/workflows/WF-20251223-kafka-oom-fix/data/verification-reports/

# 查看最新報告
cat /Users/user/CLAUDE/docs/workflows/WF-20251223-kafka-oom-fix/data/verification-reports/verification_*.txt | tail -100
```

### 分析監控數據

```bash
cd /Users/user/CLAUDE/docs/workflows/WF-20251223-kafka-oom-fix/data/monitoring

# 查看 CSV 數據（格式化）
cat memory_monitor_*.csv | column -t -s,

# 計算統計數據
awk -F',' 'NR>1 && $3!="N/A" {
    sum+=$3; count++;
    if($3>max) max=$3;
    if(min=="" || $3<min) min=$3
} END {
    print "Memory Usage Statistics:"
    print "  Average:", sum/count, "Mi"
    print "  Minimum:", min, "Mi"
    print "  Maximum:", max, "Mi"
}' memory_monitor_*.csv

# 查看記憶體趨勢
awk -F',' 'NR>1 && $3!="N/A" {print $1, $3"Mi", "("$4"%)"}' memory_monitor_*.csv

# 查看高記憶體使用時段
awk -F',' 'NR>1 && $4!="N/A" && $4>70 {print $1, "Memory:", $4"%"}' memory_monitor_*.csv
```

### 生成圖表（如有 gnuplot）

```bash
# 準備數據
awk -F',' 'NR>1 && $3!="N/A" {print NR-1, $3}' memory_monitor_*.csv > /tmp/memory.dat

# 使用 gnuplot 繪圖
gnuplot <<EOF
set terminal png size 1200,600
set output 'memory_trend.png'
set title 'Kafka Memory Usage Over Time'
set xlabel 'Sample'
set ylabel 'Memory (Mi)'
set grid
plot '/tmp/memory.dat' with lines title 'Memory Usage'
EOF

echo "Chart saved to memory_trend.png"
```

## 建議監控排程

### 第 1-3 天 (密集監控)

```bash
# 方案 A: 每小時驗證
0 * * * * /path/to/verify-deployment.sh

# 方案 B: 持續監控（每5分鐘）
nohup ./monitor-memory.sh 300 4320 &  # 持續3天
```

### 第 4-14 天 (常規監控)

```bash
# 每6小時驗證
0 */6 * * * /path/to/verify-deployment.sh

# 或每天兩次持續監控
0 9,21 * * * nohup ./monitor-memory.sh 300 360 &  # 每天上午9點和晚上9點，各監控6小時
```

### 第 15 天後 (輕度監控)

```bash
# 每天驗證一次
0 10 * * * /path/to/verify-deployment.sh
```

## 告警整合

### Slack 通知（範例）

在 `verify-deployment.sh` 中加入：

```bash
# 在腳本開頭加入 Slack Webhook URL
SLACK_WEBHOOK="https://hooks.slack.com/services/YOUR_WEBHOOK_URL"

# 發送告警函數
send_alert() {
    MESSAGE=$1
    curl -X POST -H 'Content-type: application/json' \
        --data "{\"text\":\"🚨 Kafka Alert: $MESSAGE\"}" \
        $SLACK_WEBHOOK
}

# 在檢測到問題時調用
if [ $MEMORY_PCT -gt 85 ]; then
    send_alert "High memory usage: ${MEMORY_PCT}%"
fi
```

### Email 通知（範例）

```bash
# 使用 mail 命令
echo "Memory usage: ${MEMORY_PCT}%" | mail -s "Kafka Memory Alert" your@email.com
```

## 故障排查

### 腳本執行失敗

```bash
# 檢查權限
ls -l /Users/user/CLAUDE/docs/workflows/WF-20251223-kafka-oom-fix/script/*.sh

# 確認可執行
chmod +x /Users/user/CLAUDE/docs/workflows/WF-20251223-kafka-oom-fix/script/*.sh

# 檢查 kubectl 可用性
kubectl version
kubectl -n forex-stg get pod
```

### 無法取得 Metrics

```bash
# 確認 metrics-server 運行
kubectl -n kube-system get pod | grep metrics-server

# 如無 metrics-server，監控腳本會顯示 N/A 但仍可繼續
```

### JMX Metrics 無法訪問

```bash
# 確認 JMX Exporter 端口
kubectl -n forex-stg exec kafka-0 -- netstat -tlnp | grep 5556

# 手動測試
kubectl -n forex-stg exec kafka-0 -- curl -s localhost:5556/metrics | head
```

## 腳本自訂

### 調整檢查項目

編輯 `verify-deployment.sh`，註解掉不需要的檢查：

```bash
# 例如跳過 Kafka 功能測試
# log "======================================"
# log "6. Kafka Functionality Test"
# log "======================================"
```

### 調整告警閾值

```bash
# 在 monitor-memory.sh 中修改
if [ "$MEMORY_PCT" -gt 85 ]; then  # 改為其他值，如 90
    echo "⚠️  WARNING: High memory usage detected: ${MEMORY_PCT}%"
fi
```

### 新增自訂檢查

在 `verify-deployment.sh` 中加入新的檢查區段：

```bash
echo ""
log "======================================"
log "8. Custom Check"
log "======================================"

# 你的自訂檢查邏輯
```

## 總結

- ✅ **完全自動化**: 無需手動操作
- ✅ **持續監控**: 可背景運行數天
- ✅ **自動告警**: 異常狀況自動提示
- ✅ **數據記錄**: 完整的 CSV 和報告
- ✅ **易於分析**: 提供分析命令

立即開始：
```bash
cd /Users/user/CLAUDE/docs/workflows/WF-20251223-kafka-oom-fix/script
./verify-deployment.sh
```
