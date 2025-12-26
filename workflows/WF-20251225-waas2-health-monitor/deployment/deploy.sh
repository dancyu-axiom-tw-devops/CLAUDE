#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
NAMESPACE="waas2-prod"

echo "Deploying Waas2 Health Monitor to ${NAMESPACE}..."
echo ""

# Check if secret exists
if ! kubectl get secret waas2-health-monitor-secret -n ${NAMESPACE} &>/dev/null; then
    echo "Creating secret..."
    kubectl apply -f "${SCRIPT_DIR}/secret-template.yml"
else
    echo "Secret already exists, skipping..."
fi

# Apply CronJob and RBAC
echo "Applying CronJob and RBAC..."
kubectl apply -f "${SCRIPT_DIR}/cronjob.yml"

echo ""
echo "Deployment complete!"
echo ""
echo "To check status:"
echo "  kubectl get cronjob waas2-health-monitor -n ${NAMESPACE}"
echo "  kubectl get pods -n ${NAMESPACE} -l app=waas2-health-monitor"
echo ""
echo "To trigger manual run:"
echo "  kubectl create job --from=cronjob/waas2-health-monitor manual-run-\$(date +%s) -n ${NAMESPACE}"
echo ""
echo "To view reports:"
echo "  kubectl exec -it -n ${NAMESPACE} deployment/service-admin -- ls -la /9duu/service-admin/logs/"
