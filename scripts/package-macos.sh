#!/bin/zsh

set -euo pipefail
setopt null_glob

ROOT_DIR=${0:A:h:h}
APP_NAME=${APP_NAME:-Palette}
CONFIGURATION=${CONFIGURATION:-release}
DIST_DIR=${DIST_DIR:-"$ROOT_DIR/dist"}
BUILD_DIR="$ROOT_DIR/.build/$CONFIGURATION"
APP_DIR="$DIST_DIR/$APP_NAME.app"
DMG_STAGE_DIR="$DIST_DIR/dmg"
DMG_PATH="$DIST_DIR/$APP_NAME.dmg"
VOLUME_NAME=${VOLUME_NAME:-"$APP_NAME Installer"}

rm -rf "$APP_DIR" "$DMG_STAGE_DIR" "$DMG_PATH"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources" "$DMG_STAGE_DIR"

swift build --configuration "$CONFIGURATION"

cp "$BUILD_DIR/$APP_NAME" "$APP_DIR/Contents/MacOS/$APP_NAME"
chmod 755 "$APP_DIR/Contents/MacOS/$APP_NAME"
cp "$ROOT_DIR/Sources/Palette/Info.plist" "$APP_DIR/Contents/Info.plist"

resource_bundles=("$BUILD_DIR"/*.bundle(N/))
for resource_bundle in $resource_bundles; do
    cp -R "$resource_bundle" "$APP_DIR/Contents/Resources/"
done

ln -s /Applications "$DMG_STAGE_DIR/Applications"
cp -R "$APP_DIR" "$DMG_STAGE_DIR/$APP_NAME.app"

hdiutil create \
    -volname "$VOLUME_NAME" \
    -srcfolder "$DMG_STAGE_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

print "Created $DMG_PATH"
