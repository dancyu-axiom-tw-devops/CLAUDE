#!/bin/bash
# check-logs-exist.sh
# Check if log files exist in NAS for jc-refactor services
# Usage: ./check-logs-exist.sh

NAMESPACE="jc-prod"
LOG_BASE_PATH="/juancash/logs"

echo "========================================"
echo "JC-Refactor Log File Existence Check"
echo "========================================"
echo ""
echo "Namespace: $NAMESPACE"
echo "Log base path: $LOG_BASE_PATH"
echo "Timestamp: $(date)"
echo ""

# Get a running pod to exec into for checking NAS
PROBE_POD=$(kubectl get pods -n $NAMESPACE -l app=juanworld-api -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ -z "$PROBE_POD" ]; then
    echo "ERROR: Cannot find a running pod to check logs"
    echo "Tried: juanworld-api pods in namespace $NAMESPACE"
    exit 1
fi

echo "Using pod for NAS check: $PROBE_POD"
echo ""

# Function to check if log directory exists and has recent files
check_log_directory() {
    local service_name=$1
    local log_dir="$LOG_BASE_PATH/$service_name"

    echo "=== $service_name ==="

    # Check if directory exists
    if ! kubectl exec -n $NAMESPACE $PROBE_POD -- test -d "$log_dir" 2>/dev/null; then
        echo "Status: LOG DIRECTORY NOT FOUND"
        echo "Path: $log_dir"
        echo ""
        return
    fi

    # Check if directory has files
    FILE_COUNT=$(kubectl exec -n $NAMESPACE $PROBE_POD -- sh -c "ls -1 $log_dir 2>/dev/null | wc -l" 2>/dev/null | tr -d ' ')

    if [ "$FILE_COUNT" -eq 0 ]; then
        echo "Status: NO LOG FILES"
        echo "Path: $log_dir"
        echo ""
        return
    fi

    # Get recent log files (modified in last 24 hours)
    RECENT_FILES=$(kubectl exec -n $NAMESPACE $PROBE_POD -- sh -c "find $log_dir -type f -mtime -1 2>/dev/null | wc -l" 2>/dev/null | tr -d ' ')

    echo "Status: OK"
    echo "Path: $log_dir"
    echo "Total files: $FILE_COUNT"
    echo "Recent files (last 24h): $RECENT_FILES"

    # Show latest log file
    LATEST_FILE=$(kubectl exec -n $NAMESPACE $PROBE_POD -- sh -c "ls -t $log_dir/*.log 2>/dev/null | head -1" 2>/dev/null)
    if [ -n "$LATEST_FILE" ]; then
        LATEST_MODIFIED=$(kubectl exec -n $NAMESPACE $PROBE_POD -- stat -c '%y' "$LATEST_FILE" 2>/dev/null | cut -d'.' -f1)
        echo "Latest file: $(basename $LATEST_FILE) (modified: $LATEST_MODIFIED)"
    fi

    echo ""
}

# API Services
echo "API SERVICES"
echo "========================================"
echo ""

check_log_directory "juanworld-api"
check_log_directory "juanworld-admin-api"
check_log_directory "juancash-open-api"
check_log_directory "juancash-bank-api"
check_log_directory "juancash-applet-api"
check_log_directory "juancash-clicent-api"
check_log_directory "juanword-api-shopmanager"

# APP Services (selected important ones)
echo "APP SERVICES (Sample)"
echo "========================================"
echo ""

check_log_directory "juancash-admin-bank"
check_log_directory "juancash-admin-pay"
check_log_directory "juancash-app-bank"
check_log_directory "juancash-app-pay"
check_log_directory "juancash-scheduler-bank"
check_log_directory "juancash-scheduler-pay"

echo "========================================"
echo "Summary"
echo "========================================"
echo ""
echo "Note: This check uses NAS mount from pod: $PROBE_POD"
echo "To check all 37 services, modify this script to include all service names"
echo "Log base path: $LOG_BASE_PATH"
echo ""
