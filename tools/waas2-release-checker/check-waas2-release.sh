#!/bin/bash
# check-waas2-release.sh
# Waas2 Release 鏡像檢查工具
# 用途：
#   1. 檢查 GCR 鏡像是否存在
#   2. 比對目前 prod 版本與新版本
#
# Usage: ./check-waas2-release.sh <release-file>

set -e

# ========================================
# Configuration
# ========================================

GCR_CREDENTIAL="${GCR_CREDENTIAL:-/Users/user/CLAUDE/credentials/gcr-juancash-prod.json}"
GCR_REGISTRY="asia-east2-docker.pkg.dev"
GCR_PROJECT="uu-prod"
GCR_REPOSITORY="waas-prod"
K8S_DEPLOY_DIR="/Users/user/Waas2-project/waas-tenant-prod/waas2-tenant-k8s-deploy"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# ========================================
# Functions
# ========================================

show_usage() {
    cat <<EOF
Waas2 Release 鏡像檢查工具

Usage: $0 <release-file>

Release File Format:
  Backend
  service-search-rel#60
  service-exchange-rel#8
  service-tron-rel#70

  Frontend
  service-admin-rel#82

Options:
  -h, --help     Show this help message

Output:
  1. 檢查 GCR 鏡像是否存在
  2. 比對目前 prod 版本與新版本

Example:
  $0 release-2025-12-23.txt

EOF
}

check_prerequisites() {
    # Check if gcloud is installed
    if ! command -v gcloud &> /dev/null; then
        echo -e "${RED}❌ Error: gcloud CLI not found${NC}"
        echo "Please install: brew install google-cloud-sdk"
        exit 1
    fi

    # Check if credential file exists
    if [ ! -f "$GCR_CREDENTIAL" ]; then
        echo -e "${RED}❌ Error: Credential file not found: $GCR_CREDENTIAL${NC}"
        exit 1
    fi

    # Check if k8s deploy directory exists
    if [ ! -d "$K8S_DEPLOY_DIR" ]; then
        echo -e "${RED}❌ Error: K8s deploy directory not found: $K8S_DEPLOY_DIR${NC}"
        exit 1
    fi

    echo -e "${BLUE}🔐 Authenticating with GCR...${NC}"
    gcloud auth activate-service-account --key-file="$GCR_CREDENTIAL" --quiet 2>&1 | grep -v "Activated" || true
    gcloud auth configure-docker "$GCR_REGISTRY" --quiet 2>&1 | grep -v "added to" || true
    echo ""
}

get_current_version() {
    local service_name="$1"
    local service_dir=""
    local gcr_image_name="$service_name"

    # Map service name to directory and GCR image name
    case "$service_name" in
        service-search-rel)
            service_dir="service-search"
            ;;
        service-exchange-rel)
            service_dir="service-exchange"
            ;;
        service-tron-rel)
            service_dir="service-tron"
            gcr_image_name="service-tron-v2-rel"  # Special: GCR uses v2
            ;;
        service-eth-rel)
            service_dir="service-eth"
            ;;
        service-user-rel)
            service_dir="service-user"
            ;;
        service-waas-admin-rel|service-admin-rel)
            service_dir="service-admin"
            gcr_image_name="service-waas-admin-rel"  # Special: GCR uses waas-admin
            ;;
        service-api-rel)
            service_dir="service-api"
            ;;
        service-gateway-rel)
            service_dir="service-gateway"
            gcr_image_name="gateway-service-rel"  # Special: GCR name reversed
            ;;
        service-notice-rel)
            service_dir="service-notice"
            ;;
        service-pol-rel)
            service_dir="service-pol"
            ;;
        service-setting-rel)
            service_dir="service-setting"
            ;;
        *)
            echo "unknown"
            return
            ;;
    esac

    local kustomize_file="$K8S_DEPLOY_DIR/$service_dir/kustomization.yml"

    if [ ! -f "$kustomize_file" ]; then
        echo "unknown"
        return
    fi

    # Extract version from kustomization.yml
    # Look for the actual GCR image name in kustomization.yml
    local version=$(grep -A 1 "name:.*$gcr_image_name" "$kustomize_file" | grep "newTag:" | awk -F"'" '{print $2}')

    if [ -z "$version" ]; then
        echo "unknown"
    else
        echo "$version"
    fi
}

check_image_exists() {
    local image_name="$1"
    local tag="$2"
    local gcr_image_name="$image_name"

    # Special handling for service-tron-rel: check both old (v2) and new names
    if [ "$image_name" == "service-tron-rel" ]; then
        # Try new name first (service-tron-rel)
        local full_image="$GCR_REGISTRY/$GCR_PROJECT/$GCR_REPOSITORY/$image_name:$tag"
        if gcloud artifacts docker images describe "$full_image" --format="value(image_summary.digest)" 2>/dev/null | grep -q "sha256:"; then
            return 0
        fi

        # Try old name (service-tron-v2-rel)
        local full_image_v2="$GCR_REGISTRY/$GCR_PROJECT/$GCR_REPOSITORY/service-tron-v2-rel:$tag"
        if gcloud artifacts docker images describe "$full_image_v2" --format="value(image_summary.digest)" 2>/dev/null | grep -q "sha256:"; then
            return 0
        fi

        return 1
    fi

    # Map to actual GCR image name if needed
    case "$image_name" in
        service-admin-rel)
            gcr_image_name="service-waas-admin-rel"
            ;;
        service-gateway-rel)
            gcr_image_name="gateway-service-rel"
            ;;
    esac

    local full_image="$GCR_REGISTRY/$GCR_PROJECT/$GCR_REPOSITORY/$gcr_image_name:$tag"

    # Try to describe the image with specific tag
    # If it exists, the command succeeds; if not, it fails
    if gcloud artifacts docker images describe "$full_image" --format="value(image_summary.digest)" 2>/dev/null | grep -q "sha256:"; then
        return 0
    else
        return 1
    fi
}

