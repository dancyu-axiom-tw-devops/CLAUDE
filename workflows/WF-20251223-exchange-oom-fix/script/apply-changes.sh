#!/bin/bash
# apply-changes.sh
# Apply OOM fix configuration to production cluster with safety checks

set -e

PROD_DIR="/Users/user/FOREX-project/prod-cloud/forex-prod-k8s-deploy/exchange-service"
WF_DIR="/Users/user/CLAUDE/docs/workflows/WF-20251223-exchange-oom-fix"

NAMESPACE="forex-prod"
APP="exchange-service"
HPA_NAME="exchange-service-hpa"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "======================================"
echo "Exchange Service OOM Fix - Deployment"
echo "======================================"
echo ""

# Step 1: Pre-deployment checks
echo "======================================"
echo "Step 1: Pre-Deployment Checks"
echo "======================================"

# Check kubectl context
CURRENT_CONTEXT=$(kubectl config current-context 2>&1 || echo "ERROR")
if [ "$CURRENT_CONTEXT" = "ERROR" ]; then
  echo -e "${RED}❌ Error: kubectl not configured${NC}"
  exit 1
fi

echo "kubectl context: $CURRENT_CONTEXT"
echo ""

# Confirm correct cluster
read -p "Is this the correct cluster for forex-prod? (yes/no): " CONFIRM_CLUSTER
if [ "$CONFIRM_CLUSTER" != "yes" ]; then
  echo "Deployment cancelled. Please switch to the correct kubectl context."
  exit 0
fi

# Check cluster connectivity
echo "Testing cluster connectivity..."
kubectl get nodes > /dev/null 2>&1
if [ $? -ne 0 ]; then
  echo -e "${RED}❌ Error: Cannot connect to cluster${NC}"
  exit 1
fi
echo -e "${GREEN}✅ Cluster connectivity OK${NC}"
echo ""

# Check Metrics Server
echo "Checking Metrics Server..."
METRICS_SERVER=$(kubectl get deployment metrics-server -n kube-system --ignore-not-found 2>/dev/null)
if [ -z "$METRICS_SERVER" ]; then
  echo -e "${YELLOW}⚠️  WARNING: Metrics Server not found${NC}"
  echo "   HPA will not be able to auto-scale based on metrics"
  echo ""
  read -p "Continue anyway? (yes/no): " CONTINUE_WITHOUT_METRICS
  if [ "$CONTINUE_WITHOUT_METRICS" != "yes" ]; then
    echo "Deployment cancelled."
    exit 0
  fi
else
  echo -e "${GREEN}✅ Metrics Server found${NC}"
  kubectl top nodes > /dev/null 2>&1
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Metrics Server working${NC}"
  else
    echo -e "${YELLOW}⚠️  WARNING: Metrics Server exists but not returning data${NC}"
  fi
fi
echo ""

# Check current pod status
echo "Current pod status:"
kubectl get pods -n $NAMESPACE -l app=$APP
echo ""

# Step 2: Create backup
echo "======================================"
echo "Step 2: Create Backup"
echo "======================================"

BACKUP_SCRIPT="$WF_DIR/script/backup-config.sh"
if [ -x "$BACKUP_SCRIPT" ]; then
  $BACKUP_SCRIPT
else
  echo "Backup script not found or not executable, creating manual backup..."
  TIMESTAMP=$(date +%Y%m%d_%H%M%S)
  BACKUP_DIR="$WF_DIR/data/backup/$TIMESTAMP"
  mkdir -p "$BACKUP_DIR"
  cd "$PROD_DIR"
  cp deployment.yml env/forex.env kustomization.yml "$BACKUP_DIR/" 2>/dev/null || true
  echo "Backup created: $BACKUP_DIR"
fi
echo ""

# Step 3: Review changes
echo "======================================"
echo "Step 3: Review Configuration Changes"
echo "======================================"

cd "$PROD_DIR"

echo "Key changes:"
echo "  1. Deployment: replicas 1 → 2, add RollingUpdate strategy"
echo "  2. JVM: Xms 256m → 3072m, enable G1GC, add heap dump"
echo "  3. HPA: Create new HPA (min 2, max 10)"
echo ""

# Show diff if possible
echo "--- deployment.yml diff ---"
git diff deployment.yml 2>/dev/null || echo "(git diff not available)"
echo ""

echo "--- env/forex.env diff ---"
git diff env/forex.env 2>/dev/null || echo "(git diff not available)"
echo ""

# Step 4: Final confirmation
echo "======================================"
echo "Step 4: Final Confirmation"
echo "======================================"

