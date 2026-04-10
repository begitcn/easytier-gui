#!/bin/bash
# Create DMG installer for EasyTierGUI with professional appearance

set -e

CONFIGURATION=${1:-Release}
APP_NAME="EasyTierGUI"
APP_PATH=".build/DerivedData/Build/Products/$CONFIGURATION/$APP_NAME.app"
DMG_NAME="$APP_NAME.dmg"
DMG_PATH="$DMG_NAME"
VOLUME_NAME="$APP_NAME"
TMP_DIR="./.dmg-temp"
BACKGROUND_DIR="$TMP_DIR/.background"

# Window settings
WINDOW_WIDTH=660
WINDOW_HEIGHT=400
ICON_SIZE=128
TEXT_SIZE=16

# Icon positions (left side for app, right side for Applications)
APP_ICON_X=180
APP_ICON_Y=200
APPS_ICON_X=480
APPS_ICON_Y=200

# 检查 app 是否存在
if [ ! -d "$APP_PATH" ]; then
    echo "Error: $APP_PATH not found!"
    echo "Please run ./build.sh first."
    exit 1
fi

echo "Creating professional DMG for $APP_NAME..."

# 清理旧的临时文件
rm -rf "$TMP_DIR"
rm -f "$DMG_PATH"

# 创建临时目录结构
mkdir -p "$TMP_DIR"
mkdir -p "$BACKGROUND_DIR"

# 复制 app
cp -R "$APP_PATH" "$TMP_DIR/"

# 创建 Applications 符号链接
ln -s /Applications "$TMP_DIR/Applications"

# 创建背景图片
echo "Creating background image..."
cat > "$TMP_DIR/create_background.py" << 'PYTHON_EOF'
#!/usr/bin/env python3
import os
from CoreGraphics import (
    CGRectMake, CGColorCreateGenericRGB,
    CGContextCreate, CGColorSpaceCreateWithName,
    kCGColorSpaceSRGB, CGImageDestinationCreateWithURL,
    kCGImageDestinationPNG, CGImageDestinationAddImage
)
from Quartz import (
    CGMainDisplayID, CGDisplayPixelsHigh,
    CGWindowListCopyWindowInfo, kCGNullWindowID,
    kCGWindowListOptionOnScreenOnly
)

# Create a simple gradient background with text
width, height = 660, 400

# Create color space and context
colorspace = CGColorSpaceCreateWithName(kCGColorSpaceSRGB)
context = CGContextCreate(None, width, height, colorspace)

# Background gradient (dark blue to lighter blue)
def draw_gradient():
    # Top color: #1a1a2e (dark blue)
    top_color = CGColorCreateGenericRGB(0.102, 0.102, 0.180, 1.0)
    # Bottom color: #16213e (medium blue)
    bottom_color = CGColorCreateGenericRGB(0.086, 0.129, 0.243, 1.0)

    # Fill with gradient
    for y in range(height):
        ratio = y / height
        r = 0.102 * (1 - ratio) + 0.086 * ratio
        g = 0.102 * (1 - ratio) + 0.129 * ratio
        b = 0.180 * (1 - ratio) + 0.243 * ratio
        color = CGColorCreateGenericRGB(r, g, b, 1.0)
        context.setFillColor(color)
        context.fillRect(CGRectMake(0, y, width, 1))

draw_gradient()

# Save as PNG
url = CFURLCreateWithFileSystemPath(None, b"background.png", kCFURLPOSIXPathStyle, False)
dest = CGImageDestinationCreateWithURL(url, kCGImageDestinationPNG, 1, None)
image = context.getCGImage()
CGImageDestinationAddImage(dest, image, None)
CGImageDestinationFinalize(dest)

print("Background image created successfully")
PYTHON_EOF

# 使用更简单的方法创建背景图片 - 使用 Swift 脚本
cat > "$TMP_DIR/create_background.swift" << 'SWIFT_EOF'
#!/usr/bin/swift
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let width: CGFloat = 660
let height: CGFloat = 400

// 创建 RGB 颜色空间
let colorSpace = CGColorSpaceCreateDeviceRGB()

// 创建位图上下文
guard let context = CGContext(
    data: nil,
    width: Int(width),
    height: Int(height),
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    print("Failed to create context")
    exit(1)
}

// 绘制渐变背景
let colors = [
    CGColor(red: 0.102, green: 0.102, blue: 0.180, alpha: 1.0),  // 顶部：深蓝
    CGColor(red: 0.086, green: 0.129, blue: 0.243, alpha: 1.0)   // 底部：中蓝
]

