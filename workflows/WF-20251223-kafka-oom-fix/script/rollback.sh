#!/bin/bash
# Rollback Kafka configuration to backup
# Usage: ./rollback.sh [backup_timestamp]

set -e

KAFKA_DIR="/Users/user/FOREX-project/hkidc-k8s-gitlab/forex-stg/forex-stage-k8s-deploy/kafka-cluster"
BACKUP_DIR="/Users/user/CLAUDE/docs/workflows/WF-20251223-kafka-oom-fix/data/backup"

if [ -z "$1" ]; then
    echo "Error: Please specify backup timestamp"
    echo "Usage: ./rollback.sh [backup_timestamp]"
    echo ""
    echo "Available backups:"
    ls -1 "$BACKUP_DIR" | grep -E "^[0-9]{8}_[0-9]{6}$" || echo "No timestamped backups found"
    exit 1
fi

BACKUP_TIMESTAMP="$1"
BACKUP_PATH="$BACKUP_DIR/$BACKUP_TIMESTAMP"

if [ ! -d "$BACKUP_PATH" ]; then
    echo "Error: Backup not found: $BACKUP_PATH"
    exit 1
fi

echo "Rolling back Kafka configuration..."
echo "Backup source: $BACKUP_PATH"
echo "Target: $KAFKA_DIR"
echo ""
read -p "Continue with rollback? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Rollback cancelled"
    exit 0
fi

# Restore configuration files
cp "$BACKUP_PATH/statefulset.yml" "$KAFKA_DIR/"
cp "$BACKUP_PATH/forex.env" "$KAFKA_DIR/env/"

echo "Rollback completed successfully!"
echo ""
echo "Next steps:"
echo "1. cd $KAFKA_DIR"
echo "2. kustomize build . | kubectl apply -f -"
echo "3. kubectl -n forex-stg get pods -w"
