# Architecture

    Frontend (src/)  --IPC-->  Backend Rust (src-tauri/)  --sysfs/D-Bus-->  Linux

## Structure

| Dossier | Rôle |
|---|---|
| `fan-control/src/` | Frontend (Vite + TS/JS) |
| `fan-control/src-tauri/` | Rust + config Tauri |
| `flatpak-src/` | Manifeste + shared-modules |
| `flatpak/` | Manifeste prêt Flathub |
| `docs/` | Documentation |

## Sécurité Tauri

- CSP restrictive
- Capabilities par fenêtre
- Commandes IPC validées
- Updater signé (optionnel)
