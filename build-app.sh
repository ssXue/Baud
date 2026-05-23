#!/bin/bash
set -e

APP_NAME="Baud"
BUILD_DIR=".build/arm64-apple-macosx/debug"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"

echo "Building..."
swift build

echo "Creating .app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources/en.lproj"
mkdir -p "$APP_BUNDLE/Contents/Resources/zh-Hans.lproj"

cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/"
cp "Baud/App/Info.plist" "$APP_BUNDLE/Contents/"
cp "$BUILD_DIR/${APP_NAME}_BaudKit.bundle/en.lproj/Localizable.strings" "$APP_BUNDLE/Contents/Resources/en.lproj/"
cp "$BUILD_DIR/${APP_NAME}_BaudKit.bundle/zh-Hans.lproj/Localizable.strings" "$APP_BUNDLE/Contents/Resources/zh-Hans.lproj/"
cp "Baud/App/Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/"

if [[ "$1" == "--run" ]]; then
    echo "Launching..."
    open "$APP_BUNDLE"
else
    echo "Done: $APP_BUNDLE"
fi
