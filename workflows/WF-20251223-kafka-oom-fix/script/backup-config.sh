#!/bin/bash
# Backup Kafka configuration files
# Usage: ./backup-config.sh

set -e

KAFKA_DIR="/Users/user/FOREX-project/hkidc-k8s-gitlab/forex-stg/forex-stage-k8s-deploy/kafka-cluster"
BACKUP_DIR="/Users/user/CLAUDE/docs/workflows/WF-20251223-kafka-oom-fix/data/backup"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo "Backing up Kafka configuration files..."
echo "Source: $KAFKA_DIR"
echo "Destination: $BACKUP_DIR"
echo "Timestamp: $TIMESTAMP"

# Create timestamped backup directory
mkdir -p "$BACKUP_DIR/$TIMESTAMP"

# Backup key configuration files
cp "$KAFKA_DIR/statefulset.yml" "$BACKUP_DIR/$TIMESTAMP/"
cp "$KAFKA_DIR/env/forex.env" "$BACKUP_DIR/$TIMESTAMP/"
cp "$KAFKA_DIR/kustomization.yml" "$BACKUP_DIR/$TIMESTAMP/"

echo "Backup completed successfully!"
echo "Files backed up to: $BACKUP_DIR/$TIMESTAMP"
