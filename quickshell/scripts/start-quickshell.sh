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

# Quickshell ne supprime jamais le dossier d'une instance arrêtée : son journal (log.qslog,
# parfois des centaines de Mo) resterait en RAM dans /run/user jusqu'à la déconnexion.
# On efface les instances mortes ; $1 = identifiant à garder (dernier plantage, pour `qs log`).
QS_RUN="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/quickshell"
clean_dead_instances() {
    [ -d "$QS_RUN/by-id" ] || return 0
    local keep=" $1 " link target dir id
    for link in "$QS_RUN"/by-pid/*; do
        [ -L "$link" ] || continue
        if kill -0 "${link##*/}" 2>/dev/null; then
            target=$(readlink "$link")
            keep="$keep${target##*/} "
        fi
    done
    for dir in "$QS_RUN"/by-id/*/; do
        [ -d "$dir" ] || continue
        id=${dir%/}
        id=${id##*/}
        case "$keep" in
            *" $id "*) ;;
            *) rm -rf -- "$dir" ;;
        esac
    done
    find "$QS_RUN" -xtype l -delete 2>/dev/null
    return 0
}
clean_dead_instances ""

# Boucle superviseur en arrière-plan
(
    last=""
    while true; do
        clean_dead_instances "$last"
        quickshell >>/tmp/quickshell.log 2>&1 &
        qpid=$!
        wait "$qpid"
        # Instance qui vient de s'arrêter : son journal est gardé jusqu'au prochain arrêt
        last=$(readlink "$QS_RUN/by-pid/$qpid" 2>/dev/null)
        last=${last##*/}
        sleep 0.5
    done
) >/dev/null 2>&1 &
disown
