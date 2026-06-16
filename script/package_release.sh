#!/usr/bin/env bash
set -euo pipefail

APP_NAME="CodexSkillManager"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${VERSION:-$(git -C "$ROOT_DIR" describe --tags --always --dirty 2>/dev/null || echo 0.1.0)}"
VERSION="${VERSION#v}"
DIST_DIR="$ROOT_DIR/dist"
RELEASE_DIR="$DIST_DIR/release"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
ZIP_PATH="$RELEASE_DIR/$APP_NAME-$VERSION-macos.zip"
CHECKSUM_PATH="$ZIP_PATH.sha256"

rm -rf "$RELEASE_DIR"
mkdir -p "$RELEASE_DIR"

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

CONFIGURATION=release VERSION="$VERSION" "$ROOT_DIR/script/stage_app.sh"

if command -v codesign >/dev/null 2>&1; then
  codesign --force --deep --sign - "$APP_BUNDLE"
  codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
fi

rm -f "$ZIP_PATH" "$CHECKSUM_PATH"
/usr/bin/ditto -c -k --keepParent "$APP_BUNDLE" "$ZIP_PATH"

shasum -a 256 "$ZIP_PATH" | tee "$CHECKSUM_PATH"

echo "Created $ZIP_PATH"
echo "Created $CHECKSUM_PATH"
