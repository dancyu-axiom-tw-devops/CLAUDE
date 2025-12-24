#!/bin/sh
# Backup current Waas2 production k8s deploy configs
# Usage: ./backup-configs.sh

set -e

DEPLOY_DIR="/Users/user/Waas2-project/gitlab.axiom-infra.com/waas2-tenant-k8s-deploy"
BACKUP_BASE="/Users/user/CLAUDE/workflows/WF-20251223-1-waas2-prod-upgrade/data/backup"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="$BACKUP_BASE/$TIMESTAMP"

echo "=== Waas2 Production Config Backup ==="
echo "Source: $DEPLOY_DIR"
echo "Destination: $BACKUP_DIR"
echo ""

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Services to backup
SERVICES="service-search service-exchange service-tron service-eth service-user service-admin"

echo "Backing up service configurations..."
for service in $SERVICES; do
  if [ -d "$DEPLOY_DIR/$service" ]; then
    echo "  - $service"
    cp -r "$DEPLOY_DIR/$service" "$BACKUP_DIR/"
  else
    echo "  ! $service not found"
  fi
done

# Backup git info
cd "$DEPLOY_DIR"
echo ""
echo "Recording git information..."
git log -1 --oneline > "$BACKUP_DIR/git-commit.txt" 2>&1 || echo "no git info" > "$BACKUP_DIR/git-commit.txt"
git branch --show-current > "$BACKUP_DIR/git-branch.txt" 2>&1 || echo "no branch" > "$BACKUP_DIR/git-branch.txt"
git status > "$BACKUP_DIR/git-status.txt" 2>&1 || echo "no git status" > "$BACKUP_DIR/git-status.txt"

echo ""
echo "Backup completed: $BACKUP_DIR"
ls -lh "$BACKUP_DIR" | tail -n +2
