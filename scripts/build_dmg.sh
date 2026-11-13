#!/usr/bin/env bash
set -e

# Change directory to project root
cd "$(dirname "$0")/.."

echo "🔨 Ensuring Wizit.app is built..."
./scripts/build_app.sh

if [ ! -d "Wizit.app" ]; then
    echo "❌ Error: Wizit.app not found!"
    exit 1
fi

DMG_NAME="Wizit.dmg"
STAGING_DIR=".dmg_staging"

echo "📦 Preparing DMG staging directory..."
rm -rf "$STAGING_DIR" "$DMG_NAME"
mkdir -p "$STAGING_DIR"

# Copy App to staging
echo "📋 Copying Wizit.app..."
cp -R "Wizit.app" "$STAGING_DIR/Wizit.app"

# Create /Applications symlink for drag-and-drop installation
echo "🔗 Creating /Applications symlink..."
ln -s /Applications "$STAGING_DIR/Applications"

# Build DMG using hdiutil
echo "💽 Creating compressed DMG: $DMG_NAME..."
hdiutil create \
    -volname "Wizit" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    "$DMG_NAME"

# Clean up staging directory
rm -rf "$STAGING_DIR"

echo "✅ DMG built successfully: $DMG_NAME"
ls -lh "$DMG_NAME"
shasum -a 256 "$DMG_NAME"
