#!/bin/bash
# Deploy axiom-gaming.tech SSL certificate to hkidc-k8s cluster
# Created: 2025-12-26

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLUSTER_CONTEXT="tp-hkidc-k8s"

echo "=== Deploying axiom-gaming.tech SSL Certificate ==="
echo ""

# Check if kubectl is configured for the correct cluster
CURRENT_CONTEXT=$(kubectl config current-context)
if [ "$CURRENT_CONTEXT" != "$CLUSTER_CONTEXT" ]; then
    echo "Warning: Current context is '$CURRENT_CONTEXT', expected '$CLUSTER_CONTEXT'"
    echo "Switching to $CLUSTER_CONTEXT..."
    kubectl config use-context $CLUSTER_CONTEXT
fi

echo "Step 1: Creating Cloudflare API Token Secret..."
kubectl apply -f "${SCRIPT_DIR}/secret-cloudflare-axiom-gaming.yaml"

echo ""
echo "Step 2: Creating ClusterIssuer and Certificate..."
kubectl apply -f "${SCRIPT_DIR}/axiom-gaming.tech.yaml"

echo ""
echo "Step 3: Checking Certificate status..."
sleep 5
kubectl get certificate axiom-gaming.tech -n default

echo ""
echo "=== Deployment Complete ==="
echo ""
echo "To check certificate details:"
echo "  kubectl describe certificate axiom-gaming.tech -n default"
echo ""
echo "To check certificate secret:"
echo "  kubectl get secret axiom-gaming.tech -n default"
echo ""
echo "To check ClusterIssuer:"
echo "  kubectl describe clusterissuer cloudflare-dns-axiom-gaming.tech"
