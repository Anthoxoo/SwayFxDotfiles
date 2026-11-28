#!/usr/bin/env bash
# Screenshots. Selecting is done by Quickshell (quickshell/modules/Screenshot.qml: a region, a
# window or a screen, on frozen screens); this script captures and saves:
#   screenshot.sh output                            the focused screen, right away
#   screenshot.sh save <image> <geometry> [edit]    from Quickshell: <image> is a frozen screen,
#                                                   <geometry> WxH+X+Y in its pixels (or "full")
# The shot goes to ~/Pictures/Screenshots and to the clipboard; "edit" opens it in swappy first.
# The notification offers open (click) / edit / delete.
set -euo pipefail

DIR="$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")/Screenshots"
mkdir -p "$DIR"
FILE="$DIR/Screenshot_$(date +%Y%m%d-%H%M%S).png"
EDIT=""

case "${1:-}" in
    output)
        OUT="$(swaymsg -t get_outputs | jq -r '.[] | select(.focused).name')"
        grim -o "$OUT" "$FILE"
        ;;
    save)
        SRC="$2" GEOM="$3" EDIT="${4:-}"
        if command -v magick >/dev/null 2>&1; then
            crop=()
            [ "$GEOM" != full ] && crop=(-crop "$GEOM" +repage)
            magick "$SRC" "${crop[@]}" "$FILE"
        else
            python3 - "$SRC" "$GEOM" "$FILE" <<'PY'
import sys
from PIL import Image
src, geom, dst = sys.argv[1:]
im = Image.open(src)
if geom != "full":
    size, x, y = geom.split("+")
    w, h = size.split("x")
    x, y, w, h = int(x), int(y), int(w), int(h)
    im = im.crop((x, y, x + w, y + h))
im.save(dst)
PY
        fi
        # The frozen screens (Quickshell's, in $XDG_RUNTIME_DIR/qs-screenshot) aren't needed anymore
        rm -f -- "$(dirname -- "$SRC")"/*.ppm
        ;;
    *)
        echo "usage: $0 output | save <image> <geometry|full> [edit]" >&2
        exit 1
        ;;
esac

edit() {
    command -v swappy >/dev/null 2>&1 || return 0
    swappy -f "$FILE" -o "$FILE"
}

[ "$EDIT" = edit ] && edit
wl-copy --type image/png < "$FILE"

action=$(notify-send -a screenshot -i "$FILE" -A default=open -A edit=edit -A delete=delete \
    "screenshot saved" "$(basename "$FILE") · copied to clipboard" 2>/dev/null) || true
case "$action" in
    default) xdg-open "$FILE" >/dev/null 2>&1 & ;;
    edit) edit && wl-copy --type image/png < "$FILE" ;;
    delete) gio trash "$FILE" 2>/dev/null || rm -f "$FILE" ;;
esac
