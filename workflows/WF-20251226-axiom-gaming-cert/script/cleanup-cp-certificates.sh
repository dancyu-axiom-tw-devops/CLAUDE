#!/bin/bash
# Cleanup cp-*.vip certificates and ClusterIssuers
# These certificates no longer have YAML configs in the repo
# Created: 2025-12-26

set -e

echo "=== Cleanup cp-*.vip Certificates ==="
echo ""

CLUSTER_CONTEXT="tp-hkidc-k8s"
CURRENT_CONTEXT=$(kubectl config current-context)

if [ "$CURRENT_CONTEXT" != "$CLUSTER_CONTEXT" ]; then
    echo "Warning: Current context is '$CURRENT_CONTEXT', expected '$CLUSTER_CONTEXT'"
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo "This will delete:"
echo "  Certificates:"
echo "    - cp-dev.vip (namespace: cp-dev)"
echo "    - cp-rel.vip (namespace: cp-rel)"
echo "    - cp-stage.vip (namespace: cp-stg)"
echo ""
echo "  ClusterIssuers:"
echo "    - alidns-cp-dev.vip"
echo "    - alidns-cp-rel.vip"
echo "    - alidns-cp-stage.vip"
echo ""
read -p "Are you sure? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

echo ""
echo "Step 1: Deleting Certificates..."
kubectl delete certificate cp-dev.vip -n cp-dev --ignore-not-found=true
kubectl delete certificate cp-rel.vip -n cp-rel --ignore-not-found=true
kubectl delete certificate cp-stage.vip -n cp-stg --ignore-not-found=true

echo ""
echo "Step 2: Deleting ClusterIssuers..."
kubectl delete clusterissuer alidns-cp-dev.vip --ignore-not-found=true
kubectl delete clusterissuer alidns-cp-rel.vip --ignore-not-found=true
kubectl delete clusterissuer alidns-cp-stage.vip --ignore-not-found=true

echo ""
echo "Step 3: Verifying cleanup..."
echo ""
echo "Remaining cp-* Certificates:"
kubectl get certificate -A | grep "cp-" || echo "  None"
echo ""
echo "Remaining cp-* ClusterIssuers:"
kubectl get clusterissuer | grep "cp-" || echo "  None"

echo ""
echo "=== Cleanup Complete ==="
echo ""
echo "Note: Certificate Secrets are NOT deleted automatically."
echo "To delete secrets manually:"
echo "  kubectl delete secret cp-dev.vip -n cp-dev"
echo "  kubectl delete secret cp-rel.vip -n cp-rel"
echo "  kubectl delete secret cp-stage.vip -n cp-stg"
