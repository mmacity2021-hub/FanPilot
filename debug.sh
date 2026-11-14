#!/usr/bin/env bash
set -euo pipefail

cd /home/mo/Documents/0_FanPilot/0_FanPilot-github
REPO="mmacity2021-hub/FanPilot"

echo "=== 1. Installation de GitHub CLI ==="
if ! command -v gh &> /dev/null; then
    echo "[i] Installation de gh..."
    sudo apt update && sudo apt install -y gh
else
    echo "[✓] gh est déjà installé."
fi

echo "=== 2. Authentification ==="
if ! gh auth status &> /dev/null; then
    echo "[!] Tu dois te connecter. Choisis : GitHub.com > HTTPS > Login with a web browser."
    gh auth login
else
    echo "[✓] Déjà authentifié."
fi

echo "=== 3. Récupération des logs d'erreur (CI) ==="
CI_ID=$(gh run list --repo "$REPO" --workflow=ci.yml --limit=1 --json databaseId,conclusion --jq '.[] | select(.conclusion=="failure") | .databaseId' | head -n 1)
if [ -n "$CI_ID" ]; then
    gh run view "$CI_ID" --repo "$REPO" --log-failed > ci-logs.txt
    echo "[✓] Logs CI sauvegardés dans ci-logs.txt"
else
    echo "[i] Aucun échec CI récent trouvé."
fi

echo "=== 4. Récupération des logs d'erreur (Release) ==="
REL_ID=$(gh run list --repo "$REPO" --workflow=release.yml --limit=1 --json databaseId,conclusion --jq '.[] | select(.conclusion=="failure") | .databaseId' | head -n 1)
if [ -n "$REL_ID" ]; then
    gh run view "$REL_ID" --repo "$REPO" --log-failed > release-logs.txt
    echo "[✓] Logs Release sauvegardés dans release-logs.txt"
else
    echo "[i] Aucun échec Release récent trouvé."
fi

echo "=== 5. Correction automatique du formatage Rust (pour le CI) ==="
cd fan-control/src-tauri
if cargo fmt --all -- --check; then
    echo "[✓] Le code Rust est déjà bien formaté."
else
    echo "[!] Le code Rust n'était pas formaté. Correction en cours..."
    cargo fmt --all
    cd /home/mo/Documents/0_FanPilot/0_FanPilot-github
    git add fan-control/src-tauri/src
    git commit -m "style: auto-format rust code with cargo fmt"
    git push origin main
    echo "[✓] Code Rust formaté et poussé."
fi

echo -e "\n✅ Débogage terminé."
echo "👉 Demande à l'IA de lire les fichiers : ci-logs.txt et release-logs.txt"
