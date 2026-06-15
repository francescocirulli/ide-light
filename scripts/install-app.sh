#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Code Light.app"
SOURCE_APP="$ROOT_DIR/dist/$APP_NAME"
CLI_SOURCE="$ROOT_DIR/scripts/code-light"

if [ -w /Applications ]; then
  INSTALL_DIR="/Applications"
else
  INSTALL_DIR="$HOME/Applications"
  mkdir -p "$INSTALL_DIR"
fi

"$ROOT_DIR/scripts/build-app.sh"

rm -rf "$INSTALL_DIR/$APP_NAME"
ditto "$SOURCE_APP" "$INSTALL_DIR/$APP_NAME"

LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
if [ -x "$LSREGISTER" ]; then
  "$LSREGISTER" -f "$INSTALL_DIR/$APP_NAME" >/dev/null 2>&1 || true
fi

touch "$INSTALL_DIR/$APP_NAME"

if [ -d /usr/local/bin ] && [ -w /usr/local/bin ]; then
  CLI_DIR="/usr/local/bin"
else
  CLI_DIR="$HOME/.local/bin"
  mkdir -p "$CLI_DIR"
fi

cp "$CLI_SOURCE" "$CLI_DIR/code-light"
chmod +x "$CLI_DIR/code-light"

echo "Installed: $INSTALL_DIR/$APP_NAME"
echo "Command:   $CLI_DIR/code-light"
