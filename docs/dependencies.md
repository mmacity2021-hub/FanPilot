# Dépendances

## Système (Debian/Ubuntu)

    sudo apt install -y git rsync curl build-essential pkg-config \
                        flatpak flatpak-builder nodejs npm

Rust :

    curl --proto =https --tlsv1.2 -sSf https://sh.rustup.rs | sh

## SDK Flatpak

    flatpak install -y flathub \
      org.gnome.Platform//48 org.gnome.Sdk//48 \
      org.freedesktop.Sdk.Extension.rust-stable//24.08 \
      org.freedesktop.Sdk.Extension.node20//24.08

## Modules du sandbox

1. intltool
2. libdbusmenu
3. ayatana-ido
4. libayatana-indicator
5. libayatana-appindicator
6. fan-control
