#!/usr/bin/env bash
# notif-ctl.sh clear-notifs | toggle-dnd
case "$1" in
    clear-notifs) exec qs ipc call shell clearNotifs >/dev/null 2>&1 ;;
    toggle-dnd)   exec qs ipc call shell toggleDnd >/dev/null 2>&1 ;;
    *) echo "usage: $0 clear-notifs|toggle-dnd" >&2; exit 1 ;;
esac
