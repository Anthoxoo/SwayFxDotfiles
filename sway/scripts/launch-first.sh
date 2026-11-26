#!/bin/sh
# Runs the first of the given commands that exists, e.g. `launch-first.sh zen-browser firefox`:
# the same binding works on both machines (Zen on the desktop, Firefox on the laptop; `zed` vs
# Arch's `zeditor`).
for cmd in "$@"; do
    command -v "$cmd" >/dev/null 2>&1 && exec "$cmd"
done
notify-send "sway" "none of these is installed: $*"
exit 1
