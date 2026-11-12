#!/usr/bin/env bash
exec >/tmp/omarchy-wifi.log 2>&1

# Si la fenêtre flottante est déjà ouverte dans Sway, on la ferme
if swaymsg -t get_tree 2>/dev/null | jq -e '.. | objects | select(.app_id == "omarchy-wifi")' >/dev/null 2>&1; then
    swaymsg '[app_id="omarchy-wifi"] kill'
    exit 0
fi

# Choix du TUI : wlctl (fork Impala pour NetworkManager) > impala > wifi-tui.py
if command -v wlctl >/dev/null 2>&1; then
    CMD="wlctl"
elif command -v impala >/dev/null 2>&1 && systemctl is-active --quiet iwd 2>/dev/null; then
    CMD="impala"
else
    CMD="python3 $HOME/.config/quickshell/scripts/wifi-tui.py"
fi

# Lancement dans le terminal avec app_id="omarchy-wifi"
if command -v alacritty >/dev/null 2>&1; then
    exec alacritty --class omarchy-wifi -T "Omarchy Wi-Fi" -e sh -c "$CMD"
elif command -v foot >/dev/null 2>&1; then
    exec foot --app-id=omarchy-wifi --title="Omarchy Wi-Fi" sh -c "$CMD"
elif command -v kitty >/dev/null 2>&1; then
    exec kitty --class omarchy-wifi --title "Omarchy Wi-Fi" sh -c "$CMD"
fi
