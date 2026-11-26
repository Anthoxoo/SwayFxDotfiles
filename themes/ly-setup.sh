#!/usr/bin/env bash
# Themes the ly login screen (and every text console) with the global theme. Run once, as root:
#
#   sudo ~/.config/themes/ly-setup.sh            set it up
#   sudo ~/.config/themes/ly-setup.sh --remove   undo it
#
# ly draws on the Linux console, which can't show 24-bit colors (orange comes out yellow).
# So the console's 16-color palette itself is recolored, from current/vtrgb (rendered by
# `theme` from templates/vtrgb: background, terminal colors, foreground, accent in slot 11), and
# ly uses palette colors (eight-color mode). The palette is applied at every boot by
# console-theme.service, before ly starts: switch the theme, and ly follows from the next boot.
#
# Changes: /etc/systemd/system/console-theme.service (new) and the color keys of
# /etc/ly/config.ini (backed up once as config.ini.pre-theme).
set -euo pipefail

[ "$(id -u)" -eq 0 ] || { echo "Run it with sudo." >&2; exit 1; }
user=${SUDO_USER:-}
[ -n "$user" ] && [ "$user" != root ] || { echo "Run it with sudo from your user account." >&2; exit 1; }
home=$(getent passwd "$user" | cut -d: -f6)
palette="$home/.config/themes/current/vtrgb"
unit=/etc/systemd/system/console-theme.service
ly_conf=/etc/ly/config.ini

if [ "${1:-}" = "--remove" ]; then
    systemctl disable --now console-theme.service 2>/dev/null || true
    rm -f "$unit"
    systemctl daemon-reload
    [ -f "$ly_conf.pre-theme" ] && cp "$ly_conf.pre-theme" "$ly_conf"
    setvtrgb vga || true
    echo "Removed: default console palette and ly config restored."
    exit 0
fi

[ -f "$palette" ] || { echo "$palette is missing: run ~/.config/themes/theme apply first." >&2; exit 1; }
[ -f "$ly_conf" ] || { echo "$ly_conf not found: is ly installed?" >&2; exit 1; }

# Start before every ly instance and the first getty, after Plymouth has given the console back
before="getty@tty1.service"
for u in $(systemctl list-units --all --type=service --plain --no-legend 'ly*' | awk '{print $1}'); do
    before="$before $u"
done

cat > "$unit" <<EOF
[Unit]
Description=Linux console palette from the desktop theme (~/.config/themes)
After=systemd-vconsole-setup.service plymouth-quit.service plymouth-quit-wait.service
Before=$before
RequiresMountsFor=$palette
ConditionPathExists=$palette

[Service]
Type=oneshot
ExecStart=/usr/bin/setvtrgb $palette

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable console-theme.service

# ly: palette colors (0x00 = no style, 0x01 = bold, which the console shows as the bright slot)
[ -f "$ly_conf.pre-theme" ] || cp "$ly_conf" "$ly_conf.pre-theme"
set_key() {  # set_key <key> <value>: replace the line, or append it
    if grep -q "^$1 *=" "$ly_conf"; then
        sed -i "s|^$1 *=.*|$1 = $2|" "$ly_conf"
    else
        echo "$1 = $2" >> "$ly_conf"
    fi
}
set_key full_color false
set_key bg        0x00000000   # default background = slot 0 = theme background
set_key fg        0x00000008   # white                = slot 7 = theme foreground
set_key border_fg 0x01000004   # bright yellow        = slot 11 = theme accent
set_key error_bg  0x00000000
set_key error_fg  0x01000002   # bright red           = slot 9

setvtrgb "$palette"
echo "Done: the console palette follows the theme from the next boot (ly included)."
echo "Undo: sudo $0 --remove"
