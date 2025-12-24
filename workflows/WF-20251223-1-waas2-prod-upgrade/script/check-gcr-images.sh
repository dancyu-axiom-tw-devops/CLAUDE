#!/bin/sh
# Check GCR images for Waas2 production upgrade
# Usage: ./check-gcr-images.sh

set -e

GCR_CREDENTIAL="/Users/user/CLAUDE/credentials/gcr-juancash-prod.json"
GCR_REGISTRY="asia-east2-docker.pkg.dev"
GCR_PROJECT="uu-prod"
GCR_REPOSITORY="waas-prod"

echo "=== GCR Image Check for Waas2 Production Upgrade ==="
echo ""

# Authenticate
echo "Authenticating with GCR..."
gcloud auth activate-service-account --key-file="$GCR_CREDENTIAL" --quiet 2>&1 | grep -v "Activated" || true
gcloud auth configure-docker "$GCR_REGISTRY" --quiet 2>&1 | grep -v "added to" || true
echo ""

# Images to check
echo "Checking upgrade images..."
echo ""

check_image() {
  local image_name="$1"
  local tag="$2"
  local full_image="$GCR_REGISTRY/$GCR_PROJECT/$GCR_REPOSITORY/$image_name:$tag"

  if gcloud artifacts docker images describe "$full_image" --format="value(image_summary.digest)" 2>/dev/null | grep -q "sha256:"; then
    echo "  $image_name:$tag - FOUND"
    return 0
  else
    echo "  $image_name:$tag - NOT FOUND"
    return 1
  fi
}

MISSING=0

# Backend
echo "[Backend]"
check_image "service-search-rel" "6" || MISSING=$((MISSING + 1))
check_image "service-exchange-rel" "8" || MISSING=$((MISSING + 1))
check_image "service-tron-rel" "4" || MISSING=$((MISSING + 1))
check_image "service-eth-rel" "2" || MISSING=$((MISSING + 1))
check_image "service-user-rel" "1" || MISSING=$((MISSING + 1))

echo ""
echo "[Frontend]"
check_image "service-waas-admin-rel" "1" || MISSING=$((MISSING + 1))

echo ""
echo "========================================="
if [ $MISSING -eq 0 ]; then
  echo "Result: All images found in GCR"
  exit 0
else
  echo "Result: $MISSING image(s) NOT FOUND"
  exit 1
fi
