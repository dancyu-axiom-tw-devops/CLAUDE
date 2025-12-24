#!/bin/bash
# Continuous memory monitoring script
# Usage: ./monitor-memory.sh [interval_seconds] [duration_minutes]
# Example: ./monitor-memory.sh 60 1440  # Monitor every 60s for 24 hours

NAMESPACE="forex-stg"
POD_NAME="kafka-0"
INTERVAL=${1:-300}  # Default 5 minutes
DURATION=${2:-1440} # Default 24 hours
REPORT_DIR="/Users/user/CLAUDE/docs/workflows/WF-20251223-kafka-oom-fix/data/monitoring"

# Create monitoring directory
mkdir -p "$REPORT_DIR"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
MONITOR_FILE="$REPORT_DIR/memory_monitor_${TIMESTAMP}.csv"
LOG_FILE="$REPORT_DIR/monitor_${TIMESTAMP}.log"

# Calculate iterations
ITERATIONS=$((DURATION * 60 / INTERVAL))

echo "Memory Monitoring Started"
echo "Namespace: $NAMESPACE"
echo "Pod: $POD_NAME"
echo "Interval: ${INTERVAL}s"
echo "Duration: ${DURATION}min ($ITERATIONS iterations)"
echo "Output: $MONITOR_FILE"
echo ""

# CSV Header
echo "timestamp,epoch,memory_mi,memory_pct,cpu_cores,restarts,status,heap_used_mb,nonheap_used_mb,direct_buffer_mb" > "$MONITOR_FILE"

for i in $(seq 1 $ITERATIONS); do
    CURRENT_TIME=$(date '+%Y-%m-%d %H:%M:%S')
    EPOCH=$(date +%s)

    # Get Pod status
    POD_STATUS=$(kubectl -n $NAMESPACE get pod $POD_NAME -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")

    if [ "$POD_STATUS" = "Running" ]; then
        # Get memory and CPU usage
        METRICS=$(kubectl -n $NAMESPACE top pod $POD_NAME --no-headers 2>/dev/null || echo "N/A N/A N/A")
        CPU=$(echo $METRICS | awk '{print $2}')
        MEMORY=$(echo $METRICS | awk '{print $3}')

        # Get restart count
        RESTARTS=$(kubectl -n $NAMESPACE get pod $POD_NAME -o jsonpath='{.status.containerStatuses[0].restartCount}' 2>/dev/null || echo "0")

        # Extract memory value
        if [ "$MEMORY" != "N/A" ]; then
            MEMORY_MI=$(echo $MEMORY | sed 's/Mi//')
            MEMORY_PCT=$((MEMORY_MI * 100 / 6144))  # 6Gi = 6144Mi
        else
            MEMORY_MI="N/A"
            MEMORY_PCT="N/A"
        fi

        # Get JVM metrics (if available)
        HEAP_USED=$(kubectl -n $NAMESPACE exec $POD_NAME -- curl -s localhost:5556/metrics 2>/dev/null | \
            grep 'jvm_memory_used_bytes{area="heap"}' | head -1 | awk '{print $2}' || echo "0")
        HEAP_USED_MB=$((HEAP_USED / 1024 / 1024))

        NONHEAP_USED=$(kubectl -n $NAMESPACE exec $POD_NAME -- curl -s localhost:5556/metrics 2>/dev/null | \
            grep 'jvm_memory_used_bytes{area="nonheap"}' | head -1 | awk '{print $2}' || echo "0")
        NONHEAP_USED_MB=$((NONHEAP_USED / 1024 / 1024))

        DIRECT_BUFFER=$(kubectl -n $NAMESPACE exec $POD_NAME -- curl -s localhost:5556/metrics 2>/dev/null | \
            grep 'jvm_buffer_pool_used_bytes{pool="direct"}' | head -1 | awk '{print $2}' || echo "0")
        DIRECT_BUFFER_MB=$((DIRECT_BUFFER / 1024 / 1024))

        # Write to CSV
        echo "$CURRENT_TIME,$EPOCH,$MEMORY_MI,$MEMORY_PCT,$CPU,$RESTARTS,$POD_STATUS,$HEAP_USED_MB,$NONHEAP_USED_MB,$DIRECT_BUFFER_MB" >> "$MONITOR_FILE"

        # Console output
        printf "[%s] Iter %d/%d | Memory: %s (%s%%) | CPU: %s | Heap: %dMB | Direct: %dMB | Restarts: %s\n" \
            "$CURRENT_TIME" "$i" "$ITERATIONS" "$MEMORY" "$MEMORY_PCT" "$CPU" "$HEAP_USED_MB" "$DIRECT_BUFFER_MB" "$RESTARTS"

        # Alert if high memory usage
        if [ "$MEMORY_PCT" != "N/A" ] && [ "$MEMORY_PCT" -gt 85 ]; then
            echo "⚠️  WARNING: High memory usage detected: ${MEMORY_PCT}%" | tee -a "$LOG_FILE"
        fi

        # Alert if OOMKilled
        LAST_TERM=$(kubectl -n $NAMESPACE get pod $POD_NAME -o jsonpath='{.status.containerStatuses[0].lastState.terminated.reason}' 2>/dev/null || echo "")
        if [ "$LAST_TERM" = "OOMKilled" ]; then
            echo "🚨 ALERT: OOMKilled detected at $CURRENT_TIME" | tee -a "$LOG_FILE"
            echo "OOM,$CURRENT_TIME,$EPOCH,$MEMORY_MI,$MEMORY_PCT" >> "$LOG_FILE"
        fi

    else
        echo "$CURRENT_TIME,$EPOCH,N/A,N/A,N/A,N/A,$POD_STATUS,N/A,N/A,N/A" >> "$MONITOR_FILE"
        echo "⚠️  Pod status: $POD_STATUS" | tee -a "$LOG_FILE"
    fi

    # Sleep until next iteration (except last)
    if [ $i -lt $ITERATIONS ]; then
        sleep $INTERVAL
    fi
done

echo ""
echo "Monitoring completed!"
echo "Results saved to: $MONITOR_FILE"
echo ""
echo "To analyze results:"
echo "  cat $MONITOR_FILE | column -t -s,"
echo ""
echo "To get statistics:"
echo "  awk -F',' 'NR>1 && \$3!=\"N/A\" {sum+=\$3; count++; if(\$3>max) max=\$3; if(min==\"\" || \$3<min) min=\$3} END {print \"Avg:\", sum/count, \"Min:\", min, \"Max:\", max}' $MONITOR_FILE"
