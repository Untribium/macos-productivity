#!/usr/bin/env bash
# build-app.sh — build OverlaySpike and wrap it in an .app bundle.
#
#   overlay/scripts/build-app.sh            # → overlay/build/OverlaySpike.app
#   overlay/scripts/build-app.sh --install  # also copy to ~/Applications and launch
#
# Signed ad hoc. Built on the machine it runs on, so it carries no quarantine
# flag and Gatekeeper does not assess it (docs/verification/*-overlay-env-*.md).
# Needs no admin rights.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NAME=OverlaySpike
APP="$ROOT/build/$NAME.app"

INSTALL=0
[[ "${1:-}" == "--install" ]] && INSTALL=1

swift build --package-path "$ROOT" -c release --product "$NAME"
BIN="$(swift build --package-path "$ROOT" -c release --show-bin-path)/$NAME"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/$NAME"
cp "$ROOT/app/Info.plist" "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"
echo "built $APP"

if (( INSTALL )); then
  DEST="$HOME/Applications/$NAME.app"
  pkill -x "$NAME" || true
  mkdir -p "$HOME/Applications"
  rm -rf "$DEST"
  cp -R "$APP" "$DEST"
  open "$DEST"
  echo "installed and launched $DEST"
fi
