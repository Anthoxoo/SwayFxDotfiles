#!/usr/bin/env bash
export LC_ALL=C

WIN=$(swaymsg -t get_tree 2>/dev/null | jq -r '.. | objects | select(.focused == true and (.type == "con" or .type == "floating_con")) | "\(.app_id // .window_properties.class // "")>>>\(.name // "")"' | head -n1)
MODE=$(swaymsg -t get_binding_state 2>/dev/null | jq -r '.name // "default"')

if command -v pamixer >/dev/null 2>&1; then
    MUTED=$(pamixer --get-mute 2>/dev/null || echo false)
    VOL=$(pamixer --get-volume 2>/dev/null || echo 0)
elif command -v wpctl >/dev/null 2>&1; then
    WP_OUT=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null)
    echo "$WP_OUT" | grep -q "MUTED" && MUTED="true" || MUTED="false"
    VOL=$(echo "$WP_OUT" | awk '{printf "%d", $2 * 100}' 2>/dev/null || echo 0)
else
    MUTED=$(pactl get-sink-mute @DEFAULT_SINK@ 2>/dev/null | grep -q "yes" && echo true || echo false)
    VOL=$(pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null | grep -oP '\d+(?=%)' | head -n1 || echo 0)
fi

DEF_SINK=$(pactl get-default-sink 2>/dev/null)
SINK_DESC=$(pactl list sinks 2>/dev/null | awk -v s="$DEF_SINK" '$1=="Name:" && $2==s {f=1} f && $1=="Description:" {sub(/^[ \t]*Description:[ \t]*/, ""); print; exit}')
[ -z "$SINK_DESC" ] && SINK_DESC="default"

DEF_SRC=$(pactl get-default-source 2>/dev/null)
SRC_MUTE=$(pactl get-source-mute @DEFAULT_SOURCE@ 2>/dev/null | awk '{print $2}')
[ "$SRC_MUTE" = "yes" ] && MIC_STATE="muted" || MIC_STATE="active"

if command -v brightnessctl >/dev/null 2>&1; then
    BRIGHT=$(brightnessctl -m 2>/dev/null | cut -d, -f4 | tr -d '%')
fi
[ -z "$BRIGHT" ] && BRIGHT=100

BAT_CAP=$(cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -n1)
[ -z "$BAT_CAP" ] && BAT_CAP=100
BAT_STATUS=$(cat /sys/class/power_supply/BAT*/status 2>/dev/null | head -n1)
[ -z "$BAT_STATUS" ] && BAT_STATUS="Discharging"
BAT_UW=$(cat /sys/class/power_supply/BAT*/power_now 2>/dev/null | head -n1 || echo 0)
BAT_W=$(awk -v uw="${BAT_UW:-0}" 'BEGIN { printf "%.1f", uw / 1000000 }')
PWR_PROF=$(powerprofilesctl get 2>/dev/null || echo "balanced")

ALERT_FILE="/tmp/omarchy_bat_alert"
if [ "$BAT_STATUS" = "Discharging" ]; then
    LAST_ALERT=$(cat "$ALERT_FILE" 2>/dev/null || echo 100)
    if [ "$BAT_CAP" -le 10 ] && [ "$LAST_ALERT" -gt 10 ]; then
        notify-send -u critical "battery critical (${BAT_CAP}%)" "connect power adapter immediately"
        echo 10 > "$ALERT_FILE"
    elif [ "$BAT_CAP" -le 20 ] && [ "$LAST_ALERT" -gt 20 ]; then
        notify-send -u normal "battery low (${BAT_CAP}%)" "connect charger or enable power-saver"
        echo 20 > "$ALERT_FILE"
    fi
else
    rm -f "$ALERT_FILE" 2>/dev/null
fi

if command -v bluetoothctl >/dev/null 2>&1; then
    BT_POWER=$(bluetoothctl show 2>/dev/null | grep -q 'Powered: yes' && echo on || echo off)
    BT_DEV=$(bluetoothctl info 2>/dev/null | awk -F': ' '/Alias:/ {print $2; exit}')
else
    BT_POWER="off"
    BT_DEV=""
fi

if command -v nmcli >/dev/null 2>&1; then
    WIFI_RADIO=$(nmcli -t -f WIFI g 2>/dev/null || echo enabled)
    WIFI_LINE=$(nmcli -t -f active,ssid,signal,security dev wifi list --rescan no 2>/dev/null | grep '^yes:' | head -n1)
    ETH_CON=$(nmcli -t -f TYPE,STATE dev 2>/dev/null | grep '^ethernet:connected' | head -n1)
else
    WIFI_RADIO="enabled"
    WIFI_LINE=""
    ETH_CON=""
fi
IP_ADDR=$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src") print $(i+1)}' | head -n1)

PODS_JSON=$(python3 "$HOME/.config/quickshell/scripts/omapods-ctl.py" status 2>/dev/null || echo '{"running":false,"connected":false,"barPct":-1}')

printf '%s@@SEP@@%s@@SEP@@%s@@SEP@@%s@@SEP@@%s@@SEP@@%s@@SEP@@%s@@SEP@@%s@@SEP@@%s@@SEP@@%s@@SEP@@%s@@SEP@@%s@@SEP@@%s@@SEP@@%s@@SEP@@%s@@SEP@@%s@@SEP@@%s@@SEP@@%s\n' \
    "$WIN" "$MODE" "$MUTED" "$VOL" "$BRIGHT" "$BAT_CAP" "$BAT_STATUS" "$BT_POWER" "$BT_DEV" "$WIFI_RADIO" "$WIFI_LINE" "$ETH_CON" "$IP_ADDR" "$BAT_W" "$PWR_PROF" "$PODS_JSON" "$SINK_DESC" "$MIC_STATE"
