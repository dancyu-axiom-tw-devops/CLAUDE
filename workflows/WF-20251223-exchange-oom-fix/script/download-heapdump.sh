#!/bin/bash
# download-heapdump.sh
# Download heap dump from NAS to local machine
# Usage: ./download-heapdump.sh [filename]
# Example: ./download-heapdump.sh java_pid1.hprof

NAMESPACE="forex-prod"
APP="exchange-service"
HEAP_DUMP_DIR="/forex/log/exchange-service"
LOCAL_DIR="$(dirname "$0")/../data"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo "======================================"
echo "Heap Dump Download"
echo "======================================"
echo ""

# Get a running pod
POD_NAME=$(kubectl get pods -n $NAMESPACE -l app=$APP -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ -z "$POD_NAME" ]; then
  echo -e "${RED}❌ No running pod found${NC}"
  exit 1
fi

# List available heap dumps if no filename provided
if [ -z "$1" ]; then
  echo "Available heap dumps on NAS:"
  echo ""
  kubectl exec -n $NAMESPACE $POD_NAME -- \
    ls -lht $HEAP_DUMP_DIR/*.hprof 2>/dev/null || echo "No heap dumps found"
  echo ""
  echo -e "${YELLOW}Usage: $0 <filename>${NC}"
  echo "Example: $0 java_pid1.hprof"
  exit 1
fi

FILENAME="$1"
REMOTE_PATH="$HEAP_DUMP_DIR/$FILENAME"

# Check if file exists
echo "Checking if heap dump exists..."
kubectl exec -n $NAMESPACE $POD_NAME -- \
  ls -lh $REMOTE_PATH 2>/dev/null

if [ $? -ne 0 ]; then
  echo -e "${RED}❌ File not found: $REMOTE_PATH${NC}"
  echo ""
  echo "Available files:"
  kubectl exec -n $NAMESPACE $POD_NAME -- \
    ls -1 $HEAP_DUMP_DIR/*.hprof 2>/dev/null || echo "No heap dumps found"
  exit 1
fi

# Get file size
FILE_SIZE=$(kubectl exec -n $NAMESPACE $POD_NAME -- \
  ls -lh $REMOTE_PATH 2>/dev/null | awk '{print $5}')

echo ""
echo "File: $FILENAME"
echo "Size: $FILE_SIZE"
echo "Pod: $POD_NAME"
echo ""

# Confirm download
echo -e "${YELLOW}⚠️  This may take several minutes for large files${NC}"
read -p "Proceed with download? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
  echo "Download cancelled"
  exit 0
fi

# Create local directory
mkdir -p "$LOCAL_DIR"

# Generate local filename with timestamp
LOCAL_FILENAME="heap-dump-$(date +%Y%m%d_%H%M%S).hprof"
LOCAL_PATH="$LOCAL_DIR/$LOCAL_FILENAME"

# Download
echo ""
echo "Downloading..."
echo "  From: $NAMESPACE/$POD_NAME:$REMOTE_PATH"
echo "  To:   $LOCAL_PATH"
echo ""

kubectl cp "$NAMESPACE/$POD_NAME:$REMOTE_PATH" "$LOCAL_PATH"

if [ $? -eq 0 ]; then
  echo ""
  echo -e "${GREEN}✅ Download completed successfully${NC}"
  echo ""
  echo "Local file:"
  ls -lh "$LOCAL_PATH"
  echo ""
  echo "Next steps:"
  echo "  1. Analyze with Eclipse MAT:"
  echo "     Download: https://eclipse.dev/mat/downloads.php"
  echo "     Open: File → Open Heap Dump → Select $LOCAL_PATH"
  echo ""
  echo "  2. Or analyze with jhat:"
  echo "     jhat -J-Xmx4g \"$LOCAL_PATH\""
  echo "     Then open: http://localhost:7000"
  echo ""
  echo "  3. Or analyze with VisualVM:"
  echo "     jvisualvm"
  echo "     File → Load → Select $LOCAL_PATH"
else
  echo -e "${RED}❌ Download failed${NC}"
  exit 1
fi
