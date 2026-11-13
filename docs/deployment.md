# Déploiement

## Bundle

    ./scripts/bundle.sh
    # → FanPilot.flatpak

## Installation ailleurs

    flatpak install FanPilot.flatpak
    flatpak run com.fanpilot.app

Prérequis cible :

    flatpak install -y flathub org.gnome.Platform//48

## Release GitHub

Tag `v*` → `.github/workflows/release.yml` build + upload `FanPilot.flatpak`.
