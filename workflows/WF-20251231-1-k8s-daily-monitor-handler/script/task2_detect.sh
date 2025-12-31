#!/bin/sh
# Task 2: Detect today's new health check reports
# Usage: ./task2_detect.sh

set -e

PROJECT_DIR="/Users/user/MONITOR/k8s-daily-monitor"
REPORT_DIR="${PROJECT_DIR}/reports"
LOG_DIR="${PROJECT_DIR}/logs"
TODAY=$(date +%Y-%m-%d)
TODAY_SHORT=$(date +%Y%m%d)
LOG_FILE="${LOG_DIR}/sync_${TODAY}.log"
REPORT_LIST="${PROJECT_DIR}/.today_reports"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "===== Task 2: Detect New Reports ====="
log "Target date: $TODAY"
log "Report directory: $REPORT_DIR"

cd "$PROJECT_DIR" || exit 1

# Clear previous list
: > "$REPORT_LIST"

# Method 1: Find by filename pattern (YYYY-MM-DD or YYYYMMDD)
log "Searching by filename pattern..."
find "$REPORT_DIR" -type f \( \
    -name "*${TODAY}*" -o \
    -name "*${TODAY_SHORT}*" \
    \) 2>/dev/null | while read -r file; do
    echo "$file" >> "$REPORT_LIST"
done

# Method 2: Find by git changes today
log "Checking git changes..."
git diff --name-only "HEAD@{1}" HEAD 2>/dev/null | grep "^reports/" | while read -r file; do
    if [ -f "$PROJECT_DIR/$file" ]; then
        echo "$PROJECT_DIR/$file" >> "$REPORT_LIST"
    fi
done

# Remove duplicates
if [ -f "$REPORT_LIST" ]; then
    sort -u "$REPORT_LIST" -o "$REPORT_LIST"
    REPORT_COUNT=$(wc -l < "$REPORT_LIST" | tr -d ' ')
else
    REPORT_COUNT=0
fi

log "Found $REPORT_COUNT report(s) for today"

if [ "$REPORT_COUNT" -gt 0 ]; then
    log "Report files:"
    cat "$REPORT_LIST" | while read -r file; do
        log "  - $(basename "$file")"
    done
else
    log "WARN: No reports found for $TODAY"
    # Fallback: list recent reports
    log "Recent reports in directory:"
    find "$REPORT_DIR" -type f -name "*.json" -o -name "*.yaml" -o -name "*.yml" -o -name "*.md" 2>/dev/null | head -5 | while read -r file; do
        log "  - $(basename "$file")"
    done
fi

log "===== Task 2 Complete ====="
log "Report list saved to: $REPORT_LIST"
