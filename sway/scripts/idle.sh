#!/usr/bin/env bash
# Gestion de l'inactivité (une seule instance) :
#   30 min -> verrouillage
#   31 min -> écrans éteints (rallumés à la reprise)
#   veille -> verrouillage avant suspension (lock.sh attend la confirmation du verrou)
LOCK="$HOME/.config/quickshell/scripts/lock.sh"

pkill -x swayidle 2>/dev/null
exec swayidle -w \
    timeout 1800 "$LOCK" \
    timeout 1860 'swaymsg "output * power off"' \
        resume 'swaymsg "output * power on"' \
    before-sleep "$LOCK" \
    after-resume 'swaymsg "output * power on"' \
    idlehint 1800