parse_release_file() {
    local file="$1"
    local category=""

    while IFS= read -r line; do
        # Skip empty lines
        [ -z "$line" ] && continue

        # Check if it's a category header
        if [[ "$line" == "Backend" ]] || [[ "$line" == "Frontend" ]]; then
            category="$line"
            continue
        fi

        # Skip if no category set yet
        [ -z "$category" ] && continue

        # Parse service line: service-name-rel#version
        if [[ "$line" =~ ^([a-z-]+)#([0-9]+)$ ]]; then
            local service="${BASH_REMATCH[1]}"
            local new_version="${BASH_REMATCH[2]}"

            echo "$category|$service|$new_version"
        fi
    done < "$file"
}

# ========================================
# Parse Arguments
# ========================================

if [ $# -eq 0 ]; then
    show_usage
    exit 1
fi

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            RELEASE_FILE="$1"
            shift
            ;;
    esac
done

# ========================================
# Main
# ========================================

echo "========================================"
echo "Waas2 Release 鏡像檢查"
echo "========================================"
echo ""
echo "Registry: $GCR_REGISTRY"
echo "Project:  $GCR_PROJECT"
echo "Repository: $GCR_REPOSITORY"
echo ""

# Check prerequisites
check_prerequisites

# Validate input
if [ ! -f "$RELEASE_FILE" ]; then
    echo -e "${RED}❌ Error: Release file not found: $RELEASE_FILE${NC}"
    exit 1
fi

echo -e "${CYAN}📋 Release File: $RELEASE_FILE${NC}"
echo ""

# Parse release file
SERVICES=$(parse_release_file "$RELEASE_FILE")

if [ -z "$SERVICES" ]; then
    echo -e "${YELLOW}⚠️  No services found in release file${NC}"
    exit 0
fi

# Display summary
echo "========================================"
echo "📊 Release Summary"
echo "========================================"
echo ""

BACKEND_COUNT=0
FRONTEND_COUNT=0

while IFS='|' read -r category service new_version; do
    if [ "$category" == "Backend" ]; then
        BACKEND_COUNT=$((BACKEND_COUNT + 1))
    else
        FRONTEND_COUNT=$((FRONTEND_COUNT + 1))
    fi
done <<< "$SERVICES"

echo "Backend Services:  $BACKEND_COUNT"
echo "Frontend Services: $FRONTEND_COUNT"
echo "Total:             $((BACKEND_COUNT + FRONTEND_COUNT))"
echo ""

# Check each service
echo "========================================"
echo "🔍 檢查鏡像與版本比對"
echo "========================================"
echo ""

TOTAL=0
FOUND=0
MISSING=0
UPGRADED=0
SAME=0

while IFS='|' read -r category service new_version; do
    TOTAL=$((TOTAL + 1))

    # Get current version
    current_version=$(get_current_version "$service")

    # Display header
    echo -e "${BLUE}[$TOTAL] $category - $service${NC}"
    echo "    New Version:     #$new_version"
    echo "    Current Version: #$current_version"

    # Check if image exists in GCR
    if check_image_exists "$service" "$new_version"; then
        FOUND=$((FOUND + 1))
        echo -e "    GCR Image:       ${GREEN}✅ FOUND${NC}"
    else
        MISSING=$((MISSING + 1))
        echo -e "    GCR Image:       ${RED}❌ NOT FOUND${NC}"
    fi

    # Compare versions
    if [ "$current_version" == "unknown" ]; then
        echo -e "    Version Change:  ${YELLOW}⚠️  Current version unknown${NC}"
    elif [ "$new_version" == "$current_version" ]; then
        SAME=$((SAME + 1))
        echo -e "    Version Change:  ${YELLOW}➡️  Same (no change)${NC}"
    else
        UPGRADED=$((UPGRADED + 1))
        echo -e "    Version Change:  ${CYAN}🔄  Change (#$current_version → #$new_version)${NC}"
    fi

    echo ""
done <<< "$SERVICES"

# Final Summary
echo "========================================"
echo "📊 Final Summary"
echo "========================================"
echo ""
echo "GCR Image Status:"
echo -e "  ${GREEN}Found:   $FOUND${NC}"
echo -e "  ${RED}Missing: $MISSING${NC}"
echo ""
echo "Version Comparison:"
echo -e "  ${GREEN}Upgraded: $UPGRADED${NC}"
echo -e "  ${YELLOW}Same:     $SAME${NC}"
echo ""

# Exit status
if [ $MISSING -gt 0 ]; then
    echo -e "${RED}⚠️  Warning: Some images are missing in GCR!${NC}"
    echo "Please build and push missing images before deployment."
    echo ""
    exit 1
else
    echo -e "${GREEN}✅ All images found in GCR!${NC}"

    if [ $UPGRADED -gt 0 ]; then
        echo -e "${GREEN}✅ $UPGRADED service(s) will be upgraded.${NC}"
    fi

    if [ $SAME -gt 0 ]; then
        echo -e "${YELLOW}ℹ️  $SAME service(s) have the same version (no change).${NC}"
    fi

    echo ""
    echo "Ready for deployment!"
    exit 0
fi
