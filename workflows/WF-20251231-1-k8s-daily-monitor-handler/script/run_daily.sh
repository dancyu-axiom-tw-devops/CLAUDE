#!/bin/sh
# K8s Daily Monitor - Run all tasks
# Usage: ./run_daily.sh

set -e

PROJECT_DIR="/Users/user/MONITOR/k8s-daily-monitor"
SCRIPT_DIR="${PROJECT_DIR}/scripts"
LOG_DIR="${PROJECT_DIR}/logs"
TODAY=$(date +%Y-%m-%d)
LOG_FILE="${LOG_DIR}/daily_${TODAY}.log"

# Create directories
mkdir -p "$LOG_DIR"
mkdir -p "${PROJECT_DIR}/summary"
mkdir -p "$SCRIPT_DIR"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "============================================"
log "K8s Daily Monitor"
log "Date: $TODAY"
log "Project: $PROJECT_DIR"
log "============================================"
echo ""

# Task 1: Sync data
log "[1/4] Sync data..."
if [ -f "${SCRIPT_DIR}/task1_sync.sh" ]; then
    sh "${SCRIPT_DIR}/task1_sync.sh"
else
    log "WARN: task1_sync.sh not found, running git pull directly"
    cd "$PROJECT_DIR"
    git pull 2>&1 | tee -a "$LOG_FILE"
fi
echo ""

# Task 2: Detect reports
log "[2/4] Detect new reports..."
if [ -f "${SCRIPT_DIR}/task2_detect.sh" ]; then
    sh "${SCRIPT_DIR}/task2_detect.sh"
else
    log "WARN: task2_detect.sh not found"
fi
echo ""

# Task 3: Analyze
log "[3/4] Analyze reports..."
if [ -f "${SCRIPT_DIR}/task3_analyze.sh" ]; then
    sh "${SCRIPT_DIR}/task3_analyze.sh"
else
    log "WARN: task3_analyze.sh not found"
fi
echo ""

# Task 4: Update CHANGELOG
log "[4/4] Update CHANGELOG..."
if [ -f "${SCRIPT_DIR}/task4_changelog.sh" ]; then
    sh "${SCRIPT_DIR}/task4_changelog.sh"
else
    log "WARN: task4_changelog.sh not found"
fi
echo ""

log "============================================"
log "All tasks completed"
log "============================================"
log "Output files:"
log "  - summary/${TODAY}.md"
log "  - CHANGELOG.md"
log "  - logs/daily_${TODAY}.log"
