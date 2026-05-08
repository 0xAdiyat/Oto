#!/usr/bin/env bash
# Builds Oto in Release config, ad-hoc signs it, and produces a shareable zip in ./dist/
#
# Usage:  ./scripts/build-release.sh
# Output: dist/Oto.app  and  dist/Oto.zip
set -euo pipefail

cd "$(dirname "$0")/.."
PROJECT_DIR="$PWD"
DIST_DIR="$PROJECT_DIR/dist"

echo "→ Building Release..."
xcodebuild \
  -project Oto.xcodeproj \
  -scheme Oto \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  clean build \
  | xcbeautify 2>/dev/null || true

# Locate the built .app via xcodebuild settings
BUILT_APP="$(xcodebuild -project Oto.xcodeproj -scheme Oto -configuration Release -showBuildSettings 2>/dev/null \
  | awk -F' = ' '/^[[:space:]]*BUILT_PRODUCTS_DIR/ { print $2; exit }')/Oto.app"

if [ ! -d "$BUILT_APP" ]; then
  echo "✗ Could not find built .app at: $BUILT_APP" >&2
  exit 1
fi

echo "→ Staging in dist/..."
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"
cp -R "$BUILT_APP" "$DIST_DIR/Oto.app"

echo "→ Stripping quarantine and ad-hoc signing..."
xattr -cr "$DIST_DIR/Oto.app"
codesign --force --deep --sign - "$DIST_DIR/Oto.app"

echo "→ Zipping with ditto (preserves resource forks + signature)..."
( cd "$DIST_DIR" && ditto -c -k --keepParent Oto.app Oto.zip )

echo "→ Building drag-and-drop DMG..."
DMG_STAGING="$DIST_DIR/dmg-staging"
rm -rf "$DMG_STAGING"
mkdir -p "$DMG_STAGING"
cp -R "$DIST_DIR/Oto.app" "$DMG_STAGING/Oto.app"
ln -s /Applications "$DMG_STAGING/Applications"
hdiutil create \
  -volname "Oto" \
  -srcfolder "$DMG_STAGING" \
  -ov \
  -format UDZO \
  "$DIST_DIR/Oto.dmg"
rm -rf "$DMG_STAGING"

echo
echo "✓ Done."
echo "  App: $DIST_DIR/Oto.app"
echo "  Zip: $DIST_DIR/Oto.zip"
echo "  DMG: $DIST_DIR/Oto.dmg"
echo
echo "To install: open dist/Oto.dmg → drag Oto to Applications."
echo "To share:   send dist/Oto.dmg. Recipient double-clicks, drags to Applications,"
echo "            and on first launch right-clicks → Open (one-time Gatekeeper bypass)."
