#!/usr/bin/env bash
set -euo pipefail
cd /home/mo/Documents/0_FanPilot/0_FanPilot-github

echo "=== 1. Mise à jour des versions dans release.yml ==="
# Remplacer GNOME 48 par 50
sed -i 's|org.gnome.Platform//48|org.gnome.Platform//50|g' .github/workflows/release.yml
sed -i 's|org.gnome.Sdk//48|org.gnome.Sdk//50|g' .github/workflows/release.yml

# Remplacer les extensions Freedesktop 24.08 par 25.08 (compatibles GNOME 50)
sed -i 's|org.freedesktop.Sdk.Extension.rust-stable//24.08|org.freedesktop.Sdk.Extension.rust-stable//25.08|g' .github/workflows/release.yml
sed -i 's|org.freedesktop.Sdk.Extension.node20//24.08|org.freedesktop.Sdk.Extension.node20//25.08|g' .github/workflows/release.yml

echo "  ✓ Versions mises à jour dans release.yml"

echo "=== 2. Vérification du contenu du workflow ==="
grep -E "flatpak install" -A 6 .github/workflows/release.yml

echo "=== 3. Commit et Push ==="
git add .github/workflows/release.yml
git commit -m "fix(ci): align flatpak SDK and extensions to GNOME 50 and 25.08"
git push origin main

echo
echo "✅ Terminé ! Le CI va se relancer automatiquement."
echo "👉 Vérifie sur https://github.com/mmacity2021-hub/FanPilot/actions"
