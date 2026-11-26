#!/usr/bin/env bash
# Prepares Firefox (native and Flatpak profiles) for the global theme, once:
#  - chrome/ so `theme` writes userChrome.css, userContent.css and user.js on every switch
#  - the Theme Sync extension (extensions/theme-sync@local.xpi, sideloaded: Firefox asks to
#    enable it at the next start) and its native host, which push colors live
# Needs a Firefox restart once; afterwards theme switches apply without restarting.
set -euo pipefail

here=$(dirname "$(readlink -f "$0")")
mapfile -t prefs < <(find "$HOME/.mozilla/firefox" "$HOME/.var/app/org.mozilla.firefox/.mozilla/firefox" \
    -maxdepth 2 -name prefs.js 2>/dev/null)
if [ ${#prefs[@]} -eq 0 ]; then
    echo "No Firefox profile found (start Firefox once)." >&2
    exit 1
fi

xpi=$(mktemp --suffix=.xpi)
trap 'rm -f "$xpi"' EXIT
rm -f "$xpi"
(cd "$here/firefox/extension" && python3 -m zipfile -c "$xpi" manifest.json background.js)

for pref in "${prefs[@]}"; do
    profile=$(dirname "$pref")
    echo "Profile: $(basename "$profile")"
    mkdir -p "$profile/chrome" "$profile/extensions"
    install -m644 "$xpi" "$profile/extensions/theme-sync@local.xpi"
done

# Native messaging host (native Firefox; Flatpak would need the portal, not handled here)
host_dir="$HOME/.mozilla/native-messaging-hosts"
mkdir -p "$host_dir"
cat > "$host_dir/theme_sync.json" <<JSON
{
  "name": "theme_sync",
  "description": "Pushes ~/.config/themes/current/palette.json to the Theme Sync extension",
  "path": "$here/firefox/theme-sync-host",
  "type": "stdio",
  "allowed_extensions": ["theme-sync@local"]
}
JSON

"$here/theme" apply
rm -rf "$HOME/.cache/mozilla/firefox/"*/startupCache 2>/dev/null || true
echo "Restart Firefox (Ctrl+Q) once and enable \"Theme Sync\" when it asks."
