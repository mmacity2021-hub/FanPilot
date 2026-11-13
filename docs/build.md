# Build

## Prérequis

Voir [dependencies.md](dependencies.md).

## Commande

    ./scripts/build-flatpak.sh

Équivalent :

    cd flatpak-src
    flatpak-builder --user --install --force-clean build-dir com.fanpilot.app.json

## Durées

| Cas | Durée |
|---|---|
| Première fois | ~10 min |
| Rebuilds suivants | ~4 min |

## Nettoyer

    ./scripts/clean.sh
