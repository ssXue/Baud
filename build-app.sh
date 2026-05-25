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
mkdir -p "$APP_BUNDLE/Contents/Frameworks"
mkdir -p "$APP_BUNDLE/Contents/Resources/en.lproj"
mkdir -p "$APP_BUNDLE/Contents/Resources/zh-Hans.lproj"

cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/"
cp "Baud/App/Info.plist" "$APP_BUNDLE/Contents/"
cp "$BUILD_DIR/${APP_NAME}_BaudKit.bundle/en.lproj/Localizable.strings" "$APP_BUNDLE/Contents/Resources/en.lproj/"
cp "$BUILD_DIR/${APP_NAME}_BaudKit.bundle/zh-Hans.lproj/Localizable.strings" "$APP_BUNDLE/Contents/Resources/zh-Hans.lproj/"
cp "Baud/App/Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/"

SPARKLE_FRAMEWORK="$BUILD_DIR/Sparkle.framework"
if [ -d "$SPARKLE_FRAMEWORK" ]; then
    cp -R "$SPARKLE_FRAMEWORK" "$APP_BUNDLE/Contents/Frameworks/"
    install_name_tool -add_rpath "@loader_path/../Frameworks" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
    codesign --force --deep --sign - "$APP_BUNDLE"
    echo "Sparkle.framework copied to app bundle"
fi

if [[ "$1" == "--run" ]]; then
    echo "Launching..."
    open "$APP_BUNDLE"
else
    echo "Done: $APP_BUNDLE"
fi
