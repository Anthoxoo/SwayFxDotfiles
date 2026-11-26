#!/usr/bin/env bash
# Installe librepods (démon AirPods, fork embarqué dans omarchy-pods) avec le scan BLE par
# fenêtres (10 s toutes les 5 min) au lieu d'un scan continu qui inonde BlueZ.
# Testé sur omarchy-pods f35dbc4.
# Dépendances Arch/CachyOS : cmake ninja qt6-base qt6-connectivity qt6-declarative qt6-tools libpulse pkgconf
# Dépendances Debian : cmake ninja-build qt6-base-dev
# qt6-connectivity-dev qt6-declarative-dev qt6-tools-dev libpulse-dev pkgconf
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
src="${OMARCHY_PODS_DIR:-$HOME/.local/share/omarchy-pods}"

if [ ! -d "$src/.git" ]; then
    git clone https://github.com/thisisgm/omarchy-pods.git "$src"
fi

cd "$src"
if git apply --reverse --check "$here/ble-duty-cycle.patch" 2>/dev/null; then
    echo "Patch déjà appliqué."
else
    git apply "$here/ble-duty-cycle.patch"
fi

cmake -S daemon -B daemon/build -G Ninja -DBUILD_TESTING=OFF
cmake --build daemon/build
cmake --install daemon/build --prefix "$HOME/.local"
# Service headless + relais de notifications (voir README)
install -Dm755 "$here/bin/omarchy" "$HOME/.local/share/librepods/bin/omarchy"
install -Dm644 "$here/librepods.service" "$HOME/.config/systemd/user/librepods.service"
systemctl --user daemon-reload
systemctl --user enable librepods.service
systemctl --user restart librepods.service
echo "librepods installé dans ~/.local/bin et redémarré."
