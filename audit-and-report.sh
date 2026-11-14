#!/usr/bin/env bash
set +e  # Empêche le script de planter

GREEN='\e[32m'; RED='\e[31m'; YELLOW='\e[33m'; CYAN='\e[36m'; BOLD='\e[1m'; RESET='\e[0m'
PROJECT_DIR="/home/mo/Documents/0_FanPilot/0_FanPilot-github"
LOG_FILE="$PROJECT_DIR/audit_report.txt"
REMEDIATION_FILE="$PROJECT_DIR/remediate.sh"

# Initialisation du fichier de remédiation
echo "#!/usr/bin/env bash" > "$REMEDIATION_FILE"
echo "set -e" >> "$REMEDIATION_FILE"
echo "echo '🛠️ Début de la remédiation...'" >> "$REMEDIATION_FILE"

FAIL=0

# Rediriger toute la sortie vers le terminal ET le fichier log
exec > >(tee "$LOG_FILE") 2>&1

echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════${RESET}"
echo -e "${BOLD}${CYAN}  AUDIT ET GÉNÉRATION DE REMÉDIATION${RESET}"
echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════${RESET}"

cd "$PROJECT_DIR" || exit 1

# --- 1. Outils ---
echo -e "\n${BOLD}[1/4] Vérification des outils de base${RESET}"
TOOLS=("git" "curl" "node" "npm" "cargo" "flatpak" "flatpak-builder")
for cmd in "${TOOLS[@]}"; do
    if command -v $cmd &> /dev/null; then
        echo -e "  ${GREEN}✓${RESET} $cmd"
    else
        echo -e "  ${RED}✗${RESET} $cmd MANQUANT"
        echo "  sudo apt install -y $cmd" >> "$REMEDIATION_FILE"
        FAIL=1
    fi
done

# --- 2. Bibliothèques Système (Tauri) ---
echo -e "\n${BOLD}[2/4] Vérification des bibliothèques Linux (Tauri)${RESET}"
# On vérifie via pkg-config (plus fiable) et via dpkg pour la remédiation
if ! command -v pkg-config &> /dev/null; then
    echo -e "  ${RED}✗${RESET} pkg-config MANQUANT"
    echo "  sudo apt install -y pkg-config" >> "$REMEDIATION_FILE"
    FAIL=1
else
    DEPS=("webkit2gtk-4.1" "gtk+-3.0" "ayatana-appindicator3-0.1")
    for dep in "${DEPS[@]}"; do
        if pkg-config --exists "$dep"; then
            echo -e "  ${GREEN}✓${RESET} $dep"
        else
            echo -e "  ${RED}✗${RESET} $dep MANQUANT"
            # On ajoute le paquet -dev correspondant pour Ubuntu
            if [ "$dep" == "webkit2gtk-4.1" ]; then echo "  sudo apt install -y libwebkit2gtk-4.1-dev" >> "$REMEDIATION_FILE"; fi
            if [ "$dep" == "gtk+-3.0" ]; then echo "  sudo apt install -y libgtk-3-dev" >> "$REMEDIATION_FILE"; fi
            if [ "$dep" == "ayatana-appindicator3-0.1" ]; then echo "  sudo apt install -y libayatana-appindicator3-dev" >> "$REMEDIATION_FILE"; fi
            FAIL=1
        fi
    done
fi

# --- 3. Environnement Rust ---
echo -e "\n${BOLD}[3/4] Cohérence de l'environnement Rust${RESET}"
if command -v rustup &> /dev/null; then
    echo -e "  ${GREEN}✓${RESET} rustup est installé."
else
    echo -e "  ${YELLOW}⚠${RESET} rustup manquant (impossible de mettre à jour Rust facilement)."
fi

# --- 4. Simulation Exacte du CI GitHub ---
echo -e "\n${BOLD}[4/4] Simulation des tests GitHub Actions${RESET}"

# A. NPM Build
echo -n "  [CI] Frontend (npm run build)... "
if (cd fan-control && npm run build --silent > /tmp/npm_err.log 2>&1); then
    echo -e "${GREEN}✓ OK${RESET}"
else
    echo -e "${RED}✗ ÉCHEC${RESET}"
    echo -e "  ${YELLOW}Dernières lignes :${RESET}"
    tail -n 3 /tmp/npm_err.log | sed 's/^/    /'
    echo "  cd $PROJECT_DIR/fan-control && npm install && npm run build" >> "$REMEDIATION_FILE"
    FAIL=1
fi

# B. Cargo Fmt
echo -n "  [CI] Rust Format (cargo fmt)... "
if (cd fan-control/src-tauri && cargo fmt --all -- --check > /dev/null 2>&1); then
    echo -e "${GREEN}✓ OK${RESET}"
else
    echo -e "${RED}✗ ÉCHEC (Code mal formaté)${RESET}"
    echo "  cd $PROJECT_DIR/fan-control/src-tauri && cargo fmt --all" >> "$REMEDIATION_FILE"
    FAIL=1
fi

# C. Cargo Clippy
echo -n "  [CI] Rust Clippy (analyse stricte)... "
if (cd fan-control/src-tauri && cargo clippy --all-targets --all-features -- -D warnings > /tmp/clippy_err.log 2>&1); then
    echo -e "${GREEN}✓ OK${RESET}"
else
    echo -e "${RED}✗ ÉCHEC (Clippy a trouvé des erreurs)${RESET}"
    echo -e "  ${YELLOW}Dernières lignes :${RESET}"
    grep -E "^(error|warning)" /tmp/clippy_err.log | head -n 3 | sed 's/^/    /'
    echo "  cd $PROJECT_DIR/fan-control/src-tauri && cargo clippy --fix --allow-dirty --allow-staged --all-targets -- -D warnings" >> "$REMEDIATION_FILE"
    FAIL=1
fi

# --- VERDICT ET GÉNÉRATION DU SCRIPT ---
echo -e "\n${BOLD}${CYAN}═══════════════════════════════════════════════════════════════${RESET}"
if [ $FAIL -eq 0 ]; then
    echo -e "${BOLD}${GREEN}✅ SUCCÈS : SYSTÈME PARFAITEMENT ALIGNÉ${RESET}"
    echo "echo '✅ Système déjà parfait, rien à faire.'" > "$REMEDIATION_FILE"
    rm -f "$REMEDIATION_FILE"
else
    echo -e "${BOLD}${RED}❌ DÉSALIGNEMENT DÉTECTÉ${RESET}"
    echo -e "Un script de correction a été généré."
    echo -e "\n${BOLD}👉 COPIEZ TOUT LE TEXTE CI-DESSOUS POUR L'ENVOYER À L'IA :${RESET}"
    echo -e "${YELLOW}--------------------------------------------------${RESET}"
    # On recrée un mini-rapport propre pour le copier-coller
    cat "$LOG_FILE" | grep -E "✓|✗|⚠|DÉSALIGNEMENT|SUCCÈS"
    echo -e "${YELLOW}--------------------------------------------------${RESET}"
    
    echo -e "\n${BOLD}🛠️ POUR CORRIGER AUTOMATIQUEMENT :${RESET}"
    echo -e "Lancez la commande : ${CYAN}chmod +x remediate.sh && ./remediate.sh${RESET}"
    
    echo -e "\n${GREEN}Résumé du script de remédiation généré :${RESET}"
    grep -v "^#!/" "$REMEDIATION_FILE" | grep -v "^set -e" | grep -v "^echo" | sed 's/^/  /'
fi
echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════${RESET}"
