#!/bin/bash
# backup-config.sh
# Create timestamped backup of exchange-service configuration

PROD_DIR="/Users/user/FOREX-project/prod-cloud/forex-prod-k8s-deploy/exchange-service"
WF_DIR="/Users/user/CLAUDE/docs/workflows/WF-20251223-exchange-oom-fix"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="$WF_DIR/data/backup/$TIMESTAMP"

GREEN='\033[0;32m'
NC='\033[0m'

echo "======================================"
echo "Exchange Service Config Backup"
echo "======================================"
echo ""

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Backup files
cd "$PROD_DIR"

FILES_TO_BACKUP=(
  "deployment.yml"
  "env/forex.env"
  "kustomization.yml"
)

echo "Backing up configuration files..."
for file in "${FILES_TO_BACKUP[@]}"; do
  if [ -f "$file" ]; then
    cp "$file" "$BACKUP_DIR/"
    echo "✅ Backed up: $file"
  else
    echo "⚠️  File not found (skipping): $file"
  fi
done

# Save current cluster state (if kubectl is available)
if command -v kubectl &> /dev/null; then
  echo ""
  echo "Saving current cluster state..."

  NAMESPACE="forex-prod"
  APP="exchange-service"

  kubectl get deployment $APP -n $NAMESPACE -o yaml > "$BACKUP_DIR/deployment-cluster.yaml" 2>/dev/null && echo "✅ Saved deployment state" || echo "⚠️  Could not save deployment state"
  kubectl get hpa exchange-service-hpa -n $NAMESPACE -o yaml > "$BACKUP_DIR/hpa-cluster.yaml" 2>/dev/null && echo "✅ Saved HPA state" || echo "⚠️  HPA not found (may not exist)"
  kubectl get pods -n $NAMESPACE -l app=$APP -o wide > "$BACKUP_DIR/pods-state.txt" 2>/dev/null && echo "✅ Saved pod state" || echo "⚠️  Could not save pod state"
fi

echo ""
echo -e "${GREEN}✅ Backup completed${NC}"
echo "Backup directory: $BACKUP_DIR"
echo ""
echo "Backup contents:"
ls -lh "$BACKUP_DIR"
