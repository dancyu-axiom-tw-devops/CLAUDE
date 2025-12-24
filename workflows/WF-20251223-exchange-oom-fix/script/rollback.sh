#!/bin/bash
# rollback.sh
# Rollback exchange-service to previous configuration
# Usage: ./rollback.sh [backup_timestamp]
# Example: ./rollback.sh 20251223_135549

set -e

NAMESPACE="forex-prod"
APP="exchange-service"
HPA_NAME="exchange-service-hpa"
PROD_DIR="/Users/user/FOREX-project/prod-cloud/forex-prod-k8s-deploy/exchange-service"
WF_DIR="/Users/user/CLAUDE/docs/workflows/WF-20251223-exchange-oom-fix"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "======================================"
echo "Exchange Service OOM Fix - Rollback"
echo "======================================"
echo ""

# Check if backup timestamp provided
if [ -z "$1" ]; then
  echo "Available backups:"
  ls -1 "$WF_DIR/data/backup/" 2>/dev/null || echo "No backups found"
  echo ""
  echo -e "${YELLOW}Usage: $0 <backup_timestamp>${NC}"
  echo "Example: $0 20251223_135549"
  exit 1
fi

BACKUP_TIMESTAMP="$1"
BACKUP_DIR="$WF_DIR/data/backup/$BACKUP_TIMESTAMP"

# Validate backup directory
if [ ! -d "$BACKUP_DIR" ]; then
  echo -e "${RED}Error: Backup directory not found: $BACKUP_DIR${NC}"
  echo ""
  echo "Available backups:"
  ls -1 "$WF_DIR/data/backup/" 2>/dev/null || echo "No backups found"
  exit 1
fi

echo "Backup directory: $BACKUP_DIR"
echo ""
echo "Backup files:"
ls -1 "$BACKUP_DIR"
echo ""

# Confirmation
echo -e "${YELLOW}⚠️  WARNING: This will rollback exchange-service to the backup from $BACKUP_TIMESTAMP${NC}"
echo ""
echo "This will:"
echo "  1. Restore deployment.yml, env/forex.env, kustomization.yml"
echo "  2. Delete HPA (exchange-service-hpa)"
echo "  3. Apply the old configuration to the cluster"
echo "  4. Pod will rollback to 1 replica with old JVM settings"
echo ""
read -p "Are you sure you want to proceed? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
  echo "Rollback cancelled."
  exit 0
fi

echo ""
echo "======================================"
echo "Step 1: Create Current State Backup"
echo "======================================"

CURRENT_BACKUP_DIR="$WF_DIR/data/backup/before-rollback-$(date +%Y%m%d_%H%M%S)"
mkdir -p "$CURRENT_BACKUP_DIR"

cd "$PROD_DIR"
cp deployment.yml env/forex.env kustomization.yml "$CURRENT_BACKUP_DIR/" 2>/dev/null || true

echo "Current state backed up to: $CURRENT_BACKUP_DIR"
echo ""

echo "======================================"
echo "Step 2: Restore Configuration Files"
echo "======================================"

# Check required files
REQUIRED_FILES=("deployment.yml" "forex.env" "kustomization.yml")
for file in "${REQUIRED_FILES[@]}"; do
  if [ "$file" = "forex.env" ]; then
    SRC_FILE="$BACKUP_DIR/forex.env"
    DEST_FILE="$PROD_DIR/env/forex.env"
  else
    SRC_FILE="$BACKUP_DIR/$file"
    DEST_FILE="$PROD_DIR/$file"
  fi

  if [ ! -f "$SRC_FILE" ]; then
    echo -e "${RED}Error: Required file not found in backup: $SRC_FILE${NC}"
    exit 1
  fi

  echo "Restoring: $file"
  cp "$SRC_FILE" "$DEST_FILE"
done

echo -e "${GREEN}✅ Configuration files restored${NC}"
echo ""

echo "======================================"
echo "Step 3: Show Configuration Diff"
echo "======================================"

