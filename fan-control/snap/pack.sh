#!/bin/sh
# Assemble un snap classic Ubuntu 26.04 à partir du binaire release déjà compilé.
set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
bin="${BIN:-$root/src-tauri/target/release/fan-control}"
stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT

if [ ! -x "$bin" ]; then
  echo "Binaire absent : $bin" >&2
  echo "Lancez d'abord : npm run tauri build -- --no-bundle" >&2
  exit 1
fi

install -D -m 755 "$bin" "$stage/usr/bin/fan-control.bin"
install -D -m 755 "$root/snap/fan-control.wrapper" "$stage/usr/bin/fan-control"
install -D -m 644 "$root/snap/fanpilot.desktop" "$stage/usr/share/applications/fanpilot.desktop"
install -D -m 644 "$root/snap/fanpilot.desktop" "$stage/meta/gui/fanpilot.desktop"
install -D -m 644 "$root/src-tauri/icons/128x128.png" "$stage/usr/share/icons/hicolor/128x128/apps/fanpilot.png"
install -D -m 644 "$root/src-tauri/icons/128x128.png" "$stage/meta/gui/icon.png"

# snapd exige que tout le contenu soit lisible par tous.
chmod -R u=rwX,go=rX "$stage"
chmod 755 "$stage/usr/bin/fan-control" "$stage/usr/bin/fan-control.bin"

cat > "$stage/meta/snap.yaml" << 'EOF'
name: fanpilot
title: FanPilot
version: "0.1.0"
summary: Contrôle des ventilateurs MacBook sous Ubuntu
description: |
  FanPilot affiche les températures et les ventilateurs d'un MacBook
  sous Linux (Apple SMC) et règle mbpfan. Confinement classic, requis
  pour lire le sysfs, écrire /etc/mbpfan.conf et redémarrer mbpfan
  via pkexec.
architectures:
  - amd64
base: core26
confinement: classic
grade: stable
apps:
  fanpilot:
    command: usr/bin/fan-control
    desktop: usr/share/applications/fanpilot.desktop
EOF

out="$root/dist"
mkdir -p "$out"
snap pack --compression=xz --filename=fanpilot_0.1.0_amd64.snap "$stage" "$out"
echo "Snap écrit : $out/fanpilot_0.1.0_amd64.snap"