echo -e "${YELLOW}⚠️  This deployment will:${NC}"
echo "  - Trigger a rolling update (existing pods will restart)"
echo "  - Change replica count to 2"
echo "  - Create HPA (auto-scaling enabled)"
echo "  - Modify JVM parameters (Xms, GC algorithm)"
echo ""
echo "Estimated downtime: 0 (RollingUpdate with maxUnavailable:0)"
echo "Estimated completion: 3-5 minutes"
echo ""

read -p "Proceed with deployment? (yes/no): " FINAL_CONFIRM
if [ "$FINAL_CONFIRM" != "yes" ]; then
  echo "Deployment cancelled."
  exit 0
fi

# Step 5: Apply configuration
echo ""
echo "======================================"
echo "Step 5: Applying Configuration"
echo "======================================"

cd "$PROD_DIR"

echo "Running: kubectl apply -k ."
kubectl apply -k .

if [ $? -eq 0 ]; then
  echo -e "${GREEN}✅ Configuration applied${NC}"
else
  echo -e "${RED}❌ Error applying configuration${NC}"
  exit 1
fi
echo ""

# Step 6: Monitor rollout
echo "======================================"
echo "Step 6: Monitoring Rollout"
echo "======================================"

echo "Watching deployment rollout..."
echo "(Press Ctrl+C if needed, rollout will continue)"
echo ""

kubectl rollout status deployment/$APP -n $NAMESPACE --timeout=600s &
ROLLOUT_PID=$!

# Also watch pods in parallel
(
  sleep 2
  echo ""
  echo "Pod status updates:"
  kubectl get pods -n $NAMESPACE -l app=$APP -w
) &
WATCH_PID=$!

# Wait for rollout
wait $ROLLOUT_PID
ROLLOUT_EXIT=$?

# Stop watch
kill $WATCH_PID 2>/dev/null || true

if [ $ROLLOUT_EXIT -eq 0 ]; then
  echo -e "${GREEN}✅ Rollout completed successfully${NC}"
else
  echo -e "${RED}⚠️  Rollout may have issues (exit code: $ROLLOUT_EXIT)${NC}"
fi
echo ""

# Step 7: Verification
echo "======================================"
echo "Step 7: Post-Deployment Verification"
echo "======================================"

VERIFY_SCRIPT="$WF_DIR/script/verify-deployment.sh"
if [ -x "$VERIFY_SCRIPT" ]; then
  echo "Running automated verification..."
  echo ""
  $VERIFY_SCRIPT
else
  echo "Verification script not found, performing manual checks..."
  echo ""

  echo "--- Pod Status ---"
  kubectl get pods -n $NAMESPACE -l app=$APP
  echo ""

  echo "--- Deployment Status ---"
  kubectl get deployment $APP -n $NAMESPACE
  echo ""

  echo "--- HPA Status ---"
  kubectl get hpa $HPA_NAME -n $NAMESPACE
  echo ""

  echo "--- Memory Usage ---"
  kubectl top pods -n $NAMESPACE -l app=$APP 2>&1 || echo "Metrics not available"
  echo ""
fi

# Step 8: Summary
echo "======================================"
echo "Deployment Summary"
echo "======================================"

POD_COUNT=$(kubectl get pods -n $NAMESPACE -l app=$APP --no-headers 2>/dev/null | wc -l | xargs)
RUNNING_COUNT=$(kubectl get pods -n $NAMESPACE -l app=$APP --no-headers 2>/dev/null | grep -c "Running" || echo "0")

echo "Pod Count: $POD_COUNT"
echo "Running Pods: $RUNNING_COUNT"
echo "Deployment Time: $(date)"
echo ""

if [ "$RUNNING_COUNT" -eq 2 ]; then
  echo -e "${GREEN}✅ Deployment completed successfully${NC}"
  echo ""
  echo "Next steps:"
  echo "  1. Monitor for 1 hour: $WF_DIR/script/monitor-resources.sh 300 12"
  echo "  2. Check for OOM events: kubectl get events -n $NAMESPACE --field-selector reason=OOMKilling"
  echo "  3. Review GC logs (after a few minutes of runtime)"
  echo ""
  echo "Rollback if needed: $WF_DIR/script/rollback.sh <backup_timestamp>"
  exit 0
else
  echo -e "${YELLOW}⚠️  WARNING: Not all pods are running${NC}"
  echo "Please investigate:"
  echo "  kubectl logs -n $NAMESPACE -l app=$APP --tail=100"
  echo "  kubectl describe pod -n $NAMESPACE -l app=$APP"
  echo ""
  echo "Rollback if needed: $WF_DIR/script/rollback.sh <backup_timestamp>"
  exit 1
fi
