#!/bin/sh
# Starts the first polkit authentication agent found (paths differ between Debian and Arch).
for agent in \
    /usr/lib/x86_64-linux-gnu/libexec/polkit-kde-authentication-agent-1 \
    /usr/lib/polkit-kde-authentication-agent-1 \
    /usr/libexec/polkit-kde-authentication-agent-1 \
    /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 \
    /usr/libexec/polkit-gnome-authentication-agent-1; do
    [ -x "$agent" ] && exec "$agent"
done
echo "polkit-agent.sh: no polkit agent found" >&2
exit 1
