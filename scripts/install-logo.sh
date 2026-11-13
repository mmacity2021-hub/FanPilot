#!/usr/bin/env bash
set -euo pipefail
R="$(cd "$(dirname "$0")/.." && pwd)"
LOGO="${1:-$R/assets/logo-source.png}"
[ -f "$LOGO" ] || { echo "[✗] Logo introuvable : $LOGO"; exit 1; }
cd "$R/fan-control/src-tauri"
if [ -x "node_modules/.bin/tauri" ]; then
  node_modules/.bin/tauri icon "$LOGO" --output icons
else
  npx --yes @tauri-apps/cli icon "$LOGO" --output icons
fi
exec "$R/scripts/build-flatpak.sh"
