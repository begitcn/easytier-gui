#!/bin/bash

# Icon Generation Script for EasyTier GUI
# Requires ImageMagick or sips (macOS built-in)

set -e

echo "🎨 Generating EasyTier GUI Icons..."
echo "=================================="

ICONSET_DIR="./EasyTierGUI/Assets.xcassets/AppIcon.appiconset"
SVG_FILE="./icon.svg"

# Check if SVG exists
if [ ! -f "$SVG_FILE" ]; then
    echo "❌ SVG file not found: $SVG_FILE"
    exit 1
fi

# Create temp directory
TEMP_DIR=$(mktemp -d)
echo "📁 Temp directory: $TEMP_DIR"

# Try using sips (macOS built-in)
if command -v sips &> /dev/null; then
    echo "✅ Using sips (macOS built-in)"

    # First convert SVG to PNG using qlmanage or rsvg-convert
    if command -v rsvg-convert &> /dev/null; then
        echo "✅ Using rsvg-convert for SVG"
        rsvg-convert -w 1024 -h 1024 "$SVG_FILE" > "$TEMP_DIR/icon_1024.png"
    elif command -v qlmanage &> /dev/null; then
        echo "✅ Using qlmanage for SVG"
        qlmanage -t -s 1024 -o "$TEMP_DIR" "$SVG_FILE"
        mv "$TEMP_DIR"/*.png "$TEMP_DIR/icon_1024.png" 2>/dev/null || true
    else
        echo "⚠️  No SVG converter found. Please install librsvg:"
        echo "   brew install librsvg"
        echo ""
        echo "Alternatively, manually create a 1024x1024 PNG and run this script."
        exit 1
    fi

    BASE_PNG="$TEMP_DIR/icon_1024.png"

    if [ ! -f "$BASE_PNG" ]; then
        echo "❌ Failed to create base PNG"
        exit 1
    fi

    # Generate all required sizes
    sizes=("16:16" "32:16@2x" "32:32" "64:32@2x" "128:128" "256:128@2x" "256:256" "512:256@2x" "512:512" "1024:512@2x")

    for size_def in "${sizes[@]}"; do
        IFS=':' read -r size filename <<< "$size_def"
        echo "  Creating ${size}x${size} -> icon_${filename}.png"
        sips -z $size $size "$BASE_PNG" --out "$ICONSET_DIR/icon_${filename}.png" > /dev/null 2>&1
    done

# Try ImageMagick
elif command -v convert &> /dev/null; then
    echo "✅ Using ImageMagick"

    sizes=("16:16" "32:16@2x" "32:32" "64:32@2x" "128:128" "256:128@2x" "256:256" "512:256@2x" "512:512" "1024:512@2x")

    for size_def in "${sizes[@]}"; do
        IFS=':' read -r size filename <<< "$size_def"
        echo "  Creating ${size}x${size} -> icon_${filename}.png"
        convert -background none -resize ${size}x${size} "$SVG_FILE" "$ICONSET_DIR/icon_${filename}.png"
    done
else
    echo "❌ No suitable image converter found"
    echo "Please install one of:"
    echo "  - ImageMagick: brew install imagemagick"
    echo "  - librsvg: brew install librsvg"
    exit 1
fi

# Update Contents.json
echo ""
echo "📝 Updating Contents.json"
cat > "$ICONSET_DIR/Contents.json" << 'EOF'
{
  "images" : [
    {
      "filename" : "icon_16.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "16x16"
    },
    {
      "filename" : "icon_16@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "16x16"
    },
    {
      "filename" : "icon_32.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "32x32"
    },
    {
      "filename" : "icon_32@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "32x32"
    },
    {
      "filename" : "icon_128.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "128x128"
    },
    {
      "filename" : "icon_128@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "128x128"
    },
    {
      "filename" : "icon_256.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "256x256"
    },
    {
      "filename" : "icon_256@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "256x256"
    },
    {
      "filename" : "icon_512.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "512x512"
    },
    {
      "filename" : "icon_512@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "512x512"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF

# Cleanup
rm -rf "$TEMP_DIR"

echo ""
echo "✨ Icon generation complete!"
echo ""
echo "Generated files:"
ls -lh "$ICONSET_DIR"
