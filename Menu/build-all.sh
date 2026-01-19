#!/bin/bash
# Build Menu.app and its status item bundles

set -e

cd "$(dirname "$0")"

echo "Building Menu application..."
make all

echo ""
echo "Building SystemMonitor bundle..."
cd StatusItems/SystemMonitor
make all
cd ../..

echo ""
echo "Building TimeDisplay bundle..."
cd StatusItems/TimeDisplay
make all
cd ../..

echo ""
echo "==================================="
echo "Build complete!"
echo "==================================="
echo ""
echo "Menu.app: ./Menu.app"
echo "SystemMonitor.bundle: ./StatusItems/SystemMonitor/SystemMonitor.bundle"
echo "TimeDisplay.bundle: ./StatusItems/TimeDisplay/TimeDisplay.bundle"
