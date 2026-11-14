#!/usr/bin/env bash
# Verrouille l'écran via Quickshell (ext-session-lock) et attend que sway confirme le verrou,
# pour que `swayidle before-sleep` ne laisse pas la machine se suspendre déverrouillée.
qs ipc call lock lock >/dev/null 2>&1 || exit 1
for _ in $(seq 1 30); do
    [ "$(qs ipc call lock isLocked 2>/dev/null)" = "true" ] && exit 0
    sleep 0.1
done
exit 0
