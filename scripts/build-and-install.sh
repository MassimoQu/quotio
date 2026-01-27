#!/bin/bash

# Quotio Build and Install Script
# Builds Quotio with new features and installs to /Applications/

set -e

echo "=========================================="
echo "  Quotio Build & Install Script"
echo "=========================================="
echo ""

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${GREEN}[✓]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
print_step() { echo -e "${BLUE}[→]${NC} $1"; }

# Check Homebrew
print_step "Checking Homebrew..."
if ! command -v brew &> /dev/null; then
    print_warning "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
print_status "Homebrew ready"

# Check Xcode
print_step "Checking Xcode..."
if ! command -v xcodebuild &> /dev/null; then
    echo -e "${RED}[✗]${NC} Xcode not installed!"
    echo "Please install from App Store first"
    exit 1
fi
xcodebuild -version
print_status "Xcode ready"

# Check XcodeGen
print_step "Checking XcodeGen..."
if ! command -v xcodegen &> /dev/null; then
    print_warning "Installing XcodeGen..."
    brew install xcodegen
fi
print_status "XcodeGen ready"

# Navigate to project
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$( dirname "$SCRIPT_DIR" )"
print_status "Project: $(pwd)"

# Build
echo ""
print_step "Building Quotio (this may take several minutes)..."
xcodebuild -project Quotio.xcodeproj -scheme Quotio -configuration Release \
    -destination "platform=macOS" build \
    CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGN_ENTITLEMENTS="" \
    2>&1 | grep -E "(Build|error:|warning:)" || true

# Find app
print_step "Finding built app..."
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "Quotio.app" -type d 2>/dev/null | head -1)
if [ -z "$APP_PATH" ]; then
    echo "Build failed - could not find Quotio.app"
    exit 1
fi
print_status "Found: $APP_PATH"

# Install
echo ""
print_step "Installing to /Applications/..."

# If old version exists, move it aside
if [ -d "/Applications/Quotio.app" ]; then
    BACKUP_NAME="Quotio_old_$(date +%Y%m%d_%H%M%S).app"
    echo "Moving old version to Desktop/$BACKUP_NAME"
    mv "/Applications/Quotio.app" "$HOME/Desktop/$BACKUP_NAME"
fi

# Install new version
cp -R "$APP_PATH" "/Applications/Quotio.app"
chmod +x "/Applications/Quotio.app/Contents/MacOS/Quotio"

echo ""
echo "=========================================="
echo "  ✓ Installation Complete!"
echo "=========================================="
echo ""
echo "New Features:"
echo "  ✨ Smart Model Selection (refresh frequency aware)"
echo "  📊 Usage Tracking with charts and analytics"
echo ""
echo "To use: Open /Applications/Quotio.app"
echo "Usage screen: Click menu bar icon → 'Usage'"
echo ""

