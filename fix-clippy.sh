#!/usr/bin/env bash
set -euo pipefail

cd /home/mo/Documents/0_FanPilot/0_FanPilot-github/fan-control/src-tauri

echo "=== 1. Application automatique des corrections de Clippy ==="
# --fix permet à Clippy de réécrire le code tout seul
cargo clippy --fix --allow-dirty --allow-staged --all-targets

echo "=== 2. Formatage du code (pour être sûr) ==="
cargo fmt --all

echo "=== 3. Retour à la racine du projet ==="
cd /home/mo/Documents/0_FanPilot/0_FanPilot-github

echo "=== 4. Commit et Push ==="
# Vérifier s'il y a des changements avant de commit
if ! git diff --quiet; then
    git add fan-control/src-tauri/src
    git commit -m "fix(rust): auto-fix clippy collapsible_if warnings"
    git push origin main
    echo "[✓] Corrections poussées sur GitHub."
else
    echo "[i] Aucune modification nécessaire."
fi

echo
echo "✅ Terminé ! Le CI va se relancer automatiquement sur GitHub."
