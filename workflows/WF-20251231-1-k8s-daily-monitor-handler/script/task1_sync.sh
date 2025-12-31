#!/bin/sh
# Task 1: Sync latest health check data from git
# Usage: ./task1_sync.sh

set -e

PROJECT_DIR="/Users/user/MONITOR/k8s-daily-monitor"
LOG_DIR="${PROJECT_DIR}/logs"
TODAY=$(date +%Y-%m-%d)
LOG_FILE="${LOG_DIR}/sync_${TODAY}.log"

# Create log directory
mkdir -p "$LOG_DIR"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "===== Task 1: Sync Data ====="
log "Project: $PROJECT_DIR"

cd "$PROJECT_DIR" || {
    log "ERROR: Cannot access project directory"
    exit 1
}

# Check for uncommitted changes
if [ -n "$(git status -s 2>/dev/null)" ]; then
    log "WARN: Uncommitted local changes detected, stashing..."
    git stash
fi

# Pull latest changes
log "Executing git pull..."
PULL_OUTPUT=$(git pull origin main 2>&1) || PULL_OUTPUT=$(git pull 2>&1)
echo "$PULL_OUTPUT" | tee -a "$LOG_FILE"

# Check result
if echo "$PULL_OUTPUT" | grep -q "Already up to date"; then
    log "INFO: Repository already up to date"
elif echo "$PULL_OUTPUT" | grep -q "Updating\|Fast-forward"; then
    log "SUCCESS: New changes pulled"
    # Show latest commit
    log "Latest commit:"
    git log -1 --oneline | tee -a "$LOG_FILE"
else
    log "WARN: Unexpected pull result"
fi

log "===== Task 1 Complete ====="
