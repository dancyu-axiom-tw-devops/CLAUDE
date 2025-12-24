#!/bin/bash
# monitor-resources.sh
# Continuous monitoring for exchange-service memory and performance
# Usage: ./monitor-resources.sh [interval_seconds] [count]
# Example: ./monitor-resources.sh 300 288  # Every 5 mins for 24 hours

INTERVAL=${1:-300}
COUNT=${2:-288}
NAMESPACE="forex-prod"
APP="exchange-service"
HPA_NAME="exchange-service-hpa"

# Create data directory if not exists
DATA_DIR="$(dirname "$0")/../data"
mkdir -p "$DATA_DIR"

LOGFILE="$DATA_DIR/monitor-$(date +%Y%m%d_%H%M%S).log"

echo "======================================"
echo "Exchange Service Resource Monitoring"
echo "======================================"
echo "Interval: ${INTERVAL} seconds"
echo "Count: ${COUNT} iterations"
echo "Log file: ${LOGFILE}"
echo "Start time: $(date)"
echo ""

for i in $(seq 1 $COUNT); do
  {
    echo "======================================"
    echo "Monitor Iteration #${i}/${COUNT}"
    echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "======================================"

    # Pod Status
    echo ""
    echo "--- Pod Status ---"
    kubectl get pods -n $NAMESPACE -l app=$APP 2>&1

    # Memory Usage
    echo ""
    echo "--- Memory Usage ---"
    MEMORY_OUTPUT=$(kubectl top pods -n $NAMESPACE -l app=$APP --no-headers 2>&1)

    if echo "$MEMORY_OUTPUT" | grep -q "error\|Metrics"; then
      echo "⚠️  Metrics not available"
      echo "$MEMORY_OUTPUT"
    else
      kubectl top pods -n $NAMESPACE -l app=$APP 2>&1

      # Calculate total memory
      TOTAL_MEMORY=0
      POD_COUNT=0
      while read -r line; do
        if [ ! -z "$line" ]; then
          MEMORY=$(echo "$line" | awk '{print $3}' | sed 's/Mi//')
          if [ ! -z "$MEMORY" ] && [ "$MEMORY" -eq "$MEMORY" ] 2>/dev/null; then
            TOTAL_MEMORY=$((TOTAL_MEMORY + MEMORY))
            ((POD_COUNT++))
          fi
        fi
      done <<< "$MEMORY_OUTPUT"

      echo ""
      echo "Pod Count: $POD_COUNT"
      echo "Total Memory: ${TOTAL_MEMORY}Mi"

      if [ $POD_COUNT -gt 0 ]; then
        AVG_MEMORY=$((TOTAL_MEMORY / POD_COUNT))
        echo "Average Memory: ${AVG_MEMORY}Mi"
      fi

      # Memory alerts
      if [ $TOTAL_MEMORY -gt 5900 ]; then
        echo "🚨 CRITICAL: Memory usage ${TOTAL_MEMORY}Mi > 5900Mi (> 96% of 6144Mi limit)"
      elif [ $TOTAL_MEMORY -gt 5500 ]; then
        echo "🔴 SEVERE: Memory usage ${TOTAL_MEMORY}Mi > 5500Mi (> 90% of 6144Mi limit)"
      elif [ $TOTAL_MEMORY -gt 5000 ]; then
        echo "⚠️  WARNING: Memory usage ${TOTAL_MEMORY}Mi > 5000Mi (> 81% of 6144Mi limit)"
      else
        echo "✅ OK: Memory usage ${TOTAL_MEMORY}Mi within normal range"
      fi
    fi

    # HPA Status
    echo ""
    echo "--- HPA Status ---"
    HPA_OUTPUT=$(kubectl get hpa $HPA_NAME -n $NAMESPACE 2>&1)
    if echo "$HPA_OUTPUT" | grep -q "Error\|NotFound"; then
      echo "⚠️  HPA not found or error"
      echo "$HPA_OUTPUT"
    else
      kubectl get hpa $HPA_NAME -n $NAMESPACE 2>&1

      CURRENT_REPLICAS=$(kubectl get hpa $HPA_NAME -n $NAMESPACE -o jsonpath='{.status.currentReplicas}' 2>/dev/null || echo "N/A")
      DESIRED_REPLICAS=$(kubectl get hpa $HPA_NAME -n $NAMESPACE -o jsonpath='{.status.desiredReplicas}' 2>/dev/null || echo "N/A")

      echo "Current Replicas: $CURRENT_REPLICAS"
      echo "Desired Replicas: $DESIRED_REPLICAS"

      if [ "$CURRENT_REPLICAS" != "N/A" ] && [ "$CURRENT_REPLICAS" -lt 2 ]; then
        echo "⚠️  WARNING: Current replicas < 2 (high availability risk)"
      fi
    fi

    # Restart Count
    echo ""
    echo "--- Restart Count ---"
    RESTART_OUTPUT=$(kubectl get pods -n $NAMESPACE -l app=$APP -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.containerStatuses[0].restartCount}{"\n"}{end}' 2>&1)

    if [ -z "$RESTART_OUTPUT" ]; then
      echo "No pods found"
    else
      echo "Pod Name                           Restarts"
      echo "$RESTART_OUTPUT"

      MAX_RESTARTS=$(echo "$RESTART_OUTPUT" | awk '{print $2}' | sort -n | tail -1)
      if [ ! -z "$MAX_RESTARTS" ] && [ "$MAX_RESTARTS" -gt 0 ]; then
        echo "⚠️  WARNING: Detected pod restarts (max: $MAX_RESTARTS)"
      else
        echo "✅ OK: No pod restarts"
      fi
    fi

    # OOM Events (last 5)
    echo ""
    echo "--- Recent OOM Events ---"
    OOM_EVENTS=$(kubectl get events -n $NAMESPACE --field-selector reason=OOMKilling --sort-by='.lastTimestamp' 2>&1 | grep $APP | tail -5)

    if [ -z "$OOM_EVENTS" ]; then
      echo "✅ No OOMKilled events"
    else
      echo "🔴 OOMKilled events detected:"
      echo "$OOM_EVENTS"
    fi

    # Recent Events (last 10)
    echo ""
    echo "--- Recent Events (last 10) ---"
    kubectl get events -n $NAMESPACE --field-selector involvedObject.name=$APP --sort-by='.lastTimestamp' 2>&1 | tail -10

    # Separator
    echo ""
    echo "======================================"
    echo ""

  } | tee -a "$LOGFILE"

  # Wait for next iteration
  if [ $i -lt $COUNT ]; then
    echo "Next check in ${INTERVAL} seconds... (Ctrl+C to stop)" | tee -a "$LOGFILE"
    sleep $INTERVAL
  fi
done

echo "" | tee -a "$LOGFILE"
echo "======================================"  | tee -a "$LOGFILE"
echo "Monitoring Completed" | tee -a "$LOGFILE"
echo "End time: $(date)" | tee -a "$LOGFILE"
echo "Log file: ${LOGFILE}" | tee -a "$LOGFILE"
echo "======================================" | tee -a "$LOGFILE"
