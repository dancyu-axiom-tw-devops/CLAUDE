#!/bin/bash
# Apply Solution B configuration
# This script copies the modified configuration and applies it to the cluster

set -e

WF_DIR="/Users/user/CLAUDE/docs/workflows/WF-20251223-kafka-oom-fix"
KAFKA_DIR="/Users/user/FOREX-project/hkidc-k8s-gitlab/forex-stg/forex-stage-k8s-deploy/kafka-cluster"

echo "======================================"
echo "Apply Solution B Configuration"
echo "======================================"
echo ""

# Step 1: Backup current configuration (if not already done)
echo "Step 1: Creating timestamped backup..."
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="$WF_DIR/data/backup/$TIMESTAMP"
mkdir -p "$BACKUP_DIR"

cp "$KAFKA_DIR/statefulset.yml" "$BACKUP_DIR/" || echo "Warning: Could not backup statefulset.yml"
cp "$KAFKA_DIR/env/forex.env" "$BACKUP_DIR/" || echo "Warning: Could not backup forex.env"
echo "✅ Backup saved to: $BACKUP_DIR"
echo ""

# Step 2: Copy Solution B configuration
echo "Step 2: Copying Solution B configuration..."
cp "$WF_DIR/data/solution-b/statefulset.yml" "$KAFKA_DIR/"
cp "$WF_DIR/data/solution-b/forex.env" "$KAFKA_DIR/env/"
echo "✅ Configuration files copied"
echo ""

# Step 3: Show differences
echo "Step 3: Configuration changes:"
echo ""
echo "=== KAFKA_HEAP_OPTS changes ==="
echo "OLD: $(grep KAFKA_HEAP_OPTS "$BACKUP_DIR/forex.env" 2>/dev/null || echo "N/A")"
echo "NEW: $(grep KAFKA_HEAP_OPTS "$KAFKA_DIR/env/forex.env")"
echo ""
echo "=== Memory Limit changes ==="
echo "OLD: $(grep -A2 "limits:" "$BACKUP_DIR/statefulset.yml" 2>/dev/null | grep memory || echo "N/A")"
echo "NEW: $(grep -A2 "limits:" "$KAFKA_DIR/statefulset.yml" | grep memory)"
echo ""

# Step 4: Confirmation
read -p "Apply these changes to forex-stg cluster? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled. Rolling back copied files..."
    cp "$BACKUP_DIR/statefulset.yml" "$KAFKA_DIR/" 2>/dev/null || true
    cp "$BACKUP_DIR/forex.env" "$KAFKA_DIR/env/" 2>/dev/null || true
    echo "Rollback complete"
    exit 0
fi

# Step 5: Apply with Kustomize
echo ""
echo "Step 4: Applying configuration with Kustomize..."
cd "$KAFKA_DIR"

# Build and show what will be applied
echo "Preview of changes:"
kustomize build . | kubectl diff -f - || echo "(diff may show changes or errors if resources don't exist)"
echo ""

read -p "Proceed with kubectl apply? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled"
    exit 0
fi

# Apply
kustomize build . | kubectl apply -f -

echo ""
echo "✅ Configuration applied successfully!"
echo ""

# Step 6: Monitor Pod restart
echo "Step 5: Monitoring Pod restart..."
echo "Waiting for Pod to restart with new configuration..."
echo ""

# Wait for Pod to be terminating
sleep 5

# Watch Pod status
kubectl -n forex-stg get pod kafka-0 -w &
WATCH_PID=$!

# Wait up to 5 minutes for Pod to be Running again
TIMEOUT=300
ELAPSED=0
while [ $ELAPSED -lt $TIMEOUT ]; do
    POD_STATUS=$(kubectl -n forex-stg get pod kafka-0 -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")
    POD_READY=$(kubectl -n forex-stg get pod kafka-0 -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "False")

    if [ "$POD_STATUS" = "Running" ] && [ "$POD_READY" = "True" ]; then
        echo ""
        echo "✅ Pod is Running and Ready!"
        kill $WATCH_PID 2>/dev/null || true
        break
    fi

    sleep 5
    ELAPSED=$((ELAPSED + 5))
done

if [ $ELAPSED -ge $TIMEOUT ]; then
    echo ""
    echo "⚠️  Timeout waiting for Pod to be Ready"
    kill $WATCH_PID 2>/dev/null || true
fi

echo ""
echo "======================================"
echo "Deployment Summary"
echo "======================================"

# Final status
kubectl -n forex-stg get pod kafka-0
echo ""

# Resource configuration
echo "Resource Configuration:"
kubectl -n forex-stg get pod kafka-0 -o jsonpath='{.spec.containers[0].resources}' | jq .
echo ""

# Memory usage
echo "Current Memory Usage:"
kubectl -n forex-stg top pod kafka-0 || echo "Metrics not available"
echo ""

echo "======================================"
echo "Next Steps"
echo "======================================"
echo "1. Verify JVM parameters (may need to exec from a pod in the cluster):"
echo "   kubectl -n forex-stg exec kafka-0 -- ps aux | grep java | grep Xmx"
echo ""
echo "2. Run verification script:"
echo "   cd $WF_DIR/script"
echo "   ./verify-deployment.sh"
echo ""
echo "3. Monitor for 24 hours:"
echo "   ./monitor-memory.sh 300 1440"
echo ""

# Save deployment record
DEPLOY_LOG="$WF_DIR/data/deployment-history.log"
echo "$TIMESTAMP | Solution B applied | Backup: $BACKUP_DIR" >> "$DEPLOY_LOG"
echo "Deployment logged to: $DEPLOY_LOG"
