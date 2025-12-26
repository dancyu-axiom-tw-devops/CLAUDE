#!/bin/bash
# check-services.sh
# Check if all jc-refactor services are running
# Usage: ./check-services.sh

NAMESPACE="jc-prod"

echo "========================================"
echo "JC-Refactor Services Status Check"
echo "========================================"
echo ""
echo "Namespace: $NAMESPACE"
echo "Timestamp: $(date)"
echo ""

# Function to check service status
check_service() {
    local service_name=$1
    local deployment_name=$2

    echo "=== $service_name ==="

    # Check if deployment exists
    if ! kubectl get deployment $deployment_name -n $NAMESPACE &>/dev/null; then
        echo "Status: DEPLOYMENT NOT FOUND"
        echo ""
        return
    fi

    # Get deployment info
    DESIRED=$(kubectl get deployment $deployment_name -n $NAMESPACE -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
    READY=$(kubectl get deployment $deployment_name -n $NAMESPACE -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    AVAILABLE=$(kubectl get deployment $deployment_name -n $NAMESPACE -o jsonpath='{.status.availableReplicas}' 2>/dev/null || echo "0")

    # Get pod info
    POD_COUNT=$(kubectl get pods -n $NAMESPACE -l app=$deployment_name 2>/dev/null | grep -c "Running" || echo "0")

    # Status determination
    if [ "$POD_COUNT" -eq 0 ]; then
        echo "Status: NO RUNNING PODS"
    elif [ "$READY" -eq "$DESIRED" ]; then
        echo "Status: OK - $READY/$DESIRED pods ready"
    else
        echo "Status: DEGRADED - $READY/$DESIRED pods ready"
    fi

    # Show pod details
    kubectl get pods -n $NAMESPACE -l app=$deployment_name --no-headers 2>/dev/null | while read line; do
        POD_NAME=$(echo $line | awk '{print $1}')
        POD_STATUS=$(echo $line | awk '{print $3}')
        RESTARTS=$(echo $line | awk '{print $4}')
        echo "  Pod: $POD_NAME | Status: $POD_STATUS | Restarts: $RESTARTS"
    done

    echo ""
}

# API Services (7)
echo "API SERVICES (7)"
echo "========================================"
echo ""

check_service "JuanWorld API" "juanworld-api"
check_service "JuanWorld Admin API" "juanworld-admin-api"
check_service "JuanCash Open API" "juancash-open-api"
check_service "JuanCash Bank API" "juancash-bank-api"
check_service "JuanCash Applet API" "juancash-applet-api"
check_service "JuanCash Client API" "juancash-clicent-api"
check_service "JuanWord Shop Manager API" "juanword-api-shopmanager"

# APP Services (30)
echo "APP SERVICES (30)"
echo "========================================"
echo ""

# Admin apps
check_service "JuanWorld Admin Settlement" "juanworld-admin-settlement"
check_service "JuanWorld Admin Txorder" "juanworld-admin-txorder"
check_service "JuanCash Admin Bank" "juancash-admin-bank"
check_service "JuanCash Admin Finance" "juancash-admin-finance"
check_service "JuanCash Admin Management" "juancash-admin-mgmt"
check_service "JuanCash Admin Pay" "juancash-admin-pay"
check_service "JuanCash Admin System" "juancash-admin-system"
check_service "JuanCash Admin Txorder" "juancash-admin-txorder"
check_service "JuanCash Admin Withdrawal" "juancash-admin-withdrawal"

# Scheduler apps
check_service "JuanCash Scheduler Bank" "juancash-scheduler-bank"
check_service "JuanCash Scheduler Pay" "juancash-scheduler-pay"
check_service "JuanCash Scheduler System" "juancash-scheduler-system"
check_service "JuanCash Scheduler Txorder" "juancash-scheduler-txorder"

# App apps
check_service "JuanCash App Bank" "juancash-app-bank"
check_service "JuanCash App Pay" "juancash-app-pay"
check_service "JuanCash App System" "juancash-app-system"
check_service "JuanCash App Txorder" "juancash-app-txorder"
check_service "JuanCash App Withdrawal" "juancash-app-withdrawal"
check_service "JuanCash App Merchant" "juancash-app-merchant"
check_service "JuanWorld App Merchant" "juanworld-app-merchant"

# Open apps
check_service "JuanCash Open Bank" "juancash-open-bank"
check_service "JuanCash Open Pay" "juancash-open-pay"
check_service "JuanCash Open System" "juancash-open-system"
check_service "JuanCash Open Txorder" "juancash-open-txorder"

# Socket apps
check_service "JuanCash Socket App" "juancash-socket-app"
check_service "JuanCash Socket Merchant" "juancash-socket-merchant"

# Client apps
check_service "JuanCash Client Finance" "juancash-client-finance"
check_service "JuanCash Client Merchant" "juancash-client-merchant"
check_service "JuanCash Client Settlement" "juancash-client-settlement"
check_service "JuanCash Client Withdrawal" "juancash-client-withdrawal"

# Summary
echo "========================================"
echo "Summary"
echo "========================================"
echo ""
echo "Total services checked: 37 (7 API + 30 APP)"
echo "Report generated: $(date)"
echo ""
