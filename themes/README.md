# Themes

Global theme system, omarchy-style: one command recolors the whole desktop at once
(Quickshell, sway windows, GTK 3/4, icons, alacritty, zsh prompt and `ls` colors, Neovim, Zed,
btop, fuzzel, Firefox, wallpaper). Dark themes only.

```sh
~/.config/themes/theme list           # * = current theme
~/.config/themes/theme set nord
~/.config/themes/theme next | prev
~/.config/themes/theme apply          # re-render the current theme (after editing a template)
```

Picker in Quickshell: `Super+Shift+T` (↑/↓ or j/k to choose, Enter to apply, Esc to close),
or `qs ipc call theme set <id>` / `next` / `prev`.

## Layout

```
themes/
├── theme                 the script (Python 3.11+, no dependencies)
├── firefox-setup.sh      prepares Firefox profiles once (CSS, extension, native host)
├── ly-setup.sh           ly / text consoles follow the theme (run once with sudo)
├── firefox/              Theme Sync extension + its native messaging host
├── zsh/theme.zsh-theme   oh-my-zsh theme reading current/zsh.zsh
├── templates/            one file per application, rendered into current/
├── <id>/colors.toml      the theme's palette
├── <id>/backgrounds      wallpapers (link to ../../walls/<dir>)
└── current/              generated, ignored by git
```

`theme set` writes `current/` (palette.json + rendered templates), then applies the theme to
running applications:

| Application | Reads                                     | Reload                                 |
|-------------|-------------------------------------------|----------------------------------------|
| Quickshell  | `current/palette.json` (`core/Theme.qml`) | file watch                             |
| Wallpaper   | the theme's `backgrounds` (`core/Wallpapers.qml`) | first wallpaper of the theme; `Super+Ctrl+Space` cycles the theme's wallpapers |
| sway        | `current/sway.conf` (included by `sway/config.d/theme`) | `swaymsg client.*` (no reload, which would restart Quickshell) |
| GTK 3 / 4   | `current/gtk-3.0.css`, `gtk-4.0.css` (imported by `~/.config/gtk-*/gtk.css`) | gsettings: GTK theme, color-scheme, accent, icons |
| alacritty   | `current/alacritty.toml` (`general.import`) | alacritty hot reload                  |
| zsh         | `current/zsh.zsh` (prompt colors, `LS_COLORS`), sourced by `zsh/theme.zsh-theme` | re-read at the next prompt |
| Neovim      | `current/palette.json` (`colors/theme.lua`) | SIGUSR1 → `:colorscheme theme`        |
| Zed         | `~/.config/zed/themes/theme.json` (copy of `current/zed.json`), theme "Theme" in settings.json | Zed watches its themes directory |
| btop        | `~/.config/btop/themes/theme.theme`, `color_theme = "theme"` | SIGUSR2 (re-reads btop.conf)          |
| fuzzel      | `current/fuzzel.ini` (`include=` in fuzzel.ini) | on every launch                       |
| ly, consoles | `current/vtrgb` (16-color console palette; accent in slot 11), applied by `console-theme.service` from `ly-setup.sh` | at the next boot |
| Firefox     | theme API colors from the Theme Sync extension (`firefox/`); `userChrome.css` only reads Firefox's theme variables | live: the extension's native host watches `current/palette.json` |
| Zen         | the same extension; `firefox/zen-userChrome.css` maps Zen's `--zen-*` variables onto the theme API ones | live, like Firefox |

## Creating a theme

Copy an existing directory and edit `colors.toml`. Only `background`, `foreground`, `accent`
and `color0` to `color15` (terminal palette, omarchy format) are required. The `[ui]`
(interface surfaces and text), `[syntax]` (Neovim, Zed) and `[gtk]` (`icon_theme`,
`gnome_accent`) sections are optional: every missing value is derived from the base colors.
The full list of keys is in `resolve()` in the script, and `current/palette.json` shows the
resolved values.

A theme can also replace a whole template by shipping a file of the same name
(e.g. `<id>/alacritty.toml`). Orange Black does this for Zed: `orange-black/zed.json` is the
original Zed theme, unchanged.

In templates: `{{ key }}` → `#rrggbb`, `{{ key_strip }}` → `rrggbb`, `{{ key_rgb }}` → `r, g, b`,
`{{ key_ansi }}` → `r;g;b`.
An unknown key aborts the render before anything is written.

## Included themes

| id           | Accent | Palette |
|--------------|--------|---------|
| orange-black | orange | the original theme |
| red-black    | red    | Orange Black with a red accent (from the Porco Rosso wallpaper) |
| green-black  | lime   | Orange Black with a lime accent |
| gruvbox      | yellow | morhetz/gruvbox (dark) |
| everforest   | green  | sainnhe/everforest (dark, medium) |
| nord         | frost  | arcticicestudio/nord |
| rose-pine    | love (pink) | rose-pine (main) |
| violet       | violet | near-black with a violet accent |
| monochrome   | grey   | cool greys |

Each theme's wallpapers are in `walls/<id>/` (same name as the theme). Themes named after a
known color scheme use its real palette; the others are named after the closest theme plus
what changes (`red-black` is Orange Black in red). Renamed ids still work: `kanagawa` → `nord`,
`rosso` → `red-black` (`RENAMED` in the script).

The Violet wallpapers are recolored with `walls/violet/recolor.sh` (same idea as
`walls/orange-black/recolor.sh`).

## First install

`current/` isn't versioned: run `~/.config/themes/theme set orange-black` once. Without it,
Quickshell and Neovim fall back to Orange Black, but sway, GTK and alacritty have no colors.
For Firefox or Zen, also run `~/.config/themes/firefox-setup.sh`, restart the browser once
and enable "Theme Sync" when it asks. The extension is signed by Mozilla (unlisted, never
published): `firefox/theme-sync.xpi` loads in any Firefox-based browser. After changing the
extension, bump `version` in `firefox/extension/manifest.json` and run `firefox/sign.py`
(asks for AMO API credentials from https://addons.mozilla.org/developers/addon/api/key/);
until then `firefox-setup.sh` falls back to an unsigned build. Zen drops extension themes by
default and paints its interface from its own variables (workspace gradient), so in Zen
profiles `firefox-setup.sh` sets `zen.theme.disable-lightweight` to false in `user.js` and
installs `firefox/zen-userChrome.css` instead of Firefox's userChrome: it maps Zen's variables
onto the theme API ones the extension sets, live, and only while that theme is applied. For zsh:

```sh
ln -s ~/.config/themes/zsh/theme.zsh-theme ~/.oh-my-zsh/custom/themes/theme.zsh-theme
# then in ~/.zshrc: ZSH_THEME="theme", and no LS_COLORS of its own
```

## Cost

Measured on the T490: nothing at idle (one inotify watch in Quickshell, one autocmd in
Neovim). A switch costs ~0.2 s of CPU for the script and ~0.1 s for Quickshell, almost all of
it decoding the new wallpaper; Quickshell's memory stays flat over repeated switches.