guard let gradient = CGGradient(
    colorsSpace: colorSpace,
    colors: colors as CFArray,
    locations: [0.0, 1.0]
) else {
    print("Failed to create gradient")
    exit(1)
}

context.drawLinearGradient(
    gradient,
    start: CGPoint(x: 0, y: 0),
    end: CGPoint(x: 0, y: height),
    options: []
)

// 添加装饰性圆形
context.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.03))
context.fillEllipse(in: CGRect(x: -100, y: -100, width: 300, height: 300))
context.fillEllipse(in: CGRect(x: width - 200, y: height - 200, width: 300, height: 300))

// 创建图像
guard let image = context.makeImage() else {
    print("Failed to create image")
    exit(1)
}

// 保存为 PNG
let url = URL(fileURLWithPath: "background.png")
guard let destination = CGImageDestinationCreateWithURL(
    url as CFURL,
    UTType.png.identifier as CFString,
    1,
    nil
) else {
    print("Failed to create destination")
    exit(1)
}

CGImageDestinationAddImage(destination, image, nil)
CGImageDestinationFinalize(destination)

print("Background image created: \(url.path)")
SWIFT_EOF

# 执行 Swift 脚本创建背景图片
cd "$TMP_DIR"
swift create_background.swift 2>/dev/null || {
    echo "Swift method failed, creating simple background..."
    # 备用方案：使用纯色背景
    sips -s format png --resampleWidth $WINDOW_WIDTH --resampleHeight $WINDOW_HEIGHT \
        -o background.png /System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/GenericApplicationIcon.icns 2>/dev/null || \
    {
        # 如果 sips 也失败，创建一个简单的 1x1 PNG
        echo "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==" | base64 -d > background.png
    }
}
cd - > /dev/null

# 移动背景图片到正确位置
if [ -f "$TMP_DIR/background.png" ]; then
    mv "$TMP_DIR/background.png" "$BACKGROUND_DIR/background.png"
fi

# 创建空的 DMG 用于设置属性
echo "Creating temporary DMG..."
hdiutil create -volname "$VOLUME_NAME" \
    -srcfolder "$TMP_DIR" \
    -ov -format UDRW \
    -size 200m \
    "$TMP_DIR/temp.dmg"

# 挂载 DMG
echo "Mounting DMG for customization..."
MOUNT_DIR=$(hdiutil attach -readwrite -noverify -noautoopen "$TMP_DIR/temp.dmg" | \
    egrep '^/dev/' | sed 1q | awk '{print $3}')

echo "Mounted at: $MOUNT_DIR"

# 设置 DMG 窗口外观
echo "Setting DMG window appearance..."

# 使用 AppleScript 设置窗口属性
osascript << APPLESCRIPT_EOF
tell application "Finder"
    tell disk "$VOLUME_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {100, 100, $WINDOW_WIDTH, $WINDOW_HEIGHT}
        set theViewOptions to the icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to $ICON_SIZE
        set text size of theViewOptions to $TEXT_SIZE
        set background picture of theViewOptions to file ".background:background.png"

        -- 设置图标位置
        set position of item "$APP_NAME.app" of container window to {$APP_ICON_X, $APP_ICON_Y}
        set position of item "Applications" of container window to {$APPS_ICON_X, $APPS_ICON_Y}

        -- 关闭再打开以确保设置生效
        close
        open

        -- 更新窗口
        update without registering applications
        delay 2
    end tell
end tell
APPLESCRIPT_EOF

# 确保所有更改已写入
sync

# 卸载 DMG
echo "Unmounting DMG..."
hdiutil detach "$MOUNT_DIR" -force

# 转换为压缩的只读 DMG
echo "Converting to compressed DMG..."
hdiutil convert "$TMP_DIR/temp.dmg" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "$DMG_PATH"

# 清理临时文件
rm -rf "$TMP_DIR"

echo ""
echo "=========================================="
echo "Professional DMG created successfully!"
echo "Location: $PWD/$DMG_PATH"
echo "=========================================="
echo ""
echo "Features:"
echo "  ✓ Custom gradient background"
echo "  ✓ Professional window layout"
echo "  ✓ Optimized icon positions"
echo "  ✓ Compressed for smaller size"
echo ""
echo "To install: Open the DMG and drag $APP_NAME to Applications folder"
