#!/bin/bash
# cleanup-heapdumps.sh
# Clean up old heap dumps from NAS, keep only recent ones

NAMESPACE="forex-prod"
APP="exchange-service"
HEAP_DUMP_DIR="/forex/log/exchange-service"
KEEP_COUNT=3  # Keep 3 most recent heap dumps

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "======================================"
echo "Heap Dump Cleanup"
echo "======================================"
echo ""

# Get a running pod
POD_NAME=$(kubectl get pods -n $NAMESPACE -l app=$APP -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ -z "$POD_NAME" ]; then
  echo "❌ No running pod found"
  exit 1
fi

echo "Using pod: $POD_NAME"
echo "Directory: $HEAP_DUMP_DIR"
echo "Keep count: $KEEP_COUNT"
echo ""

# List all heap dumps
echo "Existing heap dumps:"
kubectl exec -n $NAMESPACE $POD_NAME -- \
  ls -lht $HEAP_DUMP_DIR/*.hprof 2>/dev/null || echo "No heap dumps found"

echo ""

# Count heap dumps
HEAP_DUMP_COUNT=$(kubectl exec -n $NAMESPACE $POD_NAME -- \
  ls -1 $HEAP_DUMP_DIR/*.hprof 2>/dev/null | wc -l | xargs)

if [ -z "$HEAP_DUMP_COUNT" ] || [ "$HEAP_DUMP_COUNT" -eq 0 ]; then
  echo "✅ No heap dumps to clean"
  exit 0
fi

echo "Total heap dumps: $HEAP_DUMP_COUNT"

if [ "$HEAP_DUMP_COUNT" -le "$KEEP_COUNT" ]; then
  echo "✅ Heap dump count ($HEAP_DUMP_COUNT) <= keep count ($KEEP_COUNT), no cleanup needed"
  exit 0
fi

# Calculate how many to delete
DELETE_COUNT=$((HEAP_DUMP_COUNT - KEEP_COUNT))
echo -e "${YELLOW}Will delete $DELETE_COUNT old heap dump(s), keeping $KEEP_COUNT most recent${NC}"
echo ""

# Show which files will be deleted
echo "Files to be deleted:"
kubectl exec -n $NAMESPACE $POD_NAME -- \
  bash -c "cd $HEAP_DUMP_DIR && ls -1t *.hprof | tail -n +$((KEEP_COUNT + 1))"

echo ""
read -p "Proceed with deletion? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
  echo "Cleanup cancelled"
  exit 0
fi

# Delete old heap dumps
echo "Deleting old heap dumps..."
kubectl exec -n $NAMESPACE $POD_NAME -- \
  bash -c "cd $HEAP_DUMP_DIR && ls -1t *.hprof | tail -n +$((KEEP_COUNT + 1)) | xargs rm -f"

echo -e "${GREEN}✅ Cleanup completed${NC}"
echo ""

# Show remaining files
echo "Remaining heap dumps:"
kubectl exec -n $NAMESPACE $POD_NAME -- \
  ls -lht $HEAP_DUMP_DIR/*.hprof 2>/dev/null || echo "No heap dumps"

# Show disk usage
echo ""
echo "Disk usage:"
kubectl exec -n $NAMESPACE $POD_NAME -- \
  du -sh $HEAP_DUMP_DIR
