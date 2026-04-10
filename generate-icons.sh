#!/bin/bash

set -euo pipefail

ICONSET_DIR="./EasyTierGUI/Assets.xcassets/AppIcon.appiconset"
SOURCE_PNG="${1:-./logo.png}"

echo "Generating macOS app icons from: $SOURCE_PNG"

if ! command -v sips >/dev/null 2>&1; then
    echo "sips is required but was not found."
    exit 1
fi

if [ ! -f "$SOURCE_PNG" ]; then
    echo "Source image not found: $SOURCE_PNG"
    exit 1
fi

mkdir -p "$ICONSET_DIR"

SOURCE_WIDTH=$(sips -g pixelWidth "$SOURCE_PNG" | awk '/pixelWidth/ {print $2}')
SOURCE_HEIGHT=$(sips -g pixelHeight "$SOURCE_PNG" | awk '/pixelHeight/ {print $2}')

if [ "$SOURCE_WIDTH" != "$SOURCE_HEIGHT" ]; then
    echo "Source image must be square. Current size: ${SOURCE_WIDTH}x${SOURCE_HEIGHT}"
    exit 1
fi

if [ "$SOURCE_WIDTH" -lt 1024 ]; then
    echo "Source image should be at least 1024x1024. Current size: ${SOURCE_WIDTH}x${SOURCE_HEIGHT}"
    exit 1
fi

for size in 16 32 64 128 256 512 1024; do
    output_file="$ICONSET_DIR/${size}.png"
    echo "Creating ${size}x${size} -> ${output_file}"
    sips -z "$size" "$size" "$SOURCE_PNG" --out "$output_file" >/dev/null
done

cat > "$ICONSET_DIR/Contents.json" <<'EOF'
{
  "images" : [
    {
      "size" : "16x16",
      "idiom" : "mac",
      "filename" : "16.png",
      "scale" : "1x"
    },
    {
      "size" : "16x16",
      "idiom" : "mac",
      "filename" : "32.png",
      "scale" : "2x"
    },
    {
      "size" : "32x32",
      "idiom" : "mac",
      "filename" : "32.png",
      "scale" : "1x"
    },
    {
      "size" : "32x32",
      "idiom" : "mac",
      "filename" : "64.png",
      "scale" : "2x"
    },
    {
      "size" : "128x128",
      "idiom" : "mac",
      "filename" : "128.png",
      "scale" : "1x"
    },
    {
      "size" : "128x128",
      "idiom" : "mac",
      "filename" : "256.png",
      "scale" : "2x"
    },
    {
      "size" : "256x256",
      "idiom" : "mac",
      "filename" : "256.png",
      "scale" : "1x"
    },
    {
      "size" : "256x256",
      "idiom" : "mac",
      "filename" : "512.png",
      "scale" : "2x"
    },
    {
      "size" : "512x512",
      "idiom" : "mac",
      "filename" : "512.png",
      "scale" : "1x"
    },
    {
      "size" : "512x512",
      "idiom" : "mac",
      "filename" : "1024.png",
      "scale" : "2x"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF

echo "App icons generated in $ICONSET_DIR"
echo "Menu bar icon was not modified."
