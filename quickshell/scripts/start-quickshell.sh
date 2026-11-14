#!/usr/bin/env bash
export XDG_STATE_HOME="$HOME/.local/state"
export PATH="$HOME/.local/bin:$PATH"

pkill -x waybar 2>/dev/null || true
pkill -x mako 2>/dev/null || true
pkill -x dunst 2>/dev/null || true
pkill -x swaync 2>/dev/null || true
pkill -x nm-applet 2>/dev/null || true
pkill -x blueman-applet 2>/dev/null || true

if ! pgrep -x librepods >/dev/null 2>&1 && [ -x "$HOME/.local/bin/librepods" ]; then
    systemctl --user start librepods.service 2>/dev/null || QT_QPA_PLATFORM=offscreen nohup "$HOME/.local/bin/librepods" >/dev/null 2>&1 &
fi

# Arrêter les anciens superviseurs et instances quickshell
for pid in $(pgrep -f "start-quickshell.sh"); do
    if [ "$pid" != "$$" ] && [ "$pid" != "$PPID" ]; then
        kill -9 "$pid" 2>/dev/null || true
    fi
done
pkill -x quickshell 2>/dev/null
while pgrep -x quickshell >/dev/null 2>&1; do
    sleep 0.1
done

# Boucle superviseur en arrière-plan
(
    while true; do
        quickshell >>/tmp/quickshell.log 2>&1
        sleep 0.5
    done
) >/dev/null 2>&1 &
disown
