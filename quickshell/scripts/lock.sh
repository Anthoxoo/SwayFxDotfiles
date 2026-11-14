#!/usr/bin/env bash
FIFO="/tmp/quickshell-ipc.fifo"
if [ -p "$FIFO" ]; then
    printf "lock-screen\n" > "$FIFO" &
fi
