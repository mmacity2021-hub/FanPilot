#!/usr/bin/env bash
set -euo pipefail

cd /home/mo/Documents/0_FanPilot/0_FanPilot-github

echo "=== 1. Vérification de la structure ==="
if [ ! -d ".github/workflows" ]; then
  echo "[✗] Dossier .github/workflows introuvable. Es-tu dans le bon dossier ?"
  exit 1
fi

echo "=== 2. Correction du workflow CI (ajout des dépendances Linux Tauri) ==="
cat > .github/workflows/ci.yml <<'YAML_EOF'
name: CI

on:
  push:
    branches: [main]
  pull_request:

jobs:
  rust:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install system dependencies
        run: |
          sudo apt-get update
          sudo apt-get install -y libwebkit2gtk-4.1-dev \
            build-essential curl wget file libxdo-dev libssl-dev \
            libayatana-appindicator3-dev librsvg2-dev
      - uses: dtolnay/rust-toolchain@stable
        with:
          components: rustfmt, clippy
      - run: cargo fmt --all -- --check
        working-directory: fan-control/src-tauri
      - run: cargo clippy --all-targets -- -D warnings
        working-directory: fan-control/src-tauri

  frontend:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: npm
          cache-dependency-path: fan-control/package-lock.json
      - run: npm ci
        working-directory: fan-control
      - run: npm run build
        working-directory: fan-control
YAML_EOF

echo "=== 3. Correction du workflow Release (ajout des SDK Rust et Node) ==="
cat > .github/workflows/release.yml <<'YAML_EOF'
name: Release

on:
  push:
    tags: ["v*"]

permissions:
  contents: write

jobs:
  flatpak:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install Flatpak deps
        run: |
          sudo apt-get update
          sudo apt-get install -y flatpak flatpak-builder
          flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
          flatpak install --user -y flathub \
            org.gnome.Platform//48 \
            org.gnome.Sdk//48 \
            org.freedesktop.Sdk.Extension.rust-stable//24.08 \
            org.freedesktop.Sdk.Extension.node20//24.08
      - name: Build
        run: |
          cd flatpak-src
          flatpak-builder --user --force-clean --repo=repo --install-deps-from=flathub build-dir com.fanpilot.app.json
          flatpak build-bundle repo ../FanPilot.flatpak com.fanpilot.app master
      - uses: softprops/action-gh-release@v2
        with:
          files: FanPilot.flatpak
YAML_EOF

echo "=== 4. Commit et Push ==="
git add .github/workflows/ci.yml .github/workflows/release.yml
git commit -m "fix(ci): add linux deps and flatpak SDK extensions" || echo "Rien à commiter"
git push origin main

echo "=== 5. Relance du Tag pour déclencher la Release ==="
# Supprimer l'ancien tag local et distant
git tag -d v0.1.0 || true
git push origin :refs/tags/v0.1.0 || true

# Recréer et pousser le tag
git tag -a v0.1.0 -m "FanPilot 0.1.0 — première version"
git push origin v0.1.0

echo
echo "✅ Terminé ! Les workflows corrigés ont été poussés."
echo "👉 Va sur https://github.com/mmacity2021-hub/FanPilot/actions pour suivre l'exécution."
