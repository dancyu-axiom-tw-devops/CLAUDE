#!/bin/sh
# Quick rollback script for Waas2 production upgrade
# Usage: ./rollback.sh [backup-timestamp]

set -e

DEPLOY_DIR="/Users/user/Waas2-project/gitlab.axiom-infra.com/waas2-tenant-k8s-deploy"
BACKUP_BASE="/Users/user/CLAUDE/workflows/WF-20251223-1-waas2-prod-upgrade/data/backup"

# If no timestamp provided, use the latest backup
if [ -z "$1" ]; then
  BACKUP_DIR=$(ls -td "$BACKUP_BASE"/2* 2>/dev/null | head -1)
  if [ -z "$BACKUP_DIR" ]; then
    echo "Error: No backup found in $BACKUP_BASE"
    exit 1
  fi
else
  BACKUP_DIR="$BACKUP_BASE/$1"
  if [ ! -d "$BACKUP_DIR" ]; then
    echo "Error: Backup directory not found: $BACKUP_DIR"
    exit 1
  fi
fi

echo "=== Waas2 Production Rollback ==="
echo "Backup source: $BACKUP_DIR"
echo "Deploy target: $DEPLOY_DIR"
echo ""

# Show backup info
if [ -f "$BACKUP_DIR/git-commit.txt" ]; then
  echo "Backup commit:"
  cat "$BACKUP_DIR/git-commit.txt"
  echo ""
fi

# Confirm rollback
echo "WARNING: This will restore configurations to the backup state."
echo "Press Enter to continue or Ctrl+C to cancel..."
read dummy

# Services to restore
SERVICES="service-search service-exchange service-tron service-eth service-user service-admin"

echo ""
echo "Restoring service configurations..."
for service in $SERVICES; do
  if [ -d "$BACKUP_DIR/$service" ]; then
    echo "  - $service"
    cp -r "$BACKUP_DIR/$service/"* "$DEPLOY_DIR/$service/" 2>/dev/null || echo "    Warning: Some files may not exist"
  else
    echo "  ! $service backup not found"
  fi
done

echo ""
echo "=== Rollback completed ==="
echo ""
echo "Next steps:"
echo "1. Review changes: cd $DEPLOY_DIR && git diff"
echo "2. Apply to cluster: cd $DEPLOY_DIR && kubectl apply -k service-xxx/"
echo "3. Or use upgrade script with --dry-run first"
