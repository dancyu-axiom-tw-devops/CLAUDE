#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

IMAGE_NAME="asia-east2-docker.pkg.dev/uu-prod/waas-prod/waas2-health-monitor"
TAG="${1:-latest}"

echo "Building Docker image..."
echo "Image: ${IMAGE_NAME}:${TAG}"
echo ""

# Copy health-check.py to deployment directory temporarily
cp "${PROJECT_ROOT}/scripts/health-check.py" "${SCRIPT_DIR}/scripts/"

# Build image
docker build \
  --platform linux/amd64 \
  -t "${IMAGE_NAME}:${TAG}" \
  -f "${SCRIPT_DIR}/Dockerfile" \
  "${SCRIPT_DIR}"

# Cleanup
rm -f "${SCRIPT_DIR}/scripts/health-check.py"

echo ""
echo "Image built successfully!"
echo ""
echo "To push to registry:"
echo "  docker push ${IMAGE_NAME}:${TAG}"
echo ""
echo "To deploy:"
echo "  cd ${PROJECT_ROOT}/deployment"
echo "  kubectl apply -f secret-template.yml"
echo "  kubectl apply -f cronjob.yml"
