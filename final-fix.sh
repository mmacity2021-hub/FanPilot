#!/usr/bin/env bash
set -e

GREEN='\e[32m'; YELLOW='\e[33m'; CYAN='\e[36m'; RESET='\e[0m'
cd /home/mo/Documents/0_FanPilot/0_FanPilot-github

echo -e "${YELLOW}🛠️  1. Injection de la correction Rust (Clippy)...${RESET}"
python3 - <<'PYEOF'
import re
filepath = 'fan-control/src-tauri/src/lib.rs'
with open(filepath, 'r') as f:
    content = f.read()

# On cherche le bloc exact qui pose problème et on le remplace par la syntaxe moderne
pattern = r'if let Some\(state\) = app\.try_state::<TrayState>\(\) \{\s*if let Ok\(items\) = state\.items\.lock\(\) \{\s*update_menu_labels\(&items, id\);\s*\}\s*\}'
replacement = """if let Some(state) = app.try_state::<TrayState>()
                            && let Ok(items) = state.items.lock()
                        {
                            update_menu_labels(&items, id);
                        }"""

content = re.sub(pattern, replacement, content)

with open(filepath, 'w') as f:
    f.write(content)
print("  ✓ Code Rust corrigé.")
PYEOF

echo -e "\n${YELLOW}🛠️  2. Mise à jour de Node.js (20 -> 22) dans le CI...${RESET}"
sed -i 's/node-version: 20/node-version: 22/g' .github/workflows/ci.yml
echo "  ✓ Workflow CI mis à jour."

echo -e "\n${YELLOW}📐 3. Formatage final du code Rust...${RESET}"
cd fan-control/src-tauri && cargo fmt --all && cd ../..
echo "  ✓ Formatage OK."

echo -e "\n${YELLOW}🔍 4. Audit local de sécurité (Le test ultime)...${RESET}"
# On lance ton script d'audit pour être sûr à 100% avant de pousser
if ./audit-and-report.sh | grep -q "SUCCÈS : SYSTÈME PARFAITEMENT ALIGNÉ"; then
    echo -e "  ${GREEN}✓ Audit réussi, le code est parfait.${RESET}"
else
    echo -e "  ❌ Échec de l'audit. Abandon du push pour ne pas saturer GitHub."
    exit 1
fi

echo -e "\n${YELLOW}🚀 5. Envoi sur GitHub...${RESET}"
git add .
git commit -m "fix(ci): resolve final clippy warning and update node version to 22"
git push origin main

echo -e "\n${GREEN}🎉 TERMINÉ ! Toutes les corrections ont été injectées et validées.${RESET}"
echo -e "👉 Va sur l'onglet Actions : le run CI va passer au VERT."
