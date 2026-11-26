# Thèmes

Système de thèmes global, inspiré d'omarchy : une commande change les couleurs de tout le bureau
d'un coup (Quickshell, fenêtres sway, GTK 3/4, icônes, alacritty, Neovim, fond d'écran).

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

## Créer un thème

Copier un dossier existant et modifier `colors.toml`. Seuls `background`, `foreground`, `accent`
et `color0` à `color15` (palette terminal, format omarchy) sont obligatoires : les sections
`[ui]` (surfaces et texte de l'interface), `[syntax]` (Neovim) et `[gtk]` (`icon_theme`,
`gnome_accent`) sont facultatives, chaque valeur absente est dérivée des couleurs de base.
La liste complète des clés est dans `resolve()` du script, et `current/palette.json` montre les
valeurs résolues.

Un thème peut aussi remplacer un template entier en fournissant un fichier du même nom
(par ex. `<id>/alacritty.toml`).

Dans les templates : `{{ cle }}` → `#rrggbb`, `{{ cle_strip }}` → `rrggbb`,
`{{ cle_rgb }}` → `r, g, b`. Une clé inconnue fait échouer le rendu avant toute écriture.

## Première installation

`current/` n'est pas versionné : lancer une fois `~/.config/themes/theme set orange-black`.
Sans lui, Quickshell et Neovim retombent sur Orange Black, mais sway, GTK et alacritty n'ont
pas de couleurs.

## À faire

- Zed (générer un thème depuis la palette), btop, Firefox.
- Thèmes clairs : le moteur gère `mode = "light"`, aucun thème clair n'est encore fourni.
