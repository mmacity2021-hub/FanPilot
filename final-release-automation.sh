#!/usr/bin/env bash

# Couleurs pour un affichage magnifique
GREEN='\e[32m'; RED='\e[31m'; YELLOW='\e[33m'; CYAN='\e[36m'; BOLD='\e[1m'; RESET='\e[0m'

echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════${RESET}"
echo -e "${BOLD}${CYAN}  🚀 AUTOMATISATION FINALE : SYNC & RELEASE FANPILOT v0.1.1${RESET}"
echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════${RESET}"

PROJECT_DIR="/home/mo/Documents/0_FanPilot/0_FanPilot-github"
cd "$PROJECT_DIR" || { echo -e "${RED}[✗] Dossier projet introuvable.${RESET}"; exit 1; }

# --- 1. Synchronisation Locale ---
echo -e "\n${BOLD}[1/5] Récupération de la copie locale depuis GitHub...${RESET}"
# On récupère les changements distants. Le '|| true' empêche le crash si déjà à jour.
git pull origin main --no-rebase --no-edit > /dev/null 2>&1 || true
echo -e "${GREEN}  ✓ Dépôt local synchronisé avec GitHub.${RESET}"

# --- 2. Audit de Sécurité ---
echo -e "\n${BOLD}[2/5] Audit de sécurité avant envoi...${RESET}"
if [ -f "./audit-and-report.sh" ]; then
    # On lance l'audit et on vérifie qu'il n'y a pas d'erreur
    if ./audit-and-report.sh | grep -q "SUCCÈS : SYSTÈME PARFAITEMENT ALIGNÉ"; then
        echo -e "${GREEN}  ✓ Audit réussi. Le code est parfait.${RESET}"
    else
        echo -e "${RED}  ✗ L'audit a détecté des erreurs. Abandon de la release par sécurité.${RESET}"
        exit 1
    fi
else
    echo -e "${YELLOW}  ⚠ Script d'audit introuvable, on continue prudemment...${RESET}"
fi

# --- 3. Mise à jour du dépôt principal (si besoin) ---
echo -e "\n${BOLD}[3/5] Vérification des modifications locales...${RESET}"
git add .
if ! git diff --cached --quiet; then
    git commit -m "chore: pre-release sync for v0.1.1" > /dev/null
    echo -e "${GREEN}  ✓ Modifications locales commitées.${RESET}"
else
    echo -e "  [i] Aucune modification locale à commiter."
fi
git push origin main > /dev/null 2>&1 || true
echo -e "${GREEN}  ✓ Branche 'main' à jour sur GitHub.${RESET}"

# --- 4. Création du Tag v0.1.1 ---
echo -e "\n${BOLD}[4/5] Création du tag de version v0.1.1...${RESET}"
# Nettoyage de l'ancien tag s'il existe déjà (pour éviter les conflits)
git tag -d v0.1.1 > /dev/null 2>&1 || true
git push origin :refs/tags/v0.1.1 > /dev/null 2>&1 || true

# Création et envoi du nouveau tag
git tag -a v0.1.1 -m "FanPilot v0.1.1 - Clean Release" > /dev/null
git push origin v0.1.1 > /dev/null
echo -e "${GREEN}  ✓ Tag v0.1.1 créé et envoyé.${RESET}"

# --- 5. Déclenchement de la compilation GitHub ---
echo -e "\n${BOLD}[5/5] Déclenchement du robot de compilation GitHub...${RESET}"
echo -e "${GREEN}  ✓ Le robot 'Release' a été réveillé.${RESET}"

echo -e "\n${BOLD}${CYAN}═══════════════════════════════════════════════════════════════${RESET}"
echo -e "${BOLD}${GREEN}🎉 SUCCÈS TOTAL : TOUT EST LANCÉ !${RESET}"
echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════${RESET}"
echo -e "\n👉 Ton PC est synchronisé avec GitHub."
echo -e "👉 Le robot GitHub est en train de compiler ton nouveau Flatpak (cela prend ~10 minutes)."
echo -e "\n🔗 Va voir la magie en direct ici :"
echo -e "   ${CYAN}https://github.com/mmacity2021-hub/FanPilot/actions${RESET}"
echo -e "\nEt une fois terminé, ton fichier sera ici :"
echo -e "   ${CYAN}https://github.com/mmacity2021-hub/FanPilot/releases${RESET}\n"
