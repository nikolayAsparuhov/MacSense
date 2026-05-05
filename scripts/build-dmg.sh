#!/usr/bin/env bash
#
# Build a distributable DMG of MacSense.
#
# Requires:
#   brew install create-dmg
#   (optional) Developer ID Application certificate in your Keychain
#
# Output:
#   dist/MacSense-<version>.dmg
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SCHEME="MacSense"
PROJECT="MacSense.xcodeproj"
CONFIG="Release"
VERSION="$(grep -m1 'MARKETING_VERSION' "$PROJECT/project.pbxproj" | sed -E 's/.*= ([^;]+);/\1/' | tr -d ' ')"
[ -z "$VERSION" ] && VERSION="0.0.0"
DIST="$ROOT/dist"
ARCHIVE="$DIST/MacSense.xcarchive"
EXPORT="$DIST/export"
APP="$EXPORT/$SCHEME.app"
DMG="$DIST/$SCHEME-$VERSION.dmg"

DEV_ID="${DEV_ID:-}"   # Optional: "Developer ID Application: Your Name (TEAMID)"

echo "→ MacSense $VERSION"
rm -rf "$DIST"
mkdir -p "$EXPORT"

echo "→ Archiving"
if [ -n "$DEV_ID" ]; then
    xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration "$CONFIG" \
               -archivePath "$ARCHIVE" \
               -destination 'generic/platform=macOS' \
               archive
else
    # Ad-hoc sign for unsigned test builds — no Apple Developer cert required.
    xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration "$CONFIG" \
               -archivePath "$ARCHIVE" \
               -destination 'generic/platform=macOS' \
               CODE_SIGN_IDENTITY="-" \
               CODE_SIGN_STYLE=Manual \
               DEVELOPMENT_TEAM="" \
               PROVISIONING_PROFILE_SPECIFIER="" \
               archive
fi

# Export the .app from the archive. Skips signing if DEV_ID is empty.
if [ -n "$DEV_ID" ]; then
    cat > "$DIST/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key><string>developer-id</string>
    <key>signingStyle</key><string>manual</string>
    <key>signingCertificate</key><string>$DEV_ID</string>
</dict>
</plist>
PLIST
    xcodebuild -exportArchive -archivePath "$ARCHIVE" \
               -exportPath "$EXPORT" \
               -exportOptionsPlist "$DIST/ExportOptions.plist"
else
    echo "→ DEV_ID not set, copying unsigned .app from archive"
    cp -R "$ARCHIVE/Products/Applications/$SCHEME.app" "$EXPORT/"
fi

# Create the DMG with the standard layout: app icon on left,
# /Applications symlink on right, drag arrow background.
echo "→ Creating DMG"
if ! command -v create-dmg >/dev/null 2>&1; then
    echo "create-dmg not installed. Run: brew install create-dmg" >&2
    exit 1
fi

DMG_FLAGS=(
    --volname "$SCHEME $VERSION"
    --window-pos 200 120
    --window-size 600 400
    --icon-size 110
    --icon "$SCHEME.app" 150 200
    --hide-extension "$SCHEME.app"
    --app-drop-link 450 200
    --no-internet-enable
)

# Optional polish — drop these into Resources/ to use them
[ -f "$ROOT/Resources/dmg-volume.icns" ] && DMG_FLAGS+=(--volicon "$ROOT/Resources/dmg-volume.icns")
[ -f "$ROOT/Resources/dmg-background.png" ] && DMG_FLAGS+=(--background "$ROOT/Resources/dmg-background.png")

create-dmg "${DMG_FLAGS[@]}" "$DMG" "$APP"

if [ -n "$DEV_ID" ]; then
    echo "→ Signing DMG"
    codesign --sign "$DEV_ID" "$DMG"
fi

echo
echo "✓ Built: $DMG"
echo "  Size:  $(du -h "$DMG" | cut -f1)"
echo
[ -n "$DEV_ID" ] && cat <<NOTE
Next: notarize the DMG so Gatekeeper accepts it on other Macs.
    xcrun notarytool submit "$DMG" \\
        --keychain-profile "AC_PROFILE" --wait
    xcrun stapler staple "$DMG"
NOTE
