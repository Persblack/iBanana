#!/bin/bash
# Build a release iBanana.app bundle, ad-hoc sign it, install to /Applications.
# Usage: scripts/make-app.sh
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release
BIN=".build/release/iBanana"
APP="$(mktemp -d)/iBanana.app"

mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/iBanana"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>iBanana</string>
    <key>CFBundleDisplayName</key><string>iBanana</string>
    <key>CFBundleIdentifier</key><string>com.ricoklatte.iBanana</string>
    <key>CFBundleExecutable</key><string>iBanana</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHumanReadableCopyright</key><string>Rico Klatte</string>
</dict>
</plist>
PLIST

# Ad-hoc sign so the Keychain grants a stable code identity (needed for the
# biometric-gated master key). Re-signs on every rebuild.
codesign --force --sign - "$APP"

# Replace any previous install.
rm -rf /Applications/iBanana.app
cp -R "$APP" /Applications/iBanana.app
echo "Installed /Applications/iBanana.app"
