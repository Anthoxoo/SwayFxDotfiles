#!/usr/bin/env bash
# Capture d'écran : region | window | output | region-edit
# - enregistre dans ~/Pictures/Screenshots (créé si besoin)
# - copie dans le presse-papiers
# - "region-edit" ouvre swappy s'il est installé (sinon simple capture)
set -euo pipefail

MODE="${1:-region}"
DIR="$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")/Screenshots"
mkdir -p "$DIR"
FILE="$DIR/Screenshot_$(date +%Y%m%d-%H%M%S).png"

case "$MODE" in
    region|region-edit)
        GEOM="$(slurp -d)" || exit 0
        grim -g "$GEOM" "$FILE"
        ;;
    window)
        GEOM="$(swaymsg -t get_tree | jq -r '.. | select(.pid? and .visible?) | .rect | "\(.x),\(.y) \(.width)x\(.height)"' | slurp)" || exit 0
        grim -g "$GEOM" "$FILE"
        ;;
    output)
        OUT="$(swaymsg -t get_outputs | jq -r '.[] | select(.focused).name')"
        grim -o "$OUT" "$FILE"
        ;;
    *)
        echo "usage: $0 region|region-edit|window|output" >&2
        exit 1
        ;;
esac

wl-copy --type image/png < "$FILE"

if [ "$MODE" = "region-edit" ] && command -v swappy >/dev/null 2>&1; then
    swappy -f "$FILE" -o "$FILE"
fi

notify-send -a screenshot -i "$FILE" "screenshot saved" "$(basename "$FILE") · copied to clipboard" 2>/dev/null || true
