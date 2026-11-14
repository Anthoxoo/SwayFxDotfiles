#!/usr/bin/env bash
ACTION="$1"
VAL="${2:-2}"

if command -v pamixer >/dev/null 2>&1; then
    CUR=$(pamixer --get-volume 2>/dev/null || echo 0)
    MUTED=$(pamixer --get-mute 2>/dev/null || echo false)
elif command -v wpctl >/dev/null 2>&1; then
    WP_OUT=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null)
    echo "$WP_OUT" | grep -q "MUTED" && MUTED="true" || MUTED="false"
    CUR=$(echo "$WP_OUT" | awk '{printf "%d", $2 * 100}' 2>/dev/null || echo 0)
else
    MUTED=$(pactl get-sink-mute @DEFAULT_SINK@ 2>/dev/null | grep -q "yes" && echo true || echo false)
    CUR=$(pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null | grep -oP '\d+(?=%)' | head -n1 || echo 0)
fi

[ -z "$CUR" ] && CUR=0

if [ "$ACTION" = "up" ]; then
    TARGET=$(( CUR + VAL ))
    [ "$TARGET" -gt 100 ] && TARGET=100
    if command -v pamixer >/dev/null 2>&1; then
        pamixer -ui "$VAL" --unmute >/dev/null 2>&1
        MUTED="false"
    elif command -v wpctl >/dev/null 2>&1; then
        wpctl set-mute @DEFAULT_AUDIO_SINK@ 0 >/dev/null 2>&1
        wpctl set-volume @DEFAULT_AUDIO_SINK@ "${VAL}%+" >/dev/null 2>&1
        MUTED="false"
    else
        pactl set-sink-mute @DEFAULT_SINK@ 0
        pactl set-sink-volume @DEFAULT_SINK@ "+${VAL}%"
        MUTED="false"
    fi
    qs ipc call shell osdAudio "$TARGET" "$MUTED" >/dev/null 2>&1 &
elif [ "$ACTION" = "down" ]; then
    TARGET=$(( CUR - VAL ))
    [ "$TARGET" -lt 0 ] && TARGET=0
    if command -v pamixer >/dev/null 2>&1; then
        pamixer -ud "$VAL" --unmute >/dev/null 2>&1
        MUTED="false"
    elif command -v wpctl >/dev/null 2>&1; then
        wpctl set-mute @DEFAULT_AUDIO_SINK@ 0 >/dev/null 2>&1
        wpctl set-volume @DEFAULT_AUDIO_SINK@ "${VAL}%-" >/dev/null 2>&1
        MUTED="false"
    else
        pactl set-sink-mute @DEFAULT_SINK@ 0
        pactl set-sink-volume @DEFAULT_SINK@ "-${VAL}%"
        MUTED="false"
    fi
    qs ipc call shell osdAudio "$TARGET" "$MUTED" >/dev/null 2>&1 &
elif [ "$ACTION" = "mute" ]; then
    if command -v pamixer >/dev/null 2>&1; then
        pamixer --toggle-mute >/dev/null 2>&1
        MUTED=$(pamixer --get-mute 2>/dev/null || echo false)
    elif command -v wpctl >/dev/null 2>&1; then
        wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle >/dev/null 2>&1
        WP_OUT=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null)
        echo "$WP_OUT" | grep -q "MUTED" && MUTED="true" || MUTED="false"
    else
        pactl set-sink-mute @DEFAULT_SINK@ toggle
        MUTED=$(pactl get-sink-mute @DEFAULT_SINK@ 2>/dev/null | grep -q "yes" && echo true || echo false)
    fi
    qs ipc call shell osdAudio "$CUR" "$MUTED" >/dev/null 2>&1 &
else
    TARGET="$VAL"
    [ "$TARGET" -gt 100 ] && TARGET=100
    [ "$TARGET" -lt 0 ] && TARGET=0
    if command -v pamixer >/dev/null 2>&1; then
        pamixer --set-volume "$TARGET" --unmute >/dev/null 2>&1
        MUTED="false"
    elif command -v wpctl >/dev/null 2>&1; then
        wpctl set-volume @DEFAULT_AUDIO_SINK@ "$(awk -v v="$TARGET" 'BEGIN {print v/100}')" >/dev/null 2>&1
        MUTED="false"
    else
        pactl set-sink-volume @DEFAULT_SINK@ "${TARGET}%"
        MUTED="false"
    fi
    qs ipc call shell osdAudio "$TARGET" "$MUTED" >/dev/null 2>&1 &
fi
