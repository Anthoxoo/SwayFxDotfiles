#!/usr/bin/env bash
# Prepares Firefox profiles (native and Flatpak) for the global theme by creating chrome/.
# The colors (userChrome.css, userContent.css, user.js, which also enables userChrome) are then
# written by `theme` on every theme switch; Firefox reads them when it restarts.
set -euo pipefail

mapfile -t prefs < <(find "$HOME/.mozilla/firefox" "$HOME/.var/app/org.mozilla.firefox/.mozilla/firefox" \
    -maxdepth 2 -name prefs.js 2>/dev/null)
if [ ${#prefs[@]} -eq 0 ]; then
    echo "No Firefox profile found (start Firefox once)." >&2
    exit 1
fi

for pref in "${prefs[@]}"; do
    profile=$(dirname "$pref")
    echo "Profile: $(basename "$profile")"
    mkdir -p "$profile/chrome"
done

"$(dirname "$(readlink -f "$0")")/theme" apply
rm -rf "$HOME/.cache/mozilla/firefox/"*/startupCache 2>/dev/null || true
echo "Restart Firefox (Ctrl+Q) to apply the theme."
