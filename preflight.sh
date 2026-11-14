#!/usr/bin/env bash
set -e

GREEN='\e[32m'; RED='\e[31m'; YELLOW='\e[33m'; RESET='\e[0m'
echo -e "${YELLOW}🛡️  Lancement du Preflight FanPilot...${RESET}"

# Aller à la racine du projet
cd "$(dirname "$0")"

# --- 1. Frontend ---
echo -e "\n📦 [1/3] Vérification du Frontend (npm)..."
cd fan-control
# Installer les dépendances si node_modules n'existe pas
if [ ! -d "node_modules" ]; then
    echo "Installation des dépendances npm..."
    npm install --silent
fi
npm run build --silent > /dev/null || { echo -e "${RED}❌ Le frontend ne compile pas.${RESET}"; exit 1; }
echo -e "${GREEN}✓ Frontend OK.${RESET}"

# --- 2. Rust (Formatage & Clippy) ---
echo -e "\n🦀 [2/3] Vérification du Backend Rust..."
cd src-tauri

# Auto-correction du formatage
cargo fmt --all
# Auto-correction de Clippy (si possible)
cargo clippy --fix --allow-dirty --allow-staged --all-targets > /dev/null 2>&1 || true
# Vérification stricte
cargo clippy --all-targets --all-features -- -D warnings || { echo -e "${RED}❌ Clippy a trouvé des erreurs non corrigeables.${RESET}"; exit 1; }
cargo fmt --all -- --check || { echo -e "${RED}❌ Erreur de formatage Rust.${RESET}"; exit 1; }
echo -e "${GREEN}✓ Code Rust parfait.${RESET}"

# --- 3. Configuration du Hook Git (Garde-fou) ---
echo -e "\n🔒 [3/3] Configuration du garde-fou Git (pre-commit)..."
cd ../..
mkdir -p .git/hooks
cat > .git/hooks/pre-commit <<'HOOK_EOF'
#!/bin/sh
echo "🔍 Vérification automatique avant commit..."
cd fan-control/src-tauri
cargo fmt --all -- --check > /dev/null || { echo "❌ [Bloqué] Formatage Rust incorrect. Lancez ./preflight.sh"; exit 1; }
cargo clippy --all-targets --all-features -- -D warnings > /dev/null 2>&1 || { echo "❌ [Bloqué] Erreurs Clippy. Lancez ./preflight.sh"; exit 1; }
echo "✅ Code propre, commit autorisé."
HOOK_EOF
chmod +x .git/hooks/pre-commit

echo -e "\n${GREEN}🎉 PREFLIGHT RÉUSSI ! Ton code est prêt.${RESET}"
echo -e "👉 Tu peux maintenant faire : git add . && git commit -m \"...\" && git push"
