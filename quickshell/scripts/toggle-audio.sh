#!/usr/bin/env bash
exec >/tmp/omarchy-audio.log 2>&1

if swaymsg -t get_tree 2>/dev/null | jq -e '.. | objects | select(.app_id == "omarchy-audio")' >/dev/null 2>&1; then
    swaymsg '[app_id="omarchy-audio"] kill'
    exit 0
fi

TUI="$HOME/.config/quickshell/scripts/audio-tui.py"

if command -v alacritty >/dev/null 2>&1; then
    exec alacritty --class omarchy-audio -T "Audio" \
        -o 'font.size=14' \
        -o 'window.padding={x=16,y=12}' \
        -o 'colors.primary={background="#141416",foreground="#e5e5e5"}' \
        -o 'colors.normal={black="#141416",red="#e05252",green="#242428",yellow="#ff8800",blue="#888888",magenta="#ff8800",cyan="#9a9a9e",white="#e5e5e5"}' \
        -o 'colors.bright={black="#2e2e32",red="#e05252",green="#242428",yellow="#ff8800",blue="#888888",magenta="#ff8800",cyan="#9a9a9e",white="#e5e5e5"}' \
        -e python3 "$TUI"
elif command -v foot >/dev/null 2>&1; then
    exec foot --app-id=omarchy-audio --title="Audio" \
        -f "JetBrainsMono Nerd Font:size=14" \
        -o colors.background=141416 -o colors.foreground=e5e5e5 \
        -o colors.regular0=141416 -o colors.regular1=e05252 -o colors.regular2=242428 -o colors.regular3=ff8800 \
        -o colors.regular4=888888 -o colors.regular7=e5e5e5 -o colors.bright0=2e2e32 \
        python3 "$TUI"
elif command -v kitty >/dev/null 2>&1; then
    exec kitty --class omarchy-audio --title "Audio" \
        -o font_size=14 -o background=#141416 -o foreground=#e5e5e5 \
        -o color0=#141416 -o color1=#e05252 -o color2=#242428 -o color3=#ff8800 \
        -o color4=#888888 -o color7=#e5e5e5 -o color8=#2e2e32 \
        python3 "$TUI"
fi
