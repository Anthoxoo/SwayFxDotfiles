#!/usr/bin/env bash
FIFO="/tmp/quickshell-ipc.fifo"
ACTION="$1"
VAL="$2"

case "$ACTION" in
    up)
        brightnessctl -c backlight set "+${VAL:-5}%" -q
        ;;
    down)
        brightnessctl -c backlight set "${VAL:-5}%-" -q
        ;;
    set)
        brightnessctl -c backlight set "${VAL}%" -q
        ;;
    night-on)
        TEMP="${VAL:-4500}"
        pkill -x wlsunset 2>/dev/null
        nohup wlsunset -t "$TEMP" -T "$((TEMP + 1))" >/dev/null 2>&1 &
        exit 0
        ;;
    night-off)
        pkill -x wlsunset 2>/dev/null
        exit 0
        ;;
esac

CUR=$(brightnessctl -m 2>/dev/null | cut -d, -f4 | tr -d '%')
[ -p "$FIFO" ] && printf "osd-bright:%s\n" "${CUR:-100}" > "$FIFO" &
