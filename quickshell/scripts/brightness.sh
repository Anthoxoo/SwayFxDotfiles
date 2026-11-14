#!/usr/bin/env bash
ACTION="$1"
VAL="${2:-5}"

# Récupérer la valeur actuelle en %
CUR=$(brightnessctl -m 2>/dev/null | cut -d, -f4 | tr -d '%')
[ -z "$CUR" ] && CUR=100

if [ "$ACTION" = "up" ]; then
    TARGET=$(( CUR + VAL ))
    [ "$TARGET" -gt 100 ] && TARGET=100
elif [ "$ACTION" = "down" ]; then
    TARGET=$(( CUR - VAL ))
    [ "$TARGET" -lt 1 ] && TARGET=1
elif [ "$ACTION" = "night-on" ]; then
    pkill -f wlsunset 2>/dev/null || true
    wlsunset -t "$VAL" -T 6500 &
    exit 0
elif [ "$ACTION" = "night-off" ]; then
    pkill -f wlsunset 2>/dev/null || true
    exit 0
else
    TARGET="$VAL"
    [ "$TARGET" -gt 100 ] && TARGET=100
    [ "$TARGET" -lt 1 ] && TARGET=1
fi

# Notifier instantanément Quickshell pour un affichage fluide sans saccade
qs ipc call shell osdBright "$TARGET" >/dev/null 2>&1 &

# Appliquer matériellement en arrière-plan
brightnessctl -c backlight set "${TARGET}%" -q
