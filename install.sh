#!/bin/bash

# MailAssistantService Installation Script
# This script builds and installs MailAssistantService

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}"
echo "╔══════════════════════════════════════════════════════════╗"
echo "║     MailAssistantService Installation Script             ║"
echo "║     AI-Powered Email Assistant for macOS Mail            ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""

# Configuration
PROJECT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
APP_NAME="MailAssistant"
BUNDLE_ID="de.rabitem.MailAssistant"

echo "📂 Project Directory: $PROJECT_DIR"
echo ""

# Check prerequisites
echo "🔍 Checking Prerequisites..."
echo "============================"

# Check macOS version
MACOS_MAJOR=$(sw_vers -productVersion | cut -d. -f1)
if [ "$MACOS_MAJOR" -lt 14 ]; then
    echo -e "${RED}❌ Error: macOS 14.0+ required${NC}"
    exit 1
fi
echo -e "${GREEN}✅ macOS version OK${NC}"

# Check Xcode
if ! command -v xcodebuild &> /dev/null; then
    echo -e "${RED}❌ Error: Xcode not installed${NC}"
    echo "Install from: https://apps.apple.com/us/app/xcode/id497799835"
    exit 1
fi

XCODE_VERSION=$(xcodebuild -version | head -n 1 | sed 's/Xcode //')
echo -e "${GREEN}✅ Xcode $XCODE_VERSION found${NC}"

# Check for Apple Developer Team
TEAM_ID=$(security find-identity -v -p codesigning 2>/dev/null | grep "Apple Development" | head -1 | awk '{print $3}' | tr -d '()')
if [ -z "$TEAM_ID" ]; then
    echo -e "${YELLOW}⚠️  Warning: No Apple Developer certificate found${NC}"
    echo "   You'll need to set up code signing in Xcode manually"
else
    echo -e "${GREEN}✅ Apple Developer certificate found${NC}"
fi

echo ""

# Ask user if they want to proceed
echo -e "${YELLOW}This will build and install MailAssistantService${NC}"
echo "The app will be installed to /Applications/"
echo ""
read -p "Continue? (y/n) " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Installation cancelled"
    exit 0
fi

echo ""
echo "🏗️  Building Project..."
echo "======================="
cd "$PROJECT_DIR"

# Clean previous builds
echo "🧹 Cleaning..."
xcodebuild -project MailAssistant.xcodeproj clean 2>/dev/null || true

# Build the aggregate target
echo "🔨 Building all targets..."
if ! xcodebuild -project MailAssistant.xcodeproj \
                 -scheme "MailAssistant-All" \
                 -configuration Release \
                 -destination 'platform=macOS' \
                 build; then
    echo -e "${RED}❌ Build failed!${NC}"
    echo ""
    echo "Common fixes:"
    echo "1. Open MailAssistant.xcodeproj in Xcode"
    echo "2. Set your Development Team in Signing & Capabilities"
    echo "3. Try building manually in Xcode first"
    exit 1
fi

echo -e "${GREEN}✅ Build successful!${NC}"
echo ""

# Find the built app
echo "📦 Locating Build Products..."
echo "=============================="

# Try to find the built app
APP_PATH=$(find "$PROJECT_DIR" -name "MailAssistant.app" -type d 2>/dev/null | head -1)

if [ -z "$APP_PATH" ]; then
    # Try DerivedData
    DERIVED_DATA="$HOME/Library/Developer/Xcode/DerivedData"
    APP_PATH=$(find "$DERIVED_DATA" -name "MailAssistant.app" -type d -mmin -10 2>/dev/null | head -1)
fi

if [ -z "$APP_PATH" ]; then
    echo -e "${RED}❌ Could not find built app${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Found app at: $APP_PATH${NC}"
echo ""

# Install the app
echo "📲 Installing Application..."
echo "============================="

# Remove old version if exists
if [ -d "/Applications/MailAssistant.app" ]; then
    echo "🗑️  Removing old version..."
    rm -rf "/Applications/MailAssistant.app"
fi

# Copy new version
echo "📋 Copying to Applications..."
cp -R "$APP_PATH" /Applications/

if [ ! -d "/Applications/MailAssistant.app" ]; then
    echo -e "${RED}❌ Installation failed${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Installed to /Applications/MailAssistant.app${NC}"
echo ""

# Post-installation steps
echo "📋 Post-Installation Setup"
echo "=========================="
echo ""

echo "1. 🔐 Granting Permissions..."
echo "   You'll need to grant these permissions when prompted:"
echo "   • Full Disk Access (for email import)"
echo "   • Accessibility (optional, for enhanced UI)"
echo ""

echo "2. 📧 Enabling Mail Extension..."
echo "   a) Open Mail.app"
echo "   b) Go to Mail → Settings → Extensions"
echo "   c) Check 'MailAssistant'"
echo "   d) Restart Mail.app"
echo ""

echo "3. 🚀 Launching App..."
open /Applications/MailAssistant.app
echo -e "${GREEN}✅ App launched${NC}"
echo ""

# Create uninstall script
cat > /Applications/MailAssistant.app/Contents/Resources/uninstall.sh << 'EOF'
#!/bin/bash
echo "Uninstalling MailAssistant..."
# Remove app
rm -rf "/Applications/MailAssistant.app"
# Remove preferences
defaults delete de.rabitem.MailAssistant 2>/dev/null || true
# Remove data
rm -rf "$HOME/Library/Application Support/MailAssistant"
echo "Uninstall complete"
EOF
chmod +x /Applications/MailAssistant.app/Contents/Resources/uninstall.sh 2>/dev/null || true

echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  🎉 Installation Complete!                               ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "📖 Quick Start:"
echo "==============="
echo "1. Complete onboarding in the app"
echo "2. Add your Kimi API key in Settings → AI Provider"
echo "3. Open Mail.app and compose a new email"
echo "4. Press ⌘⇧G to generate AI suggestions"
echo ""
echo "📚 Documentation:"
echo "   • INSTALL.md - Detailed installation guide"
echo "   • PLAN.md - Architecture overview"
echo ""
echo "🆘 Support:"
echo "   • Logs: ~/Library/Logs/MailAssistant/"
echo "   • Console.app - for debugging"
echo ""
