#!/bin/bash
# Forex Production Upgrade - Check GCR images and record current versions
# This script will:
# 1. Read current image versions from components/images/kustomization.yaml
# 2. Check if new upgrade images exist in GCR
# 3. Generate version comparison table

set -e

DEPLOY_DIR="/Users/user/FOREX-project/gitlab.axiom-infra.com/forex-prod-k8s-deploy"
WORKFLOW_DIR="/Users/user/CLAUDE/workflows/WF-20251229-1-forex-prod-upgrade"
UPGRADE_LIST="$WORKFLOW_DIR/data/new-versions/upgrade-list.txt"
CURRENT_VERSIONS="$WORKFLOW_DIR/data/backup/current-versions.txt"
VERSION_TABLE="$WORKFLOW_DIR/data/version-comparison-table.md"

GCR_REGISTRY="asia-east2-docker.pkg.dev"
GCR_PROJECT="uu-prod"
GCR_REPOSITORY="uu-prod/forex"

echo "=== Forex Production Upgrade Check ==="
echo ""

# Step 1: Read current versions from components/images/kustomization.yaml
echo "Step 1: Reading current production versions..."
IMAGES_FILE="$DEPLOY_DIR/components/images/kustomization.yaml"

if [ ! -f "$IMAGES_FILE" ]; then
    echo "Error: $IMAGES_FILE not found"
    exit 1
fi

mkdir -p "$WORKFLOW_DIR/data/backup"
echo "Current Production Image Versions" > "$CURRENT_VERSIONS"
echo "=================================" >> "$CURRENT_VERSIONS"
echo "Recorded at: $(date '+%Y-%m-%d %H:%M:%S')" >> "$CURRENT_VERSIONS"
echo "" >> "$CURRENT_VERSIONS"

# Parse kustomization.yaml to extract image versions
python3 << 'PYTHON_SCRIPT' >> "$CURRENT_VERSIONS"
import re

images_file = "/Users/user/FOREX-project/gitlab.axiom-infra.com/forex-prod-k8s-deploy/components/images/kustomization.yaml"

with open(images_file, 'r') as f:
    content = f.read()

# Find all image blocks
pattern = r'- name: asia-east2-docker\.pkg\.dev/uu-prod/uu-prod/forex/[^\n]+\n\s+newTag: [^\n]+'
matches = re.findall(pattern, content)

results = []
for match in matches:
    # Extract image name
    name_match = re.search(r'/([^/\n]+)$', match.split('\n')[0])
    if name_match:
        image_name = name_match.group(1)

    # Extract tag
    tag_match = re.search(r"newTag: ['\"]?(\d+)['\"]?", match)
    if tag_match:
        tag = tag_match.group(1)
        results.append(f"{image_name}: {tag}")

for line in sorted(results):
    print(line)
PYTHON_SCRIPT

echo "✓ Current versions recorded to: $CURRENT_VERSIONS"
echo ""

# Step 2: Check GCR images
echo "Step 2: Checking if upgrade images exist in GCR..."
echo ""

check_image() {
    local image_name="$1"
    local tag="$2"
    # Remove -rel or -production suffix to get service name
    local service_name=$(echo "$image_name" | sed 's/-rel$//' | sed 's/-production$//')
    local full_image="$GCR_REGISTRY/$GCR_PROJECT/$GCR_REPOSITORY/$service_name/$image_name:$tag"

    if gcloud artifacts docker images describe "$full_image" --format="value(image_summary.digest)" 2>/dev/null | grep -q "sha256:"; then
        echo "  ✓ $image_name:$tag - FOUND"
        return 0
    else
        echo "  ✗ $image_name:$tag - NOT FOUND"
        return 1
    fi
}

ALL_FOUND=true

echo "Backend Services:"
while IFS='#' read -r image_name tag; do
    # Skip empty lines and "Backend"/"Frontend" headers
    if [ -z "$image_name" ] || [ "$image_name" = "Backend" ] || [ "$image_name" = "Frontend" ]; then
        continue
    fi

    if ! check_image "$image_name" "$tag"; then
        ALL_FOUND=false
    fi
done < <(sed -n '/^Backend/,/^Frontend/p' "$UPGRADE_LIST" | grep '#')

echo ""
echo "Frontend Services:"
while IFS='#' read -r image_name tag; do
    # Skip empty lines and headers
    if [ -z "$image_name" ] || [ "$image_name" = "Backend" ] || [ "$image_name" = "Frontend" ]; then
        continue
    fi

    if ! check_image "$image_name" "$tag"; then
        ALL_FOUND=false
    fi
done < <(sed -n '/^Frontend/,$p' "$UPGRADE_LIST" | grep '#')

echo ""
if [ "$ALL_FOUND" = true ]; then
    echo "✓ All upgrade images found in GCR"
else
    echo "✗ Some images not found in GCR. Please check before proceeding."
    exit 1
fi

echo ""

# Step 3: Generate version comparison table
echo "Step 3: Generating version comparison table..."

cat > "$VERSION_TABLE" << 'EOF'
# Forex Production Upgrade - Version Comparison

## Backend Services

| Service | Current Version | New Version | Status |
|---------|----------------|-------------|--------|
EOF

# Function to get current version from current-versions.txt
get_current_version() {
    local service="$1"
    grep "^$service:" "$CURRENT_VERSIONS" | cut -d':' -f2 | tr -d ' ' || echo "N/A"
}

# Add backend services to table
while IFS='#' read -r image_name tag; do
    if [ -z "$image_name" ] || [ "$image_name" = "Backend" ] || [ "$image_name" = "Frontend" ]; then
        continue
    fi

    current_ver=$(get_current_version "$image_name")
    echo "| $image_name | $current_ver | $tag | ✓ |" >> "$VERSION_TABLE"
done < <(sed -n '/^Backend/,/^Frontend/p' "$UPGRADE_LIST" | grep '#')

cat >> "$VERSION_TABLE" << 'EOF'

## Frontend Services

| Service | Current Version | New Version | Status |
|---------|----------------|-------------|--------|
EOF

# Add frontend services to table
while IFS='#' read -r image_name tag; do
    if [ -z "$image_name" ] || [ "$image_name" = "Backend" ] || [ "$image_name" = "Frontend" ]; then
        continue
    fi

    current_ver=$(get_current_version "$image_name")
    echo "| $image_name | $current_ver | $tag | ✓ |" >> "$VERSION_TABLE"
done < <(sed -n '/^Frontend/,$p' "$UPGRADE_LIST" | grep '#')

echo "" >> "$VERSION_TABLE"
echo "---" >> "$VERSION_TABLE"
echo "" >> "$VERSION_TABLE"
echo "**Generated at:** $(date '+%Y-%m-%d %H:%M:%S')" >> "$VERSION_TABLE"

echo "✓ Version comparison table generated: $VERSION_TABLE"
echo ""

echo "=== Check Complete ==="
echo ""
echo "Summary:"
echo "  - Current versions: $CURRENT_VERSIONS"
echo "  - Version table: $VERSION_TABLE"
echo "  - All GCR images: ✓ Found"
echo ""
echo "Next steps:"
echo "  1. Review version comparison table"
echo "  2. Run backup-configs.sh to backup current configurations"
echo "  3. Run upgrade.sh to update image versions"
