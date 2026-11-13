#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../flatpak-src"
exec flatpak-builder --user --install --force-clean build-dir com.fanpilot.app.json "$@"
