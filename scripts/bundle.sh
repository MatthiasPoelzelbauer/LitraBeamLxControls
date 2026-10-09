#!/bin/zsh
# Builds build/LitraApp.app from the Swift package.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release
app=build/LitraApp.app
rm -rf "$app"
mkdir -p "$app/Contents/MacOS"
cp .build/release/LitraApp "$app/Contents/MacOS/"
cp Resources/Info.plist "$app/Contents/"
codesign --force --sign - "$app"
echo "Built $app"
