#!/usr/bin/env bash
# Prepares Firefox and Zen for the global theme, once:
#  - Firefox profiles (native and Flatpak) get chrome/, so `theme` writes userChrome.css,
#    userContent.css and user.js on every switch
#  - every Firefox and Zen profile gets the Theme Sync extension
#    (extensions/theme-sync@local.xpi, sideloaded: the browser asks to enable it at the next
#    start) and its native host, which push the colors live
#  - every Zen profile gets firefox/zen-userChrome.css, which maps Zen's own colors onto the
#    theme (Firefox's userChrome would fight Zen's layout)
# Needs a browser restart once; afterwards theme switches apply without restarting.
set -euo pipefail

here=$(dirname "$(readlink -f "$0")")
ext="$here/firefox/extension"
signed="$here/firefox/theme-sync.xpi"

profiles_in() {  # profile directories (those with a prefs.js) under the given roots
    find "$@" -mindepth 1 -maxdepth 2 -name prefs.js -printf '%h\n' 2>/dev/null || true
}
# Firefox: ~/.mozilla (classic) or ~/.config/mozilla (XDG layout of recent versions, e.g. Arch)
mapfile -t firefox < <(profiles_in "$HOME/.mozilla/firefox" "$HOME/.config/mozilla/firefox" \
    "$HOME/.var/app/org.mozilla.firefox/.mozilla/firefox")
mapfile -t zen < <(profiles_in "$HOME/.zen" "$HOME/.config/zen" \
    "$HOME/.var/app/app.zen_browser.zen/.zen" "$HOME/.var/app/app.zen_browser.zen/zen")
if [ ${#firefox[@]} -eq 0 ] && [ ${#zen[@]} -eq 0 ]; then
    echo "No Firefox or Zen profile found (start the browser once)." >&2
    exit 1
fi

# The extension: the signed one (firefox/sign.py) if it matches the manifest, else unsigned
want=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"])' "$ext/manifest.json")
have=$(python3 -c 'import json,sys,zipfile; print(json.loads(zipfile.ZipFile(sys.argv[1]).read("manifest.json"))["version"])' \
    "$signed" 2>/dev/null || true)
xpi=$(mktemp --suffix=.xpi)
trap 'rm -f "$xpi"' EXIT
if [ "$have" = "$want" ]; then
    cp "$signed" "$xpi"
    echo "Theme Sync $want (signed)"
else
    rm -f "$xpi"
    (cd "$ext" && python3 -m zipfile -c "$xpi" manifest.json background.js newtab.html newtab.js)
    echo "Theme Sync $want UNSIGNED (only Firefox ESR/Developer/Nightly load it): run firefox/sign.py"
fi

for profile in "${firefox[@]}" "${zen[@]}"; do
    echo "Profile: $profile"
    mkdir -p "$profile/extensions"
    install -m644 "$xpi" "$profile/extensions/theme-sync@local.xpi"
done
for profile in "${firefox[@]}"; do
    mkdir -p "$profile/chrome"
done

# Zen drops every extension theme by default (zen.theme.disable-lightweight) and ignores most
# of the theme API anyway: the pref lets Theme Sync's theme through, and Zen's own userChrome
# maps Zen's variables onto the theme API ones (live). Zen only reads userChrome.css with the
# legacy stylesheets pref on. A userChrome.css that doesn't come from here is kept as .bak.
zen_prefs=(
    'toolkit.legacyUserProfileCustomizations.stylesheets|true'
    'zen.theme.disable-lightweight|false'
)
for profile in "${zen[@]}"; do
    mkdir -p "$profile/chrome"
    css="$profile/chrome/userChrome.css"
    if [ -f "$css" ] && ! grep -q 'Zen: follows the global theme' "$css"; then
        mv "$css" "$css.bak"
    fi
    install -m644 "$here/firefox/zen-userChrome.css" "$css"
    touch "$profile/user.js"
    for p in "${zen_prefs[@]}"; do
        name=${p%%|*}
        sed -i "/user_pref(\"${name//./\\.}\",/d" "$profile/user.js"  # same pref, other value
        echo "user_pref(\"$name\", ${p#*|});" >> "$profile/user.js"
    done
done

# Native messaging host: Firefox reads ~/.mozilla/native-messaging-hosts (or
# ~/.config/mozilla/native-messaging-hosts with the XDG layout); Zen has used ~/.zen and
# ~/.config/zen depending on its version, so the manifest goes in every one that exists.
# (Flatpak browsers would need the portal: not handled.)
host_dirs=("$HOME/.mozilla/native-messaging-hosts")
for d in "$HOME/.config/mozilla" "$HOME/.zen" "$HOME/.config/zen"; do
    [ -d "$d" ] && host_dirs+=("$d/native-messaging-hosts")
done
for host_dir in "${host_dirs[@]}"; do
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
done

"$here/theme" apply
rm -rf "$HOME/.cache/mozilla/firefox/"*/startupCache "$HOME/.cache/zen/"*/startupCache 2>/dev/null || true
echo "Restart the browser once and enable \"Theme Sync\" when it asks."
