#!/bin/bash
# Build script for EasyTier GUI
# Supports Universal Binary (arm64 + x86_64)

set -e

echo "Building EasyTierGUI..."

CONFIGURATION=${1:-Release}
DERIVED_DATA_PATH="$PWD/.build/DerivedData"
RESOURCES_DIR="$PWD/EasyTierGUI/Resources/easytier"

# MARK: - Download EasyTier Binaries

echo ""
echo "Checking EasyTier binaries..."

# 创建资源目录
mkdir -p "$RESOURCES_DIR"

# 根据架构选择下载文件
ARCH=$(uname -m)
case $ARCH in
    arm64)
        ARCH_NAME="aarch64"
        ;;
    x86_64)
        ARCH_NAME="x86_64"
        ;;
    *)
        echo "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

echo "Architecture: $ARCH ($ARCH_NAME)"

# 获取最新版本信息（优先使用 releases/latest 重定向，避免 API 限流和 JSON 解析脆弱性）
echo "Fetching latest release info from GitHub..."
LATEST_VERSION=""
LATEST_TAG_URL=$(curl -fsSL -o /dev/null -w '%{url_effective}' -A "EasyTierGUI-Build/1.0" \
    https://github.com/EasyTier/EasyTier/releases/latest 2>/dev/null || true)

if [ -n "$LATEST_TAG_URL" ]; then
    LATEST_VERSION=$(basename "$LATEST_TAG_URL")
fi

# 回退：如果重定向拿不到版本，再尝试 GitHub API
if [ -z "$LATEST_VERSION" ]; then
    LATEST_RELEASE_JSON=$(curl -fsSL -H "User-Agent: EasyTierGUI-Build/1.0" \
        -H "Accept: application/vnd.github.v3+json" \
        https://api.github.com/repos/EasyTier/EasyTier/releases/latest 2>/dev/null || true)
    if echo "$LATEST_RELEASE_JSON" | grep -q '"tag_name"'; then
        LATEST_VERSION=$(echo "$LATEST_RELEASE_JSON" | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)
    fi
fi

# 最终兜底和格式校验
if ! echo "$LATEST_VERSION" | grep -Eq '^v?[0-9]+\.[0-9]+\.[0-9]+$'; then
    echo "Warning: Failed to detect valid latest version from remote"
    LATEST_VERSION="v2.4.5"
    echo "Using fallback version: $LATEST_VERSION"
fi

# 统一补齐 v 前缀
if ! echo "$LATEST_VERSION" | grep -q '^v'; then
    LATEST_VERSION="v$LATEST_VERSION"
fi
echo "Latest version: $LATEST_VERSION"

# 构建下载 URL
# 文件名格式: easytier-macos-aarch64-v2.4.5.zip 或 easytier-macos-x86_64-v2.4.5.zip
VERSION_NUM=$(echo "$LATEST_VERSION" | sed 's/v//')
DOWNLOAD_URL="https://github.com/EasyTier/EasyTier/releases/download/$LATEST_VERSION/easytier-macos-$ARCH_NAME-$LATEST_VERSION.zip"

echo "Download URL: $DOWNLOAD_URL"

# 检查是否需要下载
CORE_BINARY="$RESOURCES_DIR/easytier-core"
NEED_DOWNLOAD=false

if [ ! -f "$CORE_BINARY" ]; then
    NEED_DOWNLOAD=true
else
    # 检查版本是否匹配（仅当 API 返回了版本号时）
    CURRENT_VERSION=$("$CORE_BINARY" -V 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "unknown")
    if [ "$CURRENT_VERSION" != "$VERSION_NUM" ]; then
        echo "Version mismatch: current=$CURRENT_VERSION, latest=$VERSION_NUM"
        NEED_DOWNLOAD=true
    else
        echo "Binaries up to date: $CURRENT_VERSION"
    fi
fi

if [ "$NEED_DOWNLOAD" = true ]; then
    echo "Downloading EasyTier binaries..."
    TEMP_ZIP="/tmp/easytier-download.zip"

    curl -L -o "$TEMP_ZIP" "$DOWNLOAD_URL"

    echo "Extracting binaries..."
    TEMP_DIR="/tmp/easytier-extract-$$"
    mkdir -p "$TEMP_DIR"
    unzip -q -o "$TEMP_ZIP" -d "$TEMP_DIR"

    # 查找并移动二进制文件
    find "$TEMP_DIR" -name "easytier-core" -type f -exec mv {} "$RESOURCES_DIR/" \; 2>/dev/null || true
    find "$TEMP_DIR" -name "easytier-cli" -type f -exec mv {} "$RESOURCES_DIR/" \; 2>/dev/null || true

    # 设置可执行权限
    chmod +x "$RESOURCES_DIR/easytier-core" 2>/dev/null || true
    chmod +x "$RESOURCES_DIR/easytier-cli" 2>/dev/null || true

    # 清理
    rm -rf "$TEMP_DIR" "$TEMP_ZIP"

    # 验证
    if [ -f "$RESOURCES_DIR/easytier-core" ]; then
        echo "Binaries extracted successfully"
        "$RESOURCES_DIR/easytier-core" -V || true
    else
        echo "Warning: easytier-core not found in downloaded archive"
    fi
fi

# MARK: - Build

echo ""
echo "Starting Xcode build..."

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

# MARK: - Copy Binaries to App Bundle

APP_PATH="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/EasyTierGUI.app"
APP_RESOURCES="$APP_PATH/Contents/Resources/easytier"

echo "Embedding binaries in app bundle..."
mkdir -p "$APP_RESOURCES"

if [ -f "$RESOURCES_DIR/easytier-core" ]; then
    cp "$RESOURCES_DIR/easytier-core" "$APP_RESOURCES/"
    chmod +x "$APP_RESOURCES/easytier-core"
    echo "✓ easytier-core copied"
else
    echo "✗ easytier-core not found"
fi

if [ -f "$RESOURCES_DIR/easytier-cli" ]; then
    cp "$RESOURCES_DIR/easytier-cli" "$APP_RESOURCES/"
    chmod +x "$APP_RESOURCES/easytier-cli"
    echo "✓ easytier-cli copied"
else
    echo "✗ easytier-cli not found"
fi

echo ""
echo "App location: $APP_PATH"
echo ""
echo "Architecture support:"
lipo -archs "$APP_PATH/Contents/MacOS/EasyTierGUI"

# MARK: - Verify Embedded Binaries

echo ""
echo "Verifying embedded binaries..."
if [ -f "$APP_RESOURCES/easytier-core" ]; then
    echo "✓ easytier-core: $("$APP_RESOURCES/easytier-core" -V 2>/dev/null || echo "version unknown")"
else
    echo "✗ easytier-core NOT found in app bundle"
fi
if [ -f "$APP_RESOURCES/easytier-cli" ]; then
    echo "✓ easytier-cli embedded"
else
    echo "✗ easytier-cli NOT found in app bundle"
fi
