#!/usr/bin/env bash
set -euo pipefail
R="$(cd "$(dirname "$0")/.." && pwd)"
rm -rf "$R/flatpak-src/build-dir" "$R/flatpak-src/.flatpak-builder"
rm -rf "$R/fan-control/node_modules" "$R/fan-control/src-tauri/target" "$R/fan-control/dist"
echo "[✓] Caches nettoyés."
