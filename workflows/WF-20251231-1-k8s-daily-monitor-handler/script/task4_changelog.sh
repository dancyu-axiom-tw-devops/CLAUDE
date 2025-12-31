#!/bin/sh
# Task 4: Update CHANGELOG.md following CLAUDE.md format
# Usage: ./task4_changelog.sh

set -e

PROJECT_DIR="/Users/user/MONITOR/k8s-daily-monitor"
LOG_DIR="${PROJECT_DIR}/logs"
TODAY=$(date +%Y-%m-%d)
TODAY_SLASH=$(date +%Y/%m/%d)
MONTH_HEADER=$(date +%Y/%m)
LOG_FILE="${LOG_DIR}/sync_${TODAY}.log"
CHANGELOG="${PROJECT_DIR}/CHANGELOG.md"
STATS_FILE="${PROJECT_DIR}/.today_stats"
SUMMARY_FILE="${PROJECT_DIR}/summary/${TODAY}.md"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "===== Task 4: Update CHANGELOG ====="

cd "$PROJECT_DIR" || exit 1

# Load stats from Task 3
if [ -f "$STATS_FILE" ]; then
    . "$STATS_FILE"
else
    log "WARN: Stats file not found, using defaults"
    HEALTHY=0
    WARNING=0
    CRITICAL=0
    TOTAL=0
    HEALTH_RATE="N/A"
    OVERALL_STATUS="UNKNOWN"
    OVERALL_ICON="❓"
fi

# Create CHANGELOG if not exists
if [ ! -f "$CHANGELOG" ]; then
    log "Creating new CHANGELOG.md..."
    cat > "$CHANGELOG" << 'EOF'
# CHANGELOG.md

K8s Daily Monitor change log.

EOF
fi

# Check if today's entry already exists
if grep -q "^\* ${TODAY_SLASH}$" "$CHANGELOG" 2>/dev/null; then
    log "WARN: Entry for $TODAY_SLASH already exists, skipping"
    log "===== Task 4 Complete (skipped) ====="
    exit 0
fi

# Determine status emoji for title
case "$OVERALL_STATUS" in
    CRITICAL) STATUS_EMOJI="❌" ;;
    WARNING)  STATUS_EMOJI="⚠️" ;;
    HEALTHY)  STATUS_EMOJI="✅" ;;
    *)        STATUS_EMOJI="🔍" ;;
esac

# Build new entry following CLAUDE.md format
NEW_ENTRY="* ${TODAY_SLASH}
  * **🔍 K8s Health Check Report** ${STATUS_EMOJI}
    * report: Daily cluster health check results
      * ✅ **Healthy**: ${HEALTHY} items
      * ⚠️ **Warning**: ${WARNING} items
      * ❌ **Critical**: ${CRITICAL} items
      * 📊 **Health Rate**: ${HEALTH_RATE}%
      * 📁 **Summary**: [summary/${TODAY}.md](summary/${TODAY}.md)"

# Check if month header exists
MONTH_PATTERN="^## 📆 ${MONTH_HEADER}$"

if grep -q "$MONTH_PATTERN" "$CHANGELOG" 2>/dev/null; then
    # Month header exists, insert entry after it
    log "Adding entry under existing month header: $MONTH_HEADER"
    
    # Create temp file
    TEMP_FILE=$(mktemp)
    
    awk -v month="## 📆 ${MONTH_HEADER}" -v entry="$NEW_ENTRY" '
    {
        print
        if ($0 == month) {
            print ""
            print entry
        }
    }
    ' "$CHANGELOG" > "$TEMP_FILE"
    
    mv "$TEMP_FILE" "$CHANGELOG"
else
    # Month header does not exist, add new section
    log "Creating new month section: $MONTH_HEADER"
    
    # Find insertion point (after title/description, before first ## or at end)
    TEMP_FILE=$(mktemp)
    
    # Add new month section after the header
    awk -v month="## 📆 ${MONTH_HEADER}" -v entry="$NEW_ENTRY" '
    BEGIN { inserted = 0 }
    /^## / && !inserted {
        print month
        print ""
        print entry
        print ""
        inserted = 1
    }
    { print }
    END {
        if (!inserted) {
            print ""
            print month
            print ""
            print entry
        }
    }
    ' "$CHANGELOG" > "$TEMP_FILE"
    
    mv "$TEMP_FILE" "$CHANGELOG"
fi

log "CHANGELOG updated successfully"
log "Entry added:"
echo "$NEW_ENTRY" | while read -r line; do
    log "  $line"
done

# Cleanup temp files
rm -f "${PROJECT_DIR}/.today_reports" "${PROJECT_DIR}/.today_stats" 2>/dev/null

log "===== Task 4 Complete ====="
