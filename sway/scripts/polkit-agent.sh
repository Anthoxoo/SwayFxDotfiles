#!/bin/sh
# Fallback polkit authentication agent: Quickshell is the agent (modules/PolkitDialog.qml) and
# runs this only when it can't register. Starts the first desktop agent found (paths differ
# between Debian and Arch), unless one already runs.
pgrep -f 'polkit-(kde|gnome)-authentication-agent-1' >/dev/null && exit 0
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
