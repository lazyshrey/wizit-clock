#!/usr/bin/env bash
set -e

echo "✨ Building Wizit in Release mode..."
swift build -c release

# Locate release binary
RELEASE_BIN=$(find .build -name "Wizit" -type f -perm +111 | grep -i "release" | head -n 1)

if [ -z "$RELEASE_BIN" ]; then
    echo "❌ Error: Could not locate built release binary."
    exit 1
fi

echo "📦 Creating Wizit.app bundle..."
APP_DIR="Wizit.app"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

# Copy executable
cp "$RELEASE_BIN" "$APP_DIR/Contents/MacOS/Wizit"
chmod +x "$APP_DIR/Contents/MacOS/Wizit"

# Generate Info.plist
cat << 'EOF' > "$APP_DIR/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Wizit</string>
    <key>CFBundleIdentifier</key>
    <string>com.shrey.wizit</string>
    <key>CFBundleName</key>
    <string>Wizit</string>
    <key>CFBundleDisplayName</key>
    <string>Wizit</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026. All rights reserved.</string>
</dict>
</plist>
EOF

echo "✅ Successfully built $APP_DIR!"
echo "🚀 You can launch it with: open $APP_DIR"
