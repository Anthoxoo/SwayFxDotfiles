#!/usr/bin/env bash

set -e

# Trouver tous les profils Firefox actifs (natif Debian/ESR et Flatpak)
mapfile -t PREF_FILES < <(find "$HOME/.mozilla/firefox" "$HOME/.var/app/org.mozilla.firefox/.mozilla/firefox" -maxdepth 3 -name "prefs.js" 2>/dev/null)

if [ ${#PREF_FILES[@]} -eq 0 ]; then
    echo "Aucun profil Firefox trouvé."
    exit 1
fi

for PREF in "${PREF_FILES[@]}"; do
    PROFILE="$(dirname "$PREF")"
    echo "Injection du thème Omarchy dans : $(basename "$PROFILE")"
    mkdir -p "$PROFILE/chrome"

    # 1. Préférences (user.js)
    cat << 'USERJS' > "$PROFILE/user.js"
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
user_pref("nglayout.debug.disable_xul_cache", true);
user_pref("ui.systemUsesDarkTheme", 1);
user_pref("browser.in-content.dark-mode", true);
user_pref("browser.display.background_color", "#141416");
USERJS

    sed -i '/toolkit.legacyUserProfileCustomizations.stylesheets/d' "$PROFILE/prefs.js" 2>/dev/null || true
    echo 'user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);' >> "$PROFILE/prefs.js"

    # 2. Interface globale + Onglets + Barre des favoris (userChrome.css)
    cat << 'CHROME' > "$PROFILE/chrome/userChrome.css"
:root,
#main-window,
#navigator-toolbox {
    --omarchy-bg: #141416;
    --omarchy-bg-alt: #1e1e20;
    --omarchy-border: #2a2a2c;
    --omarchy-fg: #e5e5e5;
    --omarchy-muted: #8a8a8d;
    --omarchy-accent: #ff8800;

    --toolbar-bgcolor: #141416 !important;
    --toolbar-color: #e5e5e5 !important;
    --lwt-accent-color: #141416 !important;
    --lwt-text-color: #e5e5e5 !important;
    --lwt-header-image: none !important;
    --lwt-additional-images: none !important;
    --toolbar-field-background-color: #1e1e20 !important;
    --toolbar-field-color: #e5e5e5 !important;
    --toolbar-field-border-color: #2a2a2c !important;
    --toolbar-field-focus-background-color: #141416 !important;
    --toolbar-field-focus-color: #e5e5e5 !important;
    --toolbar-field-focus-border-color: #ff8800 !important;
    --arrowpanel-background: #141416 !important;
    --arrowpanel-color: #e5e5e5 !important;
    --arrowpanel-border-color: #ff8800 !important;
    --arrowpanel-border-radius: 0px !important;
    --tab-border-radius: 0px !important;
    --toolbarbutton-border-radius: 0px !important;
    --tabpanel-background-color: #141416 !important;
}

* {
    font-family: "JetBrainsMono Nerd Font", monospace !important;
    border-radius: 0px !important;
}

/* Masquer les boutons réduire / agrandir / fermer et les espaces vides associés */
.titlebar-buttonbox-container,
.titlebar-buttonbox,
.titlebar-min,
.titlebar-max,
.titlebar-restore,
.titlebar-close,
.titlebar-spacer {
    display: none !important;
}

/* Toutes les barres d'outils (Onglets, Navigation, Barre des favoris) */
#navigator-toolbox,
#titlebar,
#TabsToolbar,
#nav-bar,
#PersonalToolbar,
toolbar#PersonalToolbar,
.browser-toolbar {
    appearance: none !important;
    -moz-default-appearance: none !important;
    background: #141416 !important;
    background-color: #141416 !important;
    background-image: none !important;
    color: #e5e5e5 !important;
    box-shadow: none !important;
    border: none !important;
}

/* Onglets */
.tabbrowser-tab {
    padding: 0 !important;
    margin: 0 !important;
}

.tabbrowser-tab .tab-background {
    background: #141416 !important;
    background-color: #141416 !important;
    border: none !important;
    margin: 0 !important;
    box-shadow: none !important;
}

.tabbrowser-tab:hover .tab-background:not([selected="true"]):not([visuallyselected="true"]) {
    background: #1e1e20 !important;
    background-color: #1e1e20 !important;
}

/* Onglet actif avec sa barre orange en bas */
.tabbrowser-tab[selected="true"] .tab-background,
.tabbrowser-tab[visuallyselected="true"] .tab-background,
.tab-background[selected="true"],
.tab-background[visuallyselected="true"] {
    background: #1e1e20 !important;
    background-color: #1e1e20 !important;
    box-shadow: inset 0 -1px 0 0 #ff8800 !important;
}

.tabbrowser-tab .tab-label {
    color: #8a8a8d !important;
}

.tabbrowser-tab[selected="true"] .tab-label,
.tabbrowser-tab[visuallyselected="true"] .tab-label {
    color: #e5e5e5 !important;
    font-weight: bold !important;
}

/* Masquer le séparateur vertical entre les onglets */
.tabbrowser-tab::after,
.tabbrowser-tab::before {
    border: none !important;
    display: none !important;
}

/* Barre d'adresse (URL) */
#nav-bar {
    border-top: 1px solid #2a2a2c !important;
    border-bottom: 1px solid #2a2a2c !important;
}

