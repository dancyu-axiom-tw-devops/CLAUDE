#!/bin/sh
# Task 3: Analyze health check reports and generate summary
# Usage: ./task3_analyze.sh

set -e

PROJECT_DIR="/Users/user/MONITOR/k8s-daily-monitor"
SUMMARY_DIR="${PROJECT_DIR}/summary"
LOG_DIR="${PROJECT_DIR}/logs"
TODAY=$(date +%Y-%m-%d)
LOG_FILE="${LOG_DIR}/sync_${TODAY}.log"
REPORT_LIST="${PROJECT_DIR}/.today_reports"
SUMMARY_FILE="${SUMMARY_DIR}/${TODAY}.md"
STATS_FILE="${PROJECT_DIR}/.today_stats"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "===== Task 3: Analyze Reports ====="

cd "$PROJECT_DIR" || exit 1
mkdir -p "$SUMMARY_DIR"

# Initialize counters
TOTAL=0
HEALTHY=0
WARNING=0
CRITICAL=0

# Generate summary header
cat > "$SUMMARY_FILE" << EOF
# K8s Health Check Summary

**Date**: ${TODAY}
**Generated**: $(date '+%Y-%m-%d %H:%M:%S')

---

## Overview

EOF

# Check if report list exists
if [ ! -f "$REPORT_LIST" ] || [ ! -s "$REPORT_LIST" ]; then
    log "WARN: No report list found, scanning reports directory..."
    find "${PROJECT_DIR}/reports" -type f \( -name "*.json" -o -name "*.yaml" -o -name "*.md" \) 2>/dev/null | head -10 > "$REPORT_LIST"
fi

# Process each report
log "Analyzing reports..."

while read -r report_file; do
    [ -z "$report_file" ] && continue
    [ ! -f "$report_file" ] && continue
    
    FILENAME=$(basename "$report_file")
    log "Processing: $FILENAME"
    
    # Count status occurrences (case-insensitive)
    if [ -f "$report_file" ]; then
        # Count healthy/ok/running/ready
        H=$(grep -ciE '"status"[[:space:]]*:[[:space:]]*"(healthy|ok|running|ready|pass|true)"' "$report_file" 2>/dev/null || echo 0)
        # Count warning/degraded/pending
        W=$(grep -ciE '"status"[[:space:]]*:[[:space:]]*"(warning|degraded|pending|unknown)"' "$report_file" 2>/dev/null || echo 0)
        # Count error/failed/critical
        C=$(grep -ciE '"status"[[:space:]]*:[[:space:]]*"(error|failed|critical|unhealthy|false)"' "$report_file" 2>/dev/null || echo 0)
        
        HEALTHY=$((HEALTHY + H))
        WARNING=$((WARNING + W))
        CRITICAL=$((CRITICAL + C))
        TOTAL=$((TOTAL + H + W + C))
        
        # Add to summary
        echo "### $FILENAME" >> "$SUMMARY_FILE"
        echo "" >> "$SUMMARY_FILE"
        echo "- Healthy: $H" >> "$SUMMARY_FILE"
        echo "- Warning: $W" >> "$SUMMARY_FILE"
        echo "- Critical: $C" >> "$SUMMARY_FILE"
        echo "" >> "$SUMMARY_FILE"
    fi
done < "$REPORT_LIST"

# Calculate health rate
if [ "$TOTAL" -gt 0 ]; then
    # Use awk for floating point calculation
    HEALTH_RATE=$(echo "$HEALTHY $TOTAL" | awk '{printf "%.1f", ($1/$2)*100}')
else
    HEALTH_RATE="N/A"
fi

# Write statistics summary
cat >> "$SUMMARY_FILE" << EOF
---

## Statistics

| Status | Count |
|--------|-------|
| Healthy | $HEALTHY |
| Warning | $WARNING |
| Critical | $CRITICAL |
| **Total** | **$TOTAL** |

**Health Rate**: ${HEALTH_RATE}%

EOF

# Determine overall status
if [ "$CRITICAL" -gt 0 ]; then
    OVERALL_STATUS="CRITICAL"
    OVERALL_ICON="❌"
elif [ "$WARNING" -gt 0 ]; then
    OVERALL_STATUS="WARNING"
    OVERALL_ICON="⚠️"
else
    OVERALL_STATUS="HEALTHY"
    OVERALL_ICON="✅"
fi

echo "**Overall Status**: ${OVERALL_ICON} ${OVERALL_STATUS}" >> "$SUMMARY_FILE"

# Save stats for Task 4
cat > "$STATS_FILE" << EOF
HEALTHY=$HEALTHY
WARNING=$WARNING
CRITICAL=$CRITICAL
TOTAL=$TOTAL
HEALTH_RATE=$HEALTH_RATE
OVERALL_STATUS=$OVERALL_STATUS
OVERALL_ICON=$OVERALL_ICON
EOF

log "Statistics:"
log "  Healthy: $HEALTHY"
log "  Warning: $WARNING"
log "  Critical: $CRITICAL"
log "  Total: $TOTAL"
log "  Health Rate: ${HEALTH_RATE}%"
log "  Overall: $OVERALL_STATUS"

log "Summary saved to: $SUMMARY_FILE"
log "===== Task 3 Complete ====="
