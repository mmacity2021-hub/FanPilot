# Soumission Flathub

## Fichiers requis dans `flatpak/`

| Fichier | Rôle |
|---|---|
| `com.fanpilot.app.yml` | Manifeste |
| `com.fanpilot.app.metainfo.xml` | AppStream |
| `com.fanpilot.app.desktop` | Entrée bureau |
| `cargo-sources.json` | Sources Rust offline |

## Validation

    appstreamcli validate flatpak/com.fanpilot.app.metainfo.xml
    desktop-file-validate flatpak/com.fanpilot.app.desktop

## Soumission

Fork `flathub/flathub`, branche `new-pr`, PR.
Doc : https://docs.flathub.org/docs/for-app-authors/submission
