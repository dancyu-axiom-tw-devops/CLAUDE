#!/bin/bash
# check-logs-errors.sh
# Check for errors in logs across all jc-refactor services
# Usage: ./check-logs-errors.sh [LINES] [SINCE]
# Example: ./check-logs-errors.sh 500 1h

NAMESPACE="jc-prod"
LINES="${1:-200}"
SINCE="${2:-1h}"

echo "========================================"
echo "JC-Refactor Services Error Log Check"
echo "========================================"
echo ""
echo "Namespace: $NAMESPACE"
echo "Log lines: $LINES per pod"
echo "Time window: Last $SINCE"
echo "Timestamp: $(date)"
echo ""

# Error patterns to search
ERROR_PATTERNS="(error|exception|fatal|fail|panic|timeout|refused|cannot)"
EXCLUDE_PATTERNS="(debug|trace|info.*error.*code|errorcode.*0|error.*null)"

# Function to check logs for errors
check_service_errors() {
    local service_name=$1
    local deployment_name=$2

    echo "=== $service_name ==="

    # Check if deployment exists
    if ! kubectl get deployment $deployment_name -n $NAMESPACE &>/dev/null; then
        echo "Status: DEPLOYMENT NOT FOUND"
        echo ""
        return
    fi

    # Get pod count
    POD_COUNT=$(kubectl get pods -n $NAMESPACE -l app=$deployment_name 2>/dev/null | grep -c "Running")

    if [ "$POD_COUNT" -eq 0 ]; then
        echo "Status: NO RUNNING PODS"
        echo ""
        return
    fi

    echo "Pods running: $POD_COUNT"

    # Fetch and analyze logs
    ERROR_LOG=$(kubectl logs -n $NAMESPACE -l app=$deployment_name --tail=$LINES --since=$SINCE 2>/dev/null | \
        grep -iE "$ERROR_PATTERNS" | \
        grep -viE "$EXCLUDE_PATTERNS")

    if [ -z "$ERROR_LOG" ]; then
        echo "Status: NO ERRORS FOUND"
    else
        ERROR_COUNT=$(echo "$ERROR_LOG" | wc -l | tr -d ' ')
        echo "Status: ERRORS DETECTED ($ERROR_COUNT lines)"
        echo "----------------------------------------"
        echo "$ERROR_LOG" | head -20
        if [ "$ERROR_COUNT" -gt 20 ]; then
            echo "... and $((ERROR_COUNT - 20)) more error lines"
        fi
        echo "----------------------------------------"
    fi

    echo ""
}

# API Services (7)
echo "API SERVICES (7)"
echo "========================================"
echo ""

check_service_errors "JuanWorld API" "juanworld-api"
check_service_errors "JuanWorld Admin API" "juanworld-admin-api"
check_service_errors "JuanCash Open API" "juancash-open-api"
check_service_errors "JuanCash Bank API" "juancash-bank-api"
check_service_errors "JuanCash Applet API" "juancash-applet-api"
check_service_errors "JuanCash Client API" "juancash-clicent-api"
check_service_errors "JuanWord Shop Manager API" "juanword-api-shopmanager"

# APP Services (30)
echo "APP SERVICES (30)"
echo "========================================"
echo ""

# Admin apps
check_service_errors "JuanWorld Admin Settlement" "juanworld-admin-settlement"
check_service_errors "JuanWorld Admin Txorder" "juanworld-admin-txorder"
check_service_errors "JuanCash Admin Bank" "juancash-admin-bank"
check_service_errors "JuanCash Admin Finance" "juancash-admin-finance"
check_service_errors "JuanCash Admin Management" "juancash-admin-mgmt"
check_service_errors "JuanCash Admin Pay" "juancash-admin-pay"
check_service_errors "JuanCash Admin System" "juancash-admin-system"
check_service_errors "JuanCash Admin Txorder" "juancash-admin-txorder"
check_service_errors "JuanCash Admin Withdrawal" "juancash-admin-withdrawal"

# Scheduler apps
check_service_errors "JuanCash Scheduler Bank" "juancash-scheduler-bank"
check_service_errors "JuanCash Scheduler Pay" "juancash-scheduler-pay"
check_service_errors "JuanCash Scheduler System" "juancash-scheduler-system"
check_service_errors "JuanCash Scheduler Txorder" "juancash-scheduler-txorder"

# App apps
check_service_errors "JuanCash App Bank" "juancash-app-bank"
check_service_errors "JuanCash App Pay" "juancash-app-pay"
check_service_errors "JuanCash App System" "juancash-app-system"
check_service_errors "JuanCash App Txorder" "juancash-app-txorder"
check_service_errors "JuanCash App Withdrawal" "juancash-app-withdrawal"
check_service_errors "JuanCash App Merchant" "juancash-app-merchant"
check_service_errors "JuanWorld App Merchant" "juanworld-app-merchant"

# Open apps
check_service_errors "JuanCash Open Bank" "juancash-open-bank"
check_service_errors "JuanCash Open Pay" "juancash-open-pay"
check_service_errors "JuanCash Open System" "juancash-open-system"
check_service_errors "JuanCash Open Txorder" "juancash-open-txorder"

# Socket apps
check_service_errors "JuanCash Socket App" "juancash-socket-app"
check_service_errors "JuanCash Socket Merchant" "juancash-socket-merchant"

# Client apps
check_service_errors "JuanCash Client Finance" "juancash-client-finance"
check_service_errors "JuanCash Client Merchant" "juancash-client-merchant"
check_service_errors "JuanCash Client Settlement" "juancash-client-settlement"
check_service_errors "JuanCash Client Withdrawal" "juancash-client-withdrawal"

# Summary
echo "========================================"
echo "Summary"
echo "========================================"
echo ""
echo "Total services checked: 37 (7 API + 30 APP)"
echo "Search patterns: $ERROR_PATTERNS"
echo "Excluded patterns: $EXCLUDE_PATTERNS"
echo ""
echo "To investigate specific service:"
echo "  kubectl logs -n $NAMESPACE -l app=<deployment-name> --tail=$LINES --since=$SINCE"
echo ""
echo "To export full logs:"
echo "  kubectl logs -n $NAMESPACE -l app=<deployment-name> --tail=5000 > service.log"
echo ""
echo "Report completed: $(date)"
echo ""
