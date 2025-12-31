#!/bin/sh
# Install k8s-daily-monitor scripts
# Usage: ./install.sh

set -e

PROJECT_DIR="/Users/user/MONITOR/k8s-daily-monitor"
SCRIPT_DIR="${PROJECT_DIR}/scripts"
SOURCE_DIR="$(dirname "$0")/script"

echo "Installing k8s-daily-monitor scripts..."
echo "Target: $SCRIPT_DIR"
echo ""

# Create target directory
mkdir -p "$SCRIPT_DIR"

# Copy scripts
for script in task1_sync.sh task2_detect.sh task3_analyze.sh task4_changelog.sh run_daily.sh; do
    if [ -f "${SOURCE_DIR}/${script}" ]; then
        cp "${SOURCE_DIR}/${script}" "${SCRIPT_DIR}/${script}"
        chmod +x "${SCRIPT_DIR}/${script}"
        echo "Installed: ${script}"
    else
        echo "WARN: ${script} not found"
    fi
done

echo ""
echo "Installation complete!"
echo ""
echo "Usage:"
echo "  cd $PROJECT_DIR"
echo "  ./scripts/run_daily.sh"
echo ""
echo "Or run individual tasks:"
echo "  ./scripts/task1_sync.sh"
echo "  ./scripts/task2_detect.sh"
echo "  ./scripts/task3_analyze.sh"
echo "  ./scripts/task4_changelog.sh"
