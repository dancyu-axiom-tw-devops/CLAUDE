#!/bin/sh
# Upgrade Waas2 production services to new versions
# Usage: ./upgrade.sh [--apply]

set -e

DEPLOY_DIR="/Users/user/Waas2-project/gitlab.axiom-infra.com/waas2-tenant-k8s-deploy"
APPLY_MODE=0

if [ "$1" = "--apply" ]; then
  APPLY_MODE=1
fi

echo "=== Waas2 Production Upgrade Script ==="
echo ""
echo "Deploy directory: $DEPLOY_DIR"
echo "Mode: $([ $APPLY_MODE -eq 1 ] && echo 'APPLY' || echo 'DRY RUN')"
echo ""

cd "$DEPLOY_DIR"

# Upgrade definitions
# Format: service_dir:image_name:new_tag
UPGRADES="
service-search:service-search-rel:6
service-exchange:service-exchange-rel:8
service-tron:service-tron-rel:4
service-eth:service-eth-rel:2
service-user:service-user-rel:1
service-admin:service-waas-admin-rel:1
"

update_kustomization() {
  local service_dir="$1"
  local image_name="$2"
  local new_tag="$3"

  echo "Updating $service_dir..."
  echo "  Image: $image_name"
  echo "  New tag: $new_tag"

  local kustomize_file="$DEPLOY_DIR/$service_dir/kustomization.yml"

  if [ ! -f "$kustomize_file" ]; then
    echo "  ERROR: kustomization.yml not found"
    return 1
  fi

  # Create backup
  cp "$kustomize_file" "$kustomize_file.backup"

  # Update newTag (handle both formats: '60' and 60)
  sed -i.tmp "/name:.*$image_name/,/newTag:/ s/newTag: *['\"]\\?[0-9]*['\"]\\?/newTag: '$new_tag'/" "$kustomize_file"
  rm -f "$kustomize_file.tmp"

  # Show diff
  echo "  Changes:"
  diff "$kustomize_file.backup" "$kustomize_file" || true
  echo ""
}

apply_service() {
  local service_dir="$1"

  if [ $APPLY_MODE -eq 1 ]; then
    echo "Applying $service_dir to cluster..."
    kubectl apply -k "$DEPLOY_DIR/$service_dir" || echo "  WARNING: kubectl apply failed"
    echo ""
  fi
}

# Process upgrades
echo "$UPGRADES" | while IFS=: read -r service_dir image_name new_tag; do
  # Skip empty lines
  [ -z "$service_dir" ] && continue

  update_kustomization "$service_dir" "$image_name" "$new_tag"

  if [ $APPLY_MODE -eq 1 ]; then
    echo "Apply $service_dir? (y/N)"
    read confirm
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
      apply_service "$service_dir"
    else
      echo "  Skipped"
      echo ""
    fi
  fi
done

echo "========================================="
if [ $APPLY_MODE -eq 1 ]; then
  echo "Upgrade completed."
  echo ""
  echo "Next steps:"
  echo "1. Verify pods: kubectl get pods -n waas2-prod"
  echo "2. Check logs if needed: kubectl logs -n waas2-prod <pod-name>"
  echo "3. Rollback if needed: cd $DEPLOY_DIR && ../WF-20251223-1-waas2-prod-upgrade/script/rollback.sh"
else
  echo "DRY RUN completed. Configurations updated locally."
  echo ""
  echo "Review changes:"
  echo "  cd $DEPLOY_DIR && git diff"
  echo ""
  echo "To apply changes:"
  echo "  ./upgrade.sh --apply"
  echo ""
  echo "To rollback changes:"
  echo "  cd $DEPLOY_DIR && git checkout service-*/kustomization.yml"
fi
