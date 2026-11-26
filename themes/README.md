# Thèmes

Système de thèmes global, inspiré d'omarchy : une commande change les couleurs de tout le bureau
d'un coup (Quickshell, fenêtres sway, GTK 3/4, icônes, alacritty, Neovim, Zed, btop, fuzzel,
Firefox, fond d'écran).

```sh
~/.config/themes/theme list           # * = thème courant
~/.config/themes/theme set kanagawa
~/.config/themes/theme next | prev
~/.config/themes/theme apply          # régénère le thème courant (après avoir modifié un template)
```

Sélecteur dans Quickshell : `$mod+Shift+t`, ou `qs ipc call theme set <id>`.

## Organisation

```
themes/
├── theme                 script (Python 3.11+, aucune dépendance)
├── templates/            un fichier par application, rendu dans current/
├── <id>/colors.toml      palette du thème
├── <id>/backgrounds      fonds d'écran (lien vers ../../walls/<dossier>)
└── current/              généré, ignoré par git
```

`theme set` écrit `current/` (palette.json + templates rendus), puis applique le thème aux
applications ouvertes :

| Application | Fichier lu                               | Rechargement                          |
|-------------|------------------------------------------|---------------------------------------|
| Quickshell  | `current/palette.json` (`core/Theme.qml`) | surveillance du fichier               |
| Fond d'écran| `backgrounds` du thème (`core/Wallpapers.qml`) | premier fond du thème ; `$mod+Ctrl+space` parcourt ceux du thème |
| sway        | `current/sway.conf` (inclus par `sway/config.d/theme`) | `swaymsg client.*` (pas de reload, qui relancerait Quickshell) |
| GTK 3 / 4   | `current/gtk-3.0.css`, `gtk-4.0.css` (importés par `~/.config/gtk-*/gtk.css`) | gsettings : thème GTK, color-scheme, accent, icônes |
| alacritty   | `current/alacritty.toml` (`general.import`) | rechargement à chaud d'alacritty     |
| Neovim      | `current/palette.json` (`colors/theme.lua`) | SIGUSR1 → `:colorscheme theme`       |
| Zed         | `~/.config/zed/themes/theme.json` (copie de `current/zed.json`), thème « Theme » dans settings.json | Zed surveille son dossier de thèmes |
| btop        | `~/.config/btop/themes/theme.theme`, `color_theme = "theme"` | SIGUSR2 (relit btop.conf)            |
| fuzzel      | `current/fuzzel.ini` (`include=` dans fuzzel.ini) | à chaque lancement                  |
| Firefox     | `chrome/userChrome.css`, `userContent.css`, `user.js` des profils préparés par `firefox-setup.sh` | au redémarrage de Firefox |

## Créer un thème

Copier un dossier existant et modifier `colors.toml`. Seuls `background`, `foreground`, `accent`
et `color0` à `color15` (palette terminal, format omarchy) sont obligatoires : les sections
`[ui]` (surfaces et texte de l'interface), `[syntax]` (Neovim, Zed) et `[gtk]` (`icon_theme`,
`gnome_accent`) sont facultatives, chaque valeur absente est dérivée des couleurs de base.
La liste complète des clés est dans `resolve()` du script, et `current/palette.json` montre les
valeurs résolues.

Un thème peut aussi remplacer un template entier en fournissant un fichier du même nom
(par ex. `<id>/alacritty.toml`). Orange Black le fait pour Zed : `orange-black/zed.json` est le
thème Zed d'origine à l'identique.

Dans les templates : `{{ cle }}` → `#rrggbb`, `{{ cle_strip }}` → `rrggbb`,
`{{ cle_rgb }}` → `r, g, b`. Une clé inconnue fait échouer le rendu avant toute écriture.

## Thèmes fournis

| id           | Fonds (`walls/`)    | Accent  |
|--------------|---------------------|---------|
| orange-black | orange-black        | orange  |
| gruvbox      | yellow-orange-ish   | jaune   |
| rosso        | red-ish             | rouge   |
| kanagawa     | blue-ish            | bleu    |
| everforest   | green-nature        | vert    |
| monochrome   | black-white-ish     | gris    |

## Première installation

`current/` n'est pas versionné : lancer une fois `~/.config/themes/theme set orange-black`.
Sans lui, Quickshell et Neovim retombent sur Orange Black, mais sway, GTK et alacritty n'ont
pas de couleurs. Pour Firefox, lancer aussi `~/.config/themes/firefox-setup.sh`.
