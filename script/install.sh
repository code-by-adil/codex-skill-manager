#!/usr/bin/env bash
set -euo pipefail

APP_NAME="CodexSkillManager"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL_DIR="$HOME/Applications"
LAUNCH_AFTER_INSTALL=1

usage() {
  cat >&2 <<USAGE
usage: $0 [--user|--system] [--no-launch]

Options:
  --user       Install to ~/Applications (default, no sudo)
  --system     Install to /Applications
  --no-launch  Do not launch after installing
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --user)
      INSTALL_DIR="$HOME/Applications"
      ;;
    --system)
      INSTALL_DIR="/Applications"
      ;;
    --no-launch)
      LAUNCH_AFTER_INSTALL=0
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage
      exit 2
      ;;
  esac
  shift
done

APP_BUNDLE="$ROOT_DIR/dist/$APP_NAME.app"
DESTINATION="$INSTALL_DIR/$APP_NAME.app"

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

CONFIGURATION=release "$ROOT_DIR/script/stage_app.sh"

mkdir -p "$INSTALL_DIR"
rm -rf "$DESTINATION"
/usr/bin/ditto "$APP_BUNDLE" "$DESTINATION"

if command -v xattr >/dev/null 2>&1; then
  xattr -dr com.apple.quarantine "$DESTINATION" >/dev/null 2>&1 || true
fi

echo "Installed $DESTINATION"

if [[ "$LAUNCH_AFTER_INSTALL" -eq 1 ]]; then
  /usr/bin/open "$DESTINATION"
fi
