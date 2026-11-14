#!/usr/bin/env bash
FIFO="/tmp/quickshell-ipc.fifo"
[ -p "$FIFO" ] && printf "toggle-launcher\n" > "$FIFO" &
