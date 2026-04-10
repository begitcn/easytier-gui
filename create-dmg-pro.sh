#!/bin/bash
# Create professional DMG installer for EasyTierGUI
# Features: Custom background, proper window layout, icon positioning

set -e

CONFIGURATION=${1:-Release}
APP_NAME="EasyTierGUI"
APP_PATH=".build/DerivedData/Build/Products/$CONFIGURATION/$APP_NAME.app"
DMG_NAME="$APP_NAME.dmg"
DMG_PATH="$DMG_NAME"
VOLUME_NAME="$APP_NAME"
TMP_DIR="./.dmg-temp"

# Window dimensions and icon positions
WINDOW_BOUNDS="100, 100, 760, 500"  # x, y, width, height
ICON_SIZE=100
APP_ICON_POS="160, 250"
APPS_ICON_POS="500, 250"

# 检查 app 是否存在
if [ ! -d "$APP_PATH" ]; then
    echo "❌ Error: $APP_PATH not found!"
    echo "   Please run ./build.sh first."
    exit 1
fi

echo "📦 Creating professional DMG for $APP_NAME..."

# 清理旧文件
rm -rf "$TMP_DIR"
rm -f "$DMG_PATH"

# 创建临时目录
mkdir -p "$TMP_DIR/.background"

# 复制应用和创建 Applications 链接
cp -R "$APP_PATH" "$TMP_DIR/"
ln -s /Applications "$TMP_DIR/Applications"

# 创建背景图片 (使用 Swift 脚本)
echo "🎨 Creating background image..."
cat > "$TMP_DIR/.background/create.swift" << 'SWIFT'
#!/usr/bin/swift
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

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

// 渐变背景
let colors = [
    CGColor(red: 0.11, green: 0.11, blue: 0.20, alpha: 1.0),
    CGColor(red: 0.06, green: 0.12, blue: 0.25, alpha: 1.0)
]
if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                              colors: colors as CFArray, locations: [0, 1]) {
    context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: height), options: [])
}

// 装饰元素
context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.03))
context.fillEllipse(in: CGRect(x: -50, y: -50, width: 200, height: 200))
context.fillEllipse(in: CGRect(x: width-150, y: height-150, width: 200, height: 200))

if let image = context.makeImage() {
    let url = URL(fileURLWithPath: "background.png")
    if let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) {
        CGImageDestinationAddImage(dest, image, nil)
        CGImageDestinationFinalize(dest)
    }
}
SWIFT

cd "$TMP_DIR/.background" && swift create.swift 2>/dev/null && rm create.swift && cd - > /dev/null

# 如果背景创建失败，使用默认背景
if [ ! -f "$TMP_DIR/.background/background.png" ]; then
    echo "⚠️  Background creation failed, using fallback..."
    # 创建简单的纯色背景
    sips -s format png -o "$TMP_DIR/.background/background.png" \
        /System/Library/Desktop\ Pictures/Solid\ Colors/Solid\ Aqua\ Graphite.png 2>/dev/null || true
fi

# 创建可读写 DMG
echo "🔨 Creating temporary DMG..."
hdiutil create -volname "$VOLUME_NAME" -srcfolder "$TMP_DIR" \
    -ov -format UDRW -size 200m "$TMP_DIR/temp.dmg" -quiet

# 挂载 DMG
MOUNT_DIR=$(hdiutil attach -readwrite -noverify -noautoopen "$TMP_DIR/temp.dmg" 2>/dev/null | \
    grep "/Volumes/$VOLUME_NAME" | awk '{print $3}')

echo "⚙️  Configuring DMG appearance..."

# 使用 AppleScript 配置窗口
osascript 2>/dev/null << EOF
tell application "Finder"
    tell disk "$VOLUME_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set bounds of container window to {$WINDOW_BOUNDS}
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
echo "🗜️  Compressing DMG..."
hdiutil convert "$TMP_DIR/temp.dmg" -format UDZO -imagekey zlib-level=9 -o "$DMG_PATH" -quiet

# 清理
rm -rf "$TMP_DIR"

# 获取文件大小
SIZE=$(du -h "$DMG_PATH" | cut -f1)

echo ""
echo "✅ Professional DMG created successfully!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📍 Location: $PWD/$DMG_PATH"
echo "📊 Size: $SIZE"
echo ""
echo "🎨 Features:"
echo "   • Custom gradient background"
echo "   • Professional window layout"
echo "   • Optimized icon positioning"
echo "   • Maximum compression"
echo ""
