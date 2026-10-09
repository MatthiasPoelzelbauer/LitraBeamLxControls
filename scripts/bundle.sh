#!/bin/zsh
# Builds "build/Litra Beam LX.app" from the Swift package.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release
app="build/Litra Beam LX.app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp .build/release/LitraApp "$app/Contents/MacOS/"
cp Resources/Info.plist "$app/Contents/"
cp Resources/AppIcon.icns "$app/Contents/Resources/"
codesign --force --sign - "$app"
echo "Built $app"
