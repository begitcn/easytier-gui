#!/bin/bash
# Build script for EasyTier GUI

set -e

echo "Building EasyTierGUI..."

CONFIGURATION=${1:-Release}
DERIVED_DATA_PATH="$PWD/.build/DerivedData"

xcodebuild build \
    -project EasyTierGUI.xcodeproj \
    -scheme EasyTierGUI \
    -configuration "$CONFIGURATION" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    -quiet

echo ""
echo "Build complete!"
echo "App location: $DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/EasyTierGUI.app"
