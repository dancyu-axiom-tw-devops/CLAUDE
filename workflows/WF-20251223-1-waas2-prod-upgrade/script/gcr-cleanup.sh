#!/bin/sh
# Clean up old GCR images (keep current prod + new upgrade versions only)
# Usage: ./gcr-cleanup.sh [--dry-run]

set -e

GCR_CREDENTIAL="/Users/user/CLAUDE/credentials/gcr-juancash-prod.json"
GCR_REGISTRY="asia-east2-docker.pkg.dev"
GCR_PROJECT="uu-prod"
GCR_REPOSITORY="waas-prod"

DRY_RUN=0
if [ "$1" = "--dry-run" ]; then
  DRY_RUN=1
  echo "=== DRY RUN MODE ==="
fi

echo "=== GCR Image Cleanup for Waas2 Production ==="
echo ""
echo "WARNING: This will DELETE old image versions!"
echo "Only keeping:"
echo "  - Current prod versions"
echo "  - New upgrade versions"
echo ""

# Authenticate
echo "Authenticating with GCR..."
gcloud auth activate-service-account --key-file="$GCR_CREDENTIAL" --quiet 2>&1 | grep -v "Activated" || true
gcloud auth configure-docker "$GCR_REGISTRY" --quiet 2>&1 | grep -v "added to" || true
echo ""

# Define versions to keep
# Format: image_name:current_version:new_version
KEEP_VERSIONS="
service-search-rel:60:6
service-exchange-rel:75:8
service-tron-v2-rel:70:-
service-tron-rel:-:4
service-eth-rel:28:2
service-user-rel:72:1
service-waas-admin-rel:82:1
"

cleanup_image() {
  local image_name="$1"
  local keep_current="$2"
  local keep_new="$3"

  echo "Processing: $image_name"
  echo "  Keep current: ${keep_current:-none}"
  echo "  Keep new: ${keep_new:-none}"

  # Get all tags for this image
  local all_tags=$(gcloud artifacts docker images list \
    "$GCR_REGISTRY/$GCR_PROJECT/$GCR_REPOSITORY/$image_name" \
    --include-tags --format="value(tags)" 2>/dev/null | tr ';' '\n' | sort -n)

  if [ -z "$all_tags" ]; then
    echo "  No tags found"
    echo ""
    return
  fi

  echo "  All tags: $(echo $all_tags | tr '\n' ' ')"

  # Delete tags that are not in keep list
  for tag in $all_tags; do
    if [ "$tag" = "$keep_current" ] || [ "$tag" = "$keep_new" ]; then
      echo "  Keeping: $tag"
    else
      if [ $DRY_RUN -eq 1 ]; then
        echo "  [DRY RUN] Would delete: $tag"
      else
        echo "  Deleting: $tag"
        gcloud artifacts docker images delete \
          "$GCR_REGISTRY/$GCR_PROJECT/$GCR_REPOSITORY/$image_name:$tag" \
          --quiet 2>&1 || echo "    Failed to delete $tag"
      fi
    fi
  done

  echo ""
}

# Process each image
echo "$KEEP_VERSIONS" | while IFS=: read -r image_name keep_current keep_new; do
  # Skip empty lines
  [ -z "$image_name" ] && continue

  # Replace - with empty string
  [ "$keep_current" = "-" ] && keep_current=""
  [ "$keep_new" = "-" ] && keep_new=""

  cleanup_image "$image_name" "$keep_current" "$keep_new"
done

echo "========================================="
if [ $DRY_RUN -eq 1 ]; then
  echo "DRY RUN completed. No images were deleted."
  echo "Run without --dry-run to actually delete images."
else
  echo "Cleanup completed."
fi
