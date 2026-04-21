#!/bin/bash
# Create DMG installer for EasyTierGUI
# Features: White background, proper window size without scrollbar

set -e

CONFIGURATION=${1:-Release}
APP_NAME="EasyTierGUI"
APP_PATH=".build/DerivedData/Build/Products/$CONFIGURATION/$APP_NAME.app"
DMG_NAME="$APP_NAME.dmg"
DMG_PATH="$DMG_NAME"
VOLUME_NAME="$APP_NAME"
TMP_DIR="./.dmg-temp"

# Window settings - width and height for the DMG window
# macOS Finder windows need extra space for title bar etc.
# Background image should match content area
WINDOW_WIDTH=660
WINDOW_HEIGHT=400
ICON_SIZE=100

# Icon positions (x, y from top-left of content area)
APP_ICON_POS="180, 180"
APPS_ICON_POS="480, 180"

# 检查 app 是否存在
if [ ! -d "$APP_PATH" ]; then
    echo "Error: $APP_PATH not found!"
    echo "Please run ./build.sh first."
    exit 1
fi

echo "Creating DMG for $APP_NAME..."
echo "  App size: $(du -sh "$APP_PATH" | cut -f1)"

# 清理旧文件
rm -rf "$TMP_DIR"
rm -f "$DMG_PATH"

# 创建临时目录
mkdir -p "$TMP_DIR/.background"

# 复制应用和创建 Applications 链接
cp -R "$APP_PATH" "$TMP_DIR/"
ln -s /Applications "$TMP_DIR/Applications"

# 创建白色背景图片 (与窗口内容区域大小匹配)
echo "Creating background..."
cat > "$TMP_DIR/.background/create.swift" << 'SWIFT'
#!/usr/bin/swift
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// Match window content area size
let width: CGFloat = 660
let height: CGFloat = 400

guard let context = CGContext(
    data: nil,
    width: Int(width),
    height: Int(height),
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { exit(1) }

// Pure white background
context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
context.fill(CGRect(x: 0, y: 0, width: width, height: height))

if let image = context.makeImage() {
    let url = URL(fileURLWithPath: "background.png")
    if let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) {
        CGImageDestinationAddImage(dest, image, nil)
        CGImageDestinationFinalize(dest)
    }
}
SWIFT

cd "$TMP_DIR/.background" && swift create.swift 2>/dev/null && rm create.swift && cd - > /dev/null

# 备用方案
if [ ! -f "$TMP_DIR/.background/background.png" ]; then
    sips -s format png -o "$TMP_DIR/.background/background.png" \
        /System/Library/Desktop\ Pictures/Solid\ Colors/Solid\ White.png 2>/dev/null || true
fi

# 创建可读写 DMG
echo "Creating DMG..."
hdiutil create -volname "$VOLUME_NAME" -srcfolder "$TMP_DIR" \
    -ov -format UDRW -size 200m "$TMP_DIR/temp.dmg" -quiet

# 挂载 DMG
MOUNT_DIR=$(hdiutil attach -readwrite -noverify -noautoopen "$TMP_DIR/temp.dmg" 2>/dev/null | \
    grep "/Volumes/$VOLUME_NAME" | awk '{print $3}')

echo "Configuring window..."

# 使用 AppleScript 配置窗口
# bounds format: {left, top, right, bottom} - this is the correct macOS format
osascript 2>/dev/null << EOF
tell application "Finder"
    tell disk "$VOLUME_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        -- bounds: {left, top, right, bottom}
        set bounds of container window to {100, 100, 100 + $WINDOW_WIDTH, 100 + $WINDOW_HEIGHT}
        set icon size of icon view options of container window to $ICON_SIZE
        set text size of icon view options of container window to 14
        set background picture of icon view options of container window to file ".background:background.png"

        delay 1

        set position of item "$APP_NAME.app" of container window to {$APP_ICON_POS}
        set position of item "Applications" of container window to {$APPS_ICON_POS}

        close
        open
        update without registering applications
        delay 2
    end tell
end tell
EOF

sync
hdiutil detach "$MOUNT_DIR" -force -quiet

# 转换为压缩 DMG
echo "Compressing..."
hdiutil convert "$TMP_DIR/temp.dmg" -format UDZO -imagekey zlib-level=9 -o "$DMG_PATH" -quiet

# 清理
rm -rf "$TMP_DIR"

# 获取文件大小
SIZE=$(du -h "$DMG_PATH" | cut -f1)

echo ""
echo "Done: $DMG_PATH ($SIZE)"
