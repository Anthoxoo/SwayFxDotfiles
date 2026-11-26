#!/usr/bin/env bash
# Prépare les profils Firefox (natif et Flatpak) pour le thème global : active userChrome.css
# et crée chrome/. Les couleurs (userChrome.css, userContent.css, user.js) sont ensuite écrites
# par `theme` à chaque changement de thème ; Firefox les relit à son redémarrage.
set -euo pipefail

mapfile -t prefs < <(find "$HOME/.mozilla/firefox" "$HOME/.var/app/org.mozilla.firefox/.mozilla/firefox" \
    -maxdepth 2 -name prefs.js 2>/dev/null)
if [ ${#prefs[@]} -eq 0 ]; then
    echo "Aucun profil Firefox trouvé (lancer Firefox une fois)." >&2
    exit 1
fi

for pref in "${prefs[@]}"; do
    profile=$(dirname "$pref")
    echo "Profil : $(basename "$profile")"
    mkdir -p "$profile/chrome"
done

"$(dirname "$(readlink -f "$0")")/theme" apply
rm -rf "$HOME/.cache/mozilla/firefox/"*/startupCache 2>/dev/null || true
echo "Redémarrer Firefox (Ctrl+Q) pour appliquer le thème."
