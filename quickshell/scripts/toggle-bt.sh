#!/usr/bin/env bash
exec >/tmp/omarchy-bt.log 2>&1

if swaymsg -t get_tree 2>/dev/null | jq -e '.. | objects | select(.app_id == "omarchy-bt")' >/dev/null 2>&1; then
    swaymsg '[app_id="omarchy-bt"] kill'
    exit 0
fi

if command -v alacritty >/dev/null 2>&1; then
    exec alacritty --class omarchy-bt -T "Omarchy Bluetooth" -e bluetui
elif command -v foot >/dev/null 2>&1; then
    exec foot --app-id=omarchy-bt --title="Omarchy Bluetooth" bluetui
elif command -v kitty >/dev/null 2>&1; then
    exec kitty --class omarchy-bt --title "Omarchy Bluetooth" bluetui
fi
