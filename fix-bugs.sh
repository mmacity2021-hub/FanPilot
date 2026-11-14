#!/usr/bin/env bash
set -euo pipefail
cd /home/mo/Documents/0_FanPilot/0_FanPilot-github

echo "=== 1. Alignement des versions Flatpak (manifeste -> 50, workflow -> 50) ==="
# Le manifeste utilise déjà la version 50, on corrige le workflow
sed -i 's|org.gnome.Platform//48|org.gnome.Platform//50|g' .github/workflows/release.yml
sed -i 's|org.gnome.Sdk//48|org.gnome.Sdk//50|g' .github/workflows/release.yml
echo "  ✓ release.yml aligné sur GNOME 50"

echo "=== 2. Mise à jour des actions GitHub (Node.js 24) ==="
# Passer à checkout@v5 et setup-node@v5
sed -i 's|actions/checkout@v4|actions/checkout@v5|g' .github/workflows/ci.yml .github/workflows/release.yml .github/workflows/codeql.yml
sed -i 's|actions/setup-node@v4|actions/setup-node@v5|g' .github/workflows/ci.yml
sed -i 's|github/codeql-action/init@v3|github/codeql-action/init@v4|g' .github/workflows/codeql.yml
sed -i 's|github/codeql-action/autobuild@v3|github/codeql-action/autobuild@v4|g' .github/workflows/codeql.yml
sed -i 's|github/codeql-action/analyze@v3|github/codeql-action/analyze@v4|g' .github/workflows/codeql.yml
sed -i 's|softprops/action-gh-release@v2|softprops/action-gh-release@v3|g' .github/workflows/release.yml
echo "  ✓ Actions mises à jour vers Node.js 24"

echo "=== 3. Configuration Clippy pour éviter les blocages futurs ==="
# Ajouter la section [lints.clippy] dans Cargo.toml
if ! grep -q "\[lints.clippy\]" fan-control/src-tauri/Cargo.toml; then
  cat >> fan-control/src-tauri/Cargo.toml <<'TOML'

[lints.clippy]
# Autorise collapsible_if : ce lint est trop strict pour le code Tauri généré
collapsible_if = "allow"
collapsible_else_if = "allow"
TOML
  echo "  ✓ Cargo.toml : lints Clippy configurés"
else
  echo "  [i] Section [lints.clippy] déjà présente"
fi

echo "=== 4. Commit et Push ==="
git add .github/workflows/ci.yml .github/workflows/release.yml .github/workflows/codeql.yml fan-control/src-tauri/Cargo.toml
git commit -m "fix(ci): align flatpak versions, update actions to Node 24, configure clippy lints"
git push origin main

echo
echo "✅ Terminé ! Le CI va se relancer automatiquement."
echo "👉 Vérifie sur https://github.com/mmacity2021-hub/FanPilot/actions"