echo "--- deployment.yml changes ---"
diff "$CURRENT_BACKUP_DIR/deployment.yml" "$PROD_DIR/deployment.yml" || echo "(No diff tool available or files identical)"
echo ""

echo "--- env/forex.env changes ---"
diff "$CURRENT_BACKUP_DIR/forex.env" "$PROD_DIR/env/forex.env" || echo "(No diff tool available or files identical)"
echo ""

echo "======================================"
echo "Step 4: Apply Rollback to Cluster"
echo "======================================"

echo "Current kubectl context:"
kubectl config current-context
echo ""

read -p "Proceed with kubectl apply? (yes/no): " APPLY_CONFIRM
if [ "$APPLY_CONFIRM" != "yes" ]; then
  echo "Rollback cancelled. Files have been restored but NOT applied to cluster."
  exit 0
fi

# Apply configuration
cd "$PROD_DIR"
kubectl apply -k .

echo -e "${GREEN}✅ Configuration applied${NC}"
echo ""

echo "======================================"
echo "Step 5: Delete HPA"
echo "======================================"

HPA_EXISTS=$(kubectl get hpa $HPA_NAME -n $NAMESPACE --ignore-not-found 2>/dev/null)

if [ ! -z "$HPA_EXISTS" ]; then
  echo "Deleting HPA: $HPA_NAME"
  kubectl delete hpa $HPA_NAME -n $NAMESPACE

  echo -e "${GREEN}✅ HPA deleted${NC}"
else
  echo "HPA not found (already deleted or never existed)"
fi
echo ""

echo "======================================"
echo "Step 6: Wait for Rollout"
echo "======================================"

echo "Monitoring deployment rollout..."
kubectl rollout status deployment/$APP -n $NAMESPACE --timeout=300s

echo -e "${GREEN}✅ Rollout completed${NC}"
echo ""

echo "======================================"
echo "Step 7: Verify Rollback"
echo "======================================"

echo "--- Pod Status ---"
kubectl get pods -n $NAMESPACE -l app=$APP
echo ""

echo "--- Deployment Status ---"
kubectl get deployment $APP -n $NAMESPACE
echo ""

echo "--- HPA Status (should not exist) ---"
kubectl get hpa $HPA_NAME -n $NAMESPACE 2>&1 || echo "HPA not found (expected)"
echo ""

echo "--- Memory Usage ---"
kubectl top pods -n $NAMESPACE -l app=$APP 2>&1 || echo "Metrics not available"
echo ""

echo "======================================"
echo "Rollback Summary"
echo "======================================"

POD_COUNT=$(kubectl get pods -n $NAMESPACE -l app=$APP --no-headers 2>/dev/null | wc -l | xargs)
RUNNING_COUNT=$(kubectl get pods -n $NAMESPACE -l app=$APP --no-headers 2>/dev/null | grep -c "Running" || echo "0")

echo "Pod Count: $POD_COUNT"
echo "Running Pods: $RUNNING_COUNT"
echo "Rollback Backup: $BACKUP_DIR"
echo "Current State Backup: $CURRENT_BACKUP_DIR"
echo ""

if [ "$RUNNING_COUNT" -eq "$POD_COUNT" ] && [ "$POD_COUNT" -gt 0 ]; then
  echo -e "${GREEN}✅ Rollback completed successfully${NC}"
  echo ""
  echo "⚠️  Note: The service is now running with the old configuration:"
  echo "  - JVM: Xms 256m (frequent GC expected)"
  echo "  - No HPA (single replica, manual scaling required)"
  echo "  - No heap dump on OOM"
  echo ""
  echo "Monitor the service closely for OOM issues."
  exit 0
else
  echo -e "${RED}⚠️  Rollback completed but pods may not be healthy${NC}"
  echo "Please check pod logs and events for issues:"
  echo "  kubectl logs -n $NAMESPACE -l app=$APP --tail=100"
  echo "  kubectl describe pod -n $NAMESPACE -l app=$APP"
  exit 1
fi
