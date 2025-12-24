#!/bin/bash
# Forex Production GCR Cleanup Script
# This script will delete old unused images from GCR
# Keeps: current production versions + new upgrade versions

set -e

WORKFLOW_DIR="/Users/user/CLAUDE/workflows/WF-20251223-2-forex-prod-upgrade"
CURRENT_VERSIONS="$WORKFLOW_DIR/data/backup/current-versions.txt"
UPGRADE_LIST="$WORKFLOW_DIR/data/new-versions/upgrade-list.txt"

GCR_REGISTRY="asia-east2-docker.pkg.dev"
GCR_PROJECT="uu-prod"
GCR_REPOSITORY="uu-prod/forex"

# Parse arguments
DRY_RUN=true
TEST_SERVICE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --apply)
            DRY_RUN=false
            shift
            ;;
        --test)
            TEST_SERVICE="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--apply] [--test service-name]"
            echo "  --apply: Actually delete images (default is dry-run)"
            echo "  --test service-name: Test on a single service first"
            exit 1
            ;;
    esac
done

echo "=== Forex Production GCR Cleanup ==="
echo ""

if [ "$DRY_RUN" = true ]; then
    echo "MODE: DRY RUN (no images will be deleted)"
else
    echo "MODE: APPLY (images will be deleted)"
fi

if [ -n "$TEST_SERVICE" ]; then
    echo "TEST MODE: Only processing $TEST_SERVICE"
fi
echo ""

# Function to get current version
get_current_version() {
    local service="$1"
    grep "^$service:" "$CURRENT_VERSIONS" 2>/dev/null | cut -d':' -f2 | tr -d ' ' || echo ""
}

# Function to get new version
get_new_version() {
    local service="$1"
    grep "^$service#" "$UPGRADE_LIST" 2>/dev/null | cut -d'#' -f2 || echo ""
}

# Function to clean up a single service
cleanup_service() {
    local image_name="$1"
    local current_ver="$2"
    local new_ver="$3"

    # Remove -rel or -production suffix to get service directory
    local service_dir=$(echo "$image_name" | sed 's/-rel$//' | sed 's/-production$//')
    local full_path="$GCR_REGISTRY/$GCR_PROJECT/$GCR_REPOSITORY/$service_dir/$image_name"

    echo "Processing: $image_name"
    echo "  Current version: ${current_ver:-N/A}"
    echo "  New version: ${new_ver:-N/A}"

    # Get all tags for this image
    local all_tags=$(gcloud artifacts docker tags list "$full_path" --format="value(tag)" 2>/dev/null | sort -n)

    if [ -z "$all_tags" ]; then
        echo "  No tags found, skipping"
        echo ""
        return
    fi

    local total_tags=$(echo "$all_tags" | wc -l | tr -d ' ')
    echo "  Total tags: $total_tags"

    # New strategy: Only delete tags LESS than current version
    # Keep: current version and all versions >= current version

    if [ -z "$current_ver" ]; then
        echo "  No current version found, skipping cleanup (new service)"
        echo ""
        return
    fi

    echo "  Strategy: Keep version $current_ver and all versions >= $current_ver"

    # Find tags to delete (only those < current_ver)
    local delete_count=0
    local delete_tags=()

    for tag in $all_tags; do
        # Only delete if tag is numeric and less than current version
        if [[ "$tag" =~ ^[0-9]+$ ]] && [ "$tag" -lt "$current_ver" ]; then
            delete_tags+=("$tag")
            ((delete_count++))
        fi
    done

    echo "  Tags to delete: $delete_count"

    if [ $delete_count -eq 0 ]; then
        echo "  ✓ No cleanup needed"
        echo ""
        return
    fi

    # Show first few tags that will be deleted
    if [ $delete_count -le 5 ]; then
        echo "  Will delete tags: ${delete_tags[*]}"
    else
        echo "  Will delete tags: ${delete_tags[@]:0:3} ... and $((delete_count-3)) more"
    fi

    if [ "$DRY_RUN" = true ]; then
        echo "  [DRY RUN] Would delete $delete_count tags"
    else
        echo "  Deleting $delete_count tags..."
        for tag in "${delete_tags[@]}"; do
            echo "    Deleting tag: $tag"
            gcloud artifacts docker images delete "${full_path}:${tag}" --quiet 2>&1 | grep -v "Deleted" || true
        done
        echo "  ✓ Deleted $delete_count tags"
    fi

    echo ""
}

# Main cleanup logic
if [ -n "$TEST_SERVICE" ]; then
    # Test mode: only process one service
    current_ver=$(get_current_version "$TEST_SERVICE")
    new_ver=$(get_new_version "$TEST_SERVICE")
    cleanup_service "$TEST_SERVICE" "$current_ver" "$new_ver"
else
    # Process all services from upgrade list
    echo "Processing all services from upgrade list..."
    echo ""

    # Backend services
    while IFS='#' read -r image_name tag; do
        if [ -z "$image_name" ] || [ "$image_name" = "Backend" ] || [ "$image_name" = "Frontend" ]; then
            continue
        fi

        current_ver=$(get_current_version "$image_name")
        new_ver="$tag"
        cleanup_service "$image_name" "$current_ver" "$new_ver"
    done < <(sed -n '/^Backend/,/^Frontend/p' "$UPGRADE_LIST" | grep '#')

    # Frontend services
    while IFS='#' read -r image_name tag; do
        if [ -z "$image_name" ] || [ "$image_name" = "Backend" ] || [ "$image_name" = "Frontend" ]; then
            continue
        fi

        current_ver=$(get_current_version "$image_name")
        new_ver="$tag"
        cleanup_service "$image_name" "$current_ver" "$new_ver"
    done < <(sed -n '/^Frontend/,$p' "$UPGRADE_LIST" | grep '#')
fi

echo "=== Cleanup Complete ==="
echo ""

if [ "$DRY_RUN" = true ]; then
    echo "This was a DRY RUN. No images were deleted."
    echo "To actually delete images, run with --apply flag"
else
    echo "Cleanup completed successfully."
fi

if [ -n "$TEST_SERVICE" ]; then
    echo ""
    echo "This was a TEST run on $TEST_SERVICE only."
    echo "To clean all services, run without --test flag"
fi
