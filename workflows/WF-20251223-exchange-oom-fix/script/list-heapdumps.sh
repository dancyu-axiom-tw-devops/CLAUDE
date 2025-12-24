#!/bin/bash
# list-heapdumps.sh
# List all heap dumps stored on NAS with details

NAMESPACE="forex-prod"
APP="exchange-service"
HEAP_DUMP_DIR="/forex/log/exchange-service"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo "======================================"
echo "Heap Dump Inventory"
echo "======================================"
echo ""

# Get a running pod
POD_NAME=$(kubectl get pods -n $NAMESPACE -l app=$APP -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ -z "$POD_NAME" ]; then
  echo -e "${RED}❌ No running pod found${NC}"
  exit 1
fi

echo "Querying via pod: $POD_NAME"
echo "NAS location: $HEAP_DUMP_DIR"
echo ""

# List heap dumps
HEAP_DUMPS=$(kubectl exec -n $NAMESPACE $POD_NAME -- \
  ls -lht $HEAP_DUMP_DIR/*.hprof 2>/dev/null || echo "")

if [ -z "$HEAP_DUMPS" ]; then
  echo -e "${GREEN}✅ No heap dumps found (good - no OOM events)${NC}"
  exit 0
fi

# Display heap dumps
echo "Heap Dumps on NAS:"
echo "─────────────────────────────────────────────────────────────────"
echo "$HEAP_DUMPS"
echo "─────────────────────────────────────────────────────────────────"
echo ""

# Count and total size
HEAP_DUMP_COUNT=$(echo "$HEAP_DUMPS" | wc -l | xargs)
TOTAL_SIZE=$(kubectl exec -n $NAMESPACE $POD_NAME -- \
  du -sh $HEAP_DUMP_DIR 2>/dev/null | awk '{print $1}')

echo "Summary:"
echo "  Total heap dumps: $HEAP_DUMP_COUNT"
echo "  Total disk usage: $TOTAL_SIZE"
echo ""

# Show OOM events correlation
echo "Recent OOM Events:"
OOM_EVENTS=$(kubectl get events -n $NAMESPACE \
  --field-selector reason=OOMKilling \
  --sort-by='.lastTimestamp' 2>/dev/null | grep $APP | tail -5)

if [ -z "$OOM_EVENTS" ]; then
  echo "  No OOMKilled events in recent history"
else
  echo "$OOM_EVENTS"
fi
echo ""

# Download instructions
echo -e "${YELLOW}To download a heap dump:${NC}"
echo "  kubectl cp $NAMESPACE/$POD_NAME:$HEAP_DUMP_DIR/<filename>.hprof ./heap-dump.hprof"
echo ""

# Cleanup recommendation
if [ "$HEAP_DUMP_COUNT" -gt 3 ]; then
  echo -e "${YELLOW}⚠️  Recommendation: $HEAP_DUMP_COUNT heap dumps found${NC}"
  echo "  Consider cleaning up old dumps to save disk space:"
  echo "  ./cleanup-heapdumps.sh"
  echo ""
fi

# Analysis tools
echo "Analysis Tools:"
echo "  - Eclipse MAT: https://eclipse.dev/mat/downloads.php"
echo "  - VisualVM: https://visualvm.github.io/"
echo "  - jhat: jhat -J-Xmx4g heap-dump.hprof"
