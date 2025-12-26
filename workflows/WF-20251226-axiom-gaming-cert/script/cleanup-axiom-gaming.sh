#!/bin/bash
# Remove axiom-gaming.tech SSL certificate from hkidc-k8s cluster
# Created: 2025-12-26

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLUSTER_CONTEXT="tp-hkidc-k8s"

echo "=== Removing axiom-gaming.tech SSL Certificate ==="
echo ""

# Check if kubectl is configured for the correct cluster
CURRENT_CONTEXT=$(kubectl config current-context)
if [ "$CURRENT_CONTEXT" != "$CLUSTER_CONTEXT" ]; then
    echo "Warning: Current context is '$CURRENT_CONTEXT', expected '$CLUSTER_CONTEXT'"
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo "This will remove:"
echo "  - Certificate: axiom-gaming.tech (namespace: default)"
echo "  - ClusterIssuer: cloudflare-dns-axiom-gaming.tech"
echo "  - Secret: cloudflare-api-token-secret-axiom-gaming (namespace: cert-manager)"
echo ""
read -p "Are you sure? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

echo ""
echo "Step 1: Removing Certificate..."
kubectl delete -f "${SCRIPT_DIR}/axiom-gaming.tech.yaml" --ignore-not-found=true

echo ""
echo "Step 2: Removing Cloudflare API Token Secret..."
kubectl delete -f "${SCRIPT_DIR}/secret-cloudflare-axiom-gaming.yaml" --ignore-not-found=true

echo ""
echo "Step 3: Checking remaining resources..."
kubectl get certificate axiom-gaming.tech -n default 2>/dev/null || echo "Certificate removed"
kubectl get clusterissuer cloudflare-dns-axiom-gaming.tech 2>/dev/null || echo "ClusterIssuer removed"

echo ""
echo "=== Cleanup Complete ==="
