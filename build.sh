#!/bin/bash
# Build script for EasyTier GUI
# Supports Universal Binary (arm64 + x86_64)

set -e

echo "Building EasyTierGUI..."

CONFIGURATION=${1:-Release}
DERIVED_DATA_PATH="$PWD/.build/DerivedData"

# Clean previous build to ensure Universal Binary
rm -rf "$DERIVED_DATA_PATH"

# Build Universal Binary
# ONLY_ACTIVE_ARCH=NO forces building for all architectures in ARCHS setting
xcodebuild build \
    -project EasyTierGUI.xcodeproj \
    -scheme EasyTierGUI \
    -configuration "$CONFIGURATION" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    ONLY_ACTIVE_ARCH=NO \
    -quiet

echo ""
echo "Build complete!"
echo "App location: $DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/EasyTierGUI.app"
echo ""
echo "Architecture support:"
lipo -archs "$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/EasyTierGUI.app/Contents/MacOS/EasyTierGUI"
