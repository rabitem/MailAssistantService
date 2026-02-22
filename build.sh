#!/bin/bash

# MailAssistantService Build Script
# This script helps build and install MailAssistantService

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🔧 MailAssistantService Build Script"
echo "===================================="
echo ""

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo -e "${RED}Error: This script must be run on macOS${NC}"
    exit 1
fi

# Check macOS version
MACOS_VERSION=$(sw_vers -productVersion)
echo "📱 macOS Version: $MACOS_VERSION"

# Check if Xcode is installed
if ! command -v xcodebuild &> /dev/null; then
    echo -e "${RED}Error: Xcode is not installed${NC}"
    echo "Please install Xcode from the App Store"
    exit 1
fi

XCODE_VERSION=$(xcodebuild -version | head -n 1)
echo "🔨 Xcode Version: $XCODE_VERSION"

# Check if Mail.app exists
if [ ! -d "/Applications/Mail.app" ]; then
    echo -e "${YELLOW}Warning: Mail.app not found at default location${NC}"
fi

# Navigate to project directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

echo ""
echo "📂 Project Directory: $SCRIPT_DIR"
echo ""

# Function to build target
build_target() {
    local target=$1
    echo "🏗️  Building $target..."
    
    if xcodebuild -project MailAssistant.xcodeproj \
                  -scheme "$target" \
                  -configuration Debug \
                  -destination 'platform=macOS' \
                  build; then
        echo -e "${GREEN}✅ $target built successfully${NC}"
    else
        echo -e "${RED}❌ $target build failed${NC}"
        return 1
    fi
}

# Build all targets
echo "🚀 Starting Build Process"
echo "========================="
echo ""

# Clean first
echo "🧹 Cleaning build folder..."
xcodebuild -project MailAssistant.xcodeproj clean 2>/dev/null || true
echo ""

# Build targets
build_target "MailAssistant" || exit 1
echo ""
build_target "MailExtension" || exit 1
echo ""
build_target "MailAssistantService" || exit 1

echo ""
echo -e "${GREEN}🎉 All targets built successfully!${NC}"
echo ""

# Find build products
BUILD_DIR=$(xcodebuild -project MailAssistant.xcodeproj -showBuildSettings 2>/dev/null | grep "CONFIGURATION_BUILD_DIR" | head -1 | sed 's/.*= //' | tr -d ' ')

if [ -z "$BUILD_DIR" ]; then
    BUILD_DIR="$HOME/Library/Developer/Xcode/DerivedData/MailAssistant-*/Build/Products/Debug"
fi

echo "📦 Build Products:"
echo "  Looking in: $BUILD_DIR"
echo ""

# Check for built products
APP_PATH=$(find "$SCRIPT_DIR" -name "MailAssistant.app" -type d 2>/dev/null | head -1)

if [ -n "$APP_PATH" ]; then
    echo -e "${GREEN}✅ Found: $APP_PATH${NC}"
    echo ""
    echo "📋 Next Steps:"
    echo "=============="
    echo ""
    echo "1. Install the app:"
    echo "   cp -R \"$APP_PATH\" /Applications/"
    echo ""
    echo "2. Enable the Mail Extension:"
    echo "   - Open Mail.app"
    echo "   - Go to Settings → Extensions"
    echo "   - Enable MailAssistant"
    echo ""
    echo "3. Run the app:"
    echo "   open /Applications/MailAssistant.app"
    echo ""
else
    echo -e "${YELLOW}⚠️  Could not find built app${NC}"
    echo "Check the build log for errors"
fi

echo ""
echo "📖 For detailed instructions, see INSTALL.md"
