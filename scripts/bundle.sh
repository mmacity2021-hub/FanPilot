#!/usr/bin/env bash
set -euo pipefail
R="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-$R/FanPilot.flatpak}"
flatpak build-bundle ~/.local/share/flatpak/repo "$OUT" com.fanpilot.app master
echo "[✓] Bundle : $OUT"