#urlbar-background,
#searchbar {
    appearance: none !important;
    background: #1e1e20 !important;
    background-color: #1e1e20 !important;
    border: 1px solid #2a2a2c !important;
    box-shadow: none !important;
}

#urlbar[focused="true"] > #urlbar-background {
    background-color: #141416 !important;
    border: 1px solid #ff8800 !important;
    box-shadow: none !important;
}

.urlbarView {
    background-color: #141416 !important;
    color: #e5e5e5 !important;
    border-top: 1px solid #ff8800 !important;
}

.urlbarView-row[selected] {
    background-color: #1e1e20 !important;
    color: #ff8800 !important;
}

/* Barre des favoris (Bookmarks Toolbar sur l'écran Home) */
toolbar#PersonalToolbar,
#PersonalToolbar,
#personal-bookmarks,
#PlacesToolbar,
#PlacesToolbarItems {
    appearance: none !important;
    -moz-default-appearance: none !important;
    background: #141416 !important;
    background-color: #141416 !important;
    background-image: none !important;
    color: #e5e5e5 !important;
}

toolbar#PersonalToolbar,
#PersonalToolbar {
    border-bottom: 1px solid #2a2a2c !important;
    padding: 2px 6px !important;
}

#PersonalToolbar toolbarbutton.bookmark-item,
#PlacesToolbarItems > .bookmark-item {
    appearance: none !important;
    color: #e5e5e5 !important;
    background: transparent !important;
    background-color: transparent !important;
    padding: 3px 8px !important;
    margin: 0 2px !important;
}

#PersonalToolbar toolbarbutton.bookmark-item:hover,
#PersonalToolbar toolbarbutton.bookmark-item[open="true"],
#PlacesToolbarItems > .bookmark-item:hover {
    background-color: #1e1e20 !important;
    color: #ff8800 !important;
}

/* Boutons d'outils & Menus */
toolbar .toolbarbutton-1:hover > .toolbarbutton-icon,
toolbar .toolbarbutton-1:hover > .toolbarbutton-badge-stack {
    background-color: #1e1e20 !important;
    color: #ff8800 !important;
}

menupopup,
panel {
    --panel-background: #141416 !important;
    --panel-color: #e5e5e5 !important;
    --panel-border-color: #ff8800 !important;
    --panel-border-radius: 0px !important;
}

menuitem:hover,
menu:hover,
menuitem[_moz-menuactive="true"],
menu[_moz-menuactive="true"] {
    background-color: #1e1e20 !important;
    color: #ff8800 !important;
}

#sidebar-box,
#sidebar-header {
    background-color: #141416 !important;
    color: #e5e5e5 !important;
    border-color: #2a2a2c !important;
}
CHROME

    # 3. Écran Home / Nouvel Onglet (userContent.css)
    cat << 'CONTENT' > "$PROFILE/chrome/userContent.css"
@-moz-document url("about:home"), url("about:newtab"), url("about:privatebrowsing") {
    :root {
        --newtab-background-color: #141416 !important;
        --newtab-background-color-secondary: #1e1e20 !important;
        --newtab-text-primary-color: #e5e5e5 !important;
        --newtab-primary-action-background: #ff8800 !important;
    }

    html, body, #root, main, .outer-wrapper, .discovery-stream {
        background-color: #141416 !important;
        color: #e5e5e5 !important;
        font-family: "JetBrainsMono Nerd Font", monospace !important;
    }

    .search-wrapper,
    .search-inner-wrapper {
        background-color: transparent !important;
    }

    .search-wrapper .search-handoff-button,
    .search-wrapper input {
        background-color: #1e1e20 !important;
        color: #e5e5e5 !important;
        border: 1px solid #ff8800 !important;
        border-radius: 0px !important;
        box-shadow: none !important;
    }

    .top-site-outer {
        background-color: transparent !important;
    }

    .top-site-outer .tile {
        background-color: #1e1e20 !important;
        border: 1px solid #2a2a2c !important;
        border-radius: 0px !important;
        box-shadow: none !important;
    }

    .top-site-outer:hover .tile {
        border-color: #ff8800 !important;
    }
}

@-moz-document url("about:blank") {
    html, body {
        background-color: #141416 !important;
    }
}
CONTENT
done

# 4. Vider le cache CSS de Firefox pour forcer la prise en compte immédiate
rm -rf "$HOME/.cache/mozilla/firefox/"*/startupCache 2>/dev/null || true
rm -rf "$HOME/.var/app/org.mozilla.firefox/cache/mozilla/firefox/"*/startupCache 2>/dev/null || true

echo "Thème injecté et cache vidé ! Redémarre Firefox (Ctrl+Q) pour voir le changement."
