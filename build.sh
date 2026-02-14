#!/bin/bash
set -e

echo "🔨 Building MacVMApp..."
swift build -c release

echo "📝 Signing with entitlements..."
codesign --force --sign - --entitlements MacVMApp.entitlements .build/release/MacVMApp

echo "📦 Creating app bundle..."
APP_DIR=".build/MacVM.app"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp .build/release/MacVMApp "$APP_DIR/Contents/MacOS/MacVM"
cp Sources/Info.plist "$APP_DIR/Contents/"
cp Sources/AppIcon.icns "$APP_DIR/Contents/Resources/"

# Sign the app bundle
codesign --force --sign - --entitlements MacVMApp.entitlements "$APP_DIR"

echo "✅ Done! App bundle at: $APP_DIR"
echo ""
echo "To run: open $APP_DIR"
echo "Or:     $APP_DIR/Contents/MacOS/MacVM"
