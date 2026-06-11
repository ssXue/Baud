#!/bin/bash
set -e

APP_NAME="Baud"
VERSION="${1:-1.0.0}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR=".build/arm64-apple-macosx/release"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
DIST_DIR="dist"
DMG_NAME="Baud-${VERSION}"
DMG_DIR="$SCRIPT_DIR/$DIST_DIR"
DMG_PATH="$DMG_DIR/${DMG_NAME}.dmg"

echo "=== Building Baud ${VERSION} (release) ==="
swift build -c release

echo "=== Creating .app bundle ==="
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Frameworks"
mkdir -p "$APP_BUNDLE/Contents/Resources/en.lproj"
mkdir -p "$APP_BUNDLE/Contents/Resources/zh-Hans.lproj"

cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/"
cp "Baud/App/Info.plist" "$APP_BUNDLE/Contents/"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP_BUNDLE/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $(git rev-list --count HEAD)" "$APP_BUNDLE/Contents/Info.plist"

# Copy BaudKit resource bundle (required for Bundle.module localization lookups)
KIT_BUNDLE="$BUILD_DIR/${APP_NAME}_BaudKit.bundle"
if [ -d "$KIT_BUNDLE" ]; then
    cp -R "$KIT_BUNDLE" "$APP_BUNDLE/Contents/Resources/"
fi

# Also copy lproj directories to app Resources for Bundle.main lookups
if [ -d "$KIT_BUNDLE/en.lproj" ]; then
    cp "$KIT_BUNDLE/en.lproj/Localizable.strings" "$APP_BUNDLE/Contents/Resources/en.lproj/"
fi
if [ -d "$KIT_BUNDLE/zh-Hans.lproj" ]; then
    cp "$KIT_BUNDLE/zh-Hans.lproj/Localizable.strings" "$APP_BUNDLE/Contents/Resources/zh-Hans.lproj/"
elif [ -d "$KIT_BUNDLE/zh-hans.lproj" ]; then
    cp "$KIT_BUNDLE/zh-hans.lproj/Localizable.strings" "$APP_BUNDLE/Contents/Resources/zh-Hans.lproj/"
fi
cp "Baud/App/Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/"

# Convert .strings files from text plist to binary plist (required for runtime localization)
python3 - <<'PY'
import re, plistlib, glob

def convert_strings(path):
    try:
        with open(path, 'r', encoding='utf-8') as f:
            content = f.read()
    except UnicodeDecodeError:
        return
    d = {}
    for line in content.split('\n'):
        line = line.strip()
        if not line or line.startswith('/*') or line.startswith('//'):
            continue
        m = re.match(r'^"((?:[^"\\]|\\.)*)"\s*=\s*"((?:[^"\\]|\\.)*)"\s*;$', line)
        if m:
            d[m.group(1)] = m.group(2)
    if d:
        with open(path, 'wb') as f:
            plistlib.dump(d, f, fmt=plistlib.FMT_BINARY)

for f in glob.glob(".build/arm64-apple-macosx/release/Baud.app/**/*.strings", recursive=True):
    convert_strings(f)
PY

SPARKLE_FRAMEWORK="$BUILD_DIR/Sparkle.framework"
if [ -d "$SPARKLE_FRAMEWORK" ]; then
    cp -R "$SPARKLE_FRAMEWORK" "$APP_BUNDLE/Contents/Frameworks/"
    install_name_tool -add_rpath "@loader_path/../Frameworks" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
    codesign --force --deep --sign - "$APP_BUNDLE"
    echo "Sparkle.framework copied to app bundle"
fi

echo "=== Creating DMG ==="
rm -rf "$DMG_DIR"
mkdir -p "$DMG_DIR"

DMG_STAGING="$DMG_DIR/staging"
mkdir -p "$DMG_STAGING"
cp -R "$APP_BUNDLE" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"

hdiutil create -volname "$DMG_NAME" \
  -srcfolder "$DMG_STAGING" \
  -ov -format UDZO \
  -imagekey zlib-level=9 \
  "$DMG_PATH"

rm -rf "$DMG_STAGING"

echo "=== Done: $DMG_PATH ($(du -h "$DMG_PATH" | cut -f1)) ==="
