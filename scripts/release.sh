#!/bin/bash
# Builds a universal ZenPad release into dist/:
#   ZenPad-<version>.dmg        drag-to-Applications installer
#   ZenPad-<version>.zip        what the in-app updater downloads
#   ZenPad-<version>.zip.sig    Ed25519 signature of the zip (checked by the updater)
#   SHA256SUMS.txt
#
#   scripts/release.sh             build only
#   scripts/release.sh --publish   build, then create the GitHub release v<version> with notes from CHANGELOG.md
#
# Needs: Xcode, xcodegen, create-dmg (brew install xcodegen create-dmg), gh for --publish,
# and the update signing key (~/.config/zenpad/update_signing_key or $ZENPAD_UPDATE_PRIVATE_KEY).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

PUBLISH=0
[ "${1:-}" = "--publish" ] && PUBLISH=1

VERSION=$(awk -F'"' '/MARKETING_VERSION/ {print $2; exit}' project.yml)
BUILD_DIR="$ROOT/build/release"
DIST="$ROOT/dist"
APP="$BUILD_DIR/Build/Products/Release/ZenPad.app"
NAME="ZenPad-$VERSION"

step() { printf "\n\033[1m==> %s\033[0m\n" "$1"; }

step "ZenPad $VERSION"
for tool in xcodegen create-dmg; do
  command -v "$tool" >/dev/null || { echo "Missing $tool (brew install $tool)" >&2; exit 1; }
done
swift scripts/update_keys.swift public >/dev/null || { echo "No update signing key; see scripts/update_keys.swift" >&2; exit 1; }

step "Generating project"
xcodegen generate --quiet

step "Running tests"
xcodebuild -project ZenPad.xcodeproj -scheme ZenPad -derivedDataPath "$BUILD_DIR" test -quiet

step "Building universal Release"
rm -rf "$BUILD_DIR/Build/Products/Release"
xcodebuild -project ZenPad.xcodeproj -scheme ZenPad -configuration Release \
  -derivedDataPath "$BUILD_DIR" ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO build -quiet
lipo -info "$APP/Contents/MacOS/ZenPad"
codesign --verify --deep --strict "$APP"
BUILT_VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP/Contents/Info.plist")
[ "$BUILT_VERSION" = "$VERSION" ] || { echo "Built version $BUILT_VERSION != $VERSION" >&2; exit 1; }

rm -rf "$DIST"
mkdir -p "$DIST"

step "Packaging update zip"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$DIST/$NAME.zip"
swift scripts/update_keys.swift sign "$DIST/$NAME.zip" > "$DIST/$NAME.zip.sig"

step "Building DMG"
STAGE=$(mktemp -d)
cp -R "$APP" "$STAGE/"
tiffutil -cathidpicheck docs/art/dmg-background.png docs/art/dmg-background@2x.png -out "$STAGE/background.tiff" 2>/dev/null
create-dmg \
  --volname "ZenPad $VERSION" \
  --volicon "$APP/Contents/Resources/AppIcon.icns" \
  --background "$STAGE/background.tiff" \
  --window-pos 200 160 \
  --window-size 660 428 \
  --icon-size 128 \
  --text-size 13 \
  --icon "ZenPad.app" 170 170 \
  --hide-extension "ZenPad.app" \
  --app-drop-link 490 170 \
  --no-internet-enable \
  "$DIST/$NAME.dmg" \
  "$STAGE/ZenPad.app" >/dev/null
rm -rf "$STAGE"
codesign --force --sign - "$DIST/$NAME.dmg"
hdiutil verify "$DIST/$NAME.dmg" >/dev/null

(cd "$DIST" && shasum -a 256 "$NAME.dmg" "$NAME.zip" > SHA256SUMS.txt)

step "Artifacts"
ls -lh "$DIST"

if [ "$PUBLISH" = 1 ]; then
  step "Publishing v$VERSION to GitHub"
  NOTES=$(mktemp)
  # The section of CHANGELOG.md for this version, without its heading.
  awk -v v="$VERSION" '
    $0 ~ "^## \\[" v "\\]" { found = 1; next }
    found && /^## \[/ { exit }
    found { print }
  ' CHANGELOG.md > "$NOTES"
  [ -s "$NOTES" ] || { echo "No CHANGELOG.md section for $VERSION" >&2; exit 1; }
  ASSETS=("$DIST/$NAME.dmg" "$DIST/$NAME.zip" "$DIST/$NAME.zip.sig" "$DIST/SHA256SUMS.txt")
  if gh release view "v$VERSION" >/dev/null 2>&1; then
    # Already published (for example by CI): refresh the files and notes.
    gh release upload "v$VERSION" "${ASSETS[@]}" --clobber
    gh release edit "v$VERSION" --notes-file "$NOTES"
  else
    gh release create "v$VERSION" --title "ZenPad $VERSION" --notes-file "$NOTES" "${ASSETS[@]}"
  fi
  rm -f "$NOTES"
fi
