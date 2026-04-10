#!/bin/bash
# Create DMG installer for EasyTierGUI
#
# This is the simple version. For a professional-looking DMG with custom
# background and window layout, use: ./create-dmg-pro.sh

set -e

CONFIGURATION=${1:-Release}
APP_NAME="EasyTierGUI"
APP_PATH=".build/DerivedData/Build/Products/$CONFIGURATION/$APP_NAME.app"
DMG_NAME="$APP_NAME.dmg"
DMG_PATH="$DMG_NAME"
VOLUME_NAME="$APP_NAME"
TMP_DIR="./.dmg-temp"

# 检查 app 是否存在
if [ ! -d "$APP_PATH" ]; then
    echo "Error: $APP_PATH not found!"
    echo "Please run ./build.sh first."
    exit 1
fi

echo "Creating DMG for $APP_NAME..."

# 清理旧的临时文件
rm -rf "$TMP_DIR"
rm -f "$DMG_PATH"

# 创建临时目录结构
mkdir -p "$TMP_DIR"

# 复制 app
cp -R "$APP_PATH" "$TMP_DIR/"

# 创建 Applications 符号链接
ln -s /Applications "$TMP_DIR/Applications"

# 创建 DMG
echo "Creating DMG file..."
hdiutil create -volname "$VOLUME_NAME" \
    -srcfolder "$TMP_DIR" \
    -ov -format UDZO \
    "$DMG_PATH"

# 清理临时文件
rm -rf "$TMP_DIR"

echo ""
echo "=========================================="
echo "DMG created successfully!"
echo "Location: $PWD/$DMG_PATH"
echo "=========================================="
echo ""
echo "To install: Open the DMG and drag $APP_NAME to Applications folder"
