#!/bin/bash
# check-gcr-images.sh
# 檢查 GCR (Google Container Registry) 中的 image 是否存在
# Usage: ./check-gcr-images.sh <image-list-file>

set -e

# ========================================
# Configuration
# ========================================

GCR_CREDENTIAL="${GCR_CREDENTIAL:-/Users/user/CLAUDE/credentials/gcr-juancash-prod.json}"
GCR_REGISTRY="${GCR_REGISTRY:-asia-east2-docker.pkg.dev}"
GCR_PROJECT="${GCR_PROJECT:-uu-prod}"
GCR_REPOSITORY="${GCR_REPOSITORY:-juancash-prod}"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# ========================================
# Functions
# ========================================

show_usage() {
    cat <<EOF
Usage: $0 [OPTIONS] <image-list-file>

Options:
  -c, --credential PATH    GCR service account JSON (default: $GCR_CREDENTIAL)
  -r, --registry HOST      GCR registry host (default: $GCR_REGISTRY)
  -p, --project ID         GCP project ID (default: $GCR_PROJECT)
  -R, --repository NAME    Repository name (default: $GCR_REPOSITORY)
  -h, --help              Show this help message

Image List File Format:
  One image per line in format: <image-name>:<tag>
  Example:
    juanworld-api-rel:v1.2.3
    juancash-open-api-rel:v2.0.1
    juancash-app-bank-rel:latest

  Or use full path:
    asia-east2-docker.pkg.dev/uu-prod/juancash-prod/juanworld-api-rel:v1.2.3

Examples:
  # Check images from file
  $0 release-images.txt

  # Use custom credential
  $0 -c /path/to/cred.json release-images.txt

  # Check single image (stdin)
  echo "juanworld-api-rel:v1.2.3" | $0 -

EOF
}

check_prerequisites() {
    # Check if gcloud is installed
    if ! command -v gcloud &> /dev/null; then
        echo -e "${RED}❌ Error: gcloud CLI not found${NC}"
        echo "Please install: https://cloud.google.com/sdk/docs/install"
        exit 1
    fi

    # Check if credential file exists
    if [ ! -f "$GCR_CREDENTIAL" ]; then
        echo -e "${RED}❌ Error: Credential file not found: $GCR_CREDENTIAL${NC}"
        exit 1
    fi

    echo -e "${BLUE}🔐 Authenticating with GCR...${NC}"
    gcloud auth activate-service-account --key-file="$GCR_CREDENTIAL" --quiet 2>&1 | grep -v "Activated service account" || true

    echo -e "${BLUE}🔧 Configuring Docker for GCR...${NC}"
    gcloud auth configure-docker "$GCR_REGISTRY" --quiet 2>&1 | grep -v "added to" || true

    echo ""
}

normalize_image_name() {
    local image="$1"

    # If already full path, return as is
    if [[ "$image" == *"$GCR_REGISTRY"* ]]; then
        echo "$image"
        return
    fi

    # Build full path
    echo "$GCR_REGISTRY/$GCR_PROJECT/$GCR_REPOSITORY/$image"
}

check_image_exists() {
    local image="$1"
    local full_image=$(normalize_image_name "$image")

    # Extract image name and tag
    local image_name="${full_image%:*}"
    local tag="${full_image##*:}"

    # Use gcloud to list tags and check if exists
    if gcloud artifacts docker images list "$image_name" \
        --filter="tags:$tag" \
        --format="value(package)" \
        --limit=1 2>/dev/null | grep -q .; then
        return 0
    else
        return 1
    fi
}

get_image_details() {
    local image="$1"
    local full_image=$(normalize_image_name "$image")

    gcloud artifacts docker images describe "$full_image" \
        --format="table(
            image_summary.digest.short(),
            image_summary.upload_time.date('%Y-%m-%d %H:%M:%S'),
            image_summary.media_type
        )" 2>/dev/null || echo "N/A"
}

# ========================================
# Parse Arguments
# ========================================

while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--credential)
            GCR_CREDENTIAL="$2"
            shift 2
            ;;
        -r|--registry)
            GCR_REGISTRY="$2"
            shift 2
            ;;
        -p|--project)
            GCR_PROJECT="$2"
            shift 2
            ;;
        -R|--repository)
            GCR_REPOSITORY="$2"
            shift 2
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            IMAGE_LIST_FILE="$1"
            shift
            ;;
    esac
done

# ========================================
# Main
# ========================================

echo "========================================"
echo "GCR Image Checker"
echo "========================================"
echo ""
echo "Registry: $GCR_REGISTRY"
echo "Project:  $GCR_PROJECT"
echo "Repository: $GCR_REPOSITORY"
echo ""

# Check prerequisites
check_prerequisites

# Validate input
if [ -z "$IMAGE_LIST_FILE" ]; then
    echo -e "${RED}❌ Error: No image list file provided${NC}"
    echo ""
    show_usage
    exit 1
fi

# Read from stdin or file
if [ "$IMAGE_LIST_FILE" == "-" ]; then
    IMAGE_LIST=$(cat)
elif [ ! -f "$IMAGE_LIST_FILE" ]; then
    echo -e "${RED}❌ Error: File not found: $IMAGE_LIST_FILE${NC}"
    exit 1
else
    IMAGE_LIST=$(cat "$IMAGE_LIST_FILE")
fi

# Filter out comments and empty lines
IMAGE_LIST=$(echo "$IMAGE_LIST" | grep -v '^#' | grep -v '^$')

if [ -z "$IMAGE_LIST" ]; then
    echo -e "${YELLOW}⚠️  No images to check${NC}"
    exit 0
fi

# Check images
echo -e "${BLUE}🔍 Checking images...${NC}"
echo ""

TOTAL=0
FOUND=0
MISSING=0

while IFS= read -r image; do
    # Skip empty lines
    [ -z "$image" ] && continue

    TOTAL=$((TOTAL + 1))

    echo -e "${BLUE}[$TOTAL] Checking: ${NC}$image"

    if check_image_exists "$image"; then
        FOUND=$((FOUND + 1))
        echo -e "    ${GREEN}✅ FOUND${NC}"

        # Get image details (optional, can be slow for many images)
        # details=$(get_image_details "$image")
        # echo "$details" | sed 's/^/    /'
    else
        MISSING=$((MISSING + 1))
        echo -e "    ${RED}❌ NOT FOUND${NC}"
    fi

    echo ""
done <<< "$IMAGE_LIST"

# Summary
echo "========================================"
echo -e "${BLUE}📊 Summary${NC}"
echo "========================================"
echo "Total images checked: $TOTAL"
echo -e "${GREEN}Found:   $FOUND${NC}"
echo -e "${RED}Missing: $MISSING${NC}"
echo ""

if [ $MISSING -gt 0 ]; then
    echo -e "${RED}⚠️  Some images are missing in GCR!${NC}"
    echo "Please build and push missing images before deployment."
    exit 1
else
    echo -e "${GREEN}✅ All images found in GCR!${NC}"
    echo "Ready for deployment."
    exit 0
fi
