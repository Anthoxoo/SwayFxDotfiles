# Themes

Global theme system, omarchy-style: one command recolors the whole desktop at once
(Quickshell, sway windows, GTK 3/4, icons, alacritty, Neovim, Zed, btop, fuzzel, Firefox,
wallpaper). Dark themes only.

```sh
~/.config/themes/theme list           # * = current theme
~/.config/themes/theme set kanagawa
~/.config/themes/theme next | prev
~/.config/themes/theme apply          # re-render the current theme (after editing a template)
```

Picker in Quickshell: `Super+Shift+T` (↑/↓ or j/k to choose, Enter to apply, Esc to close),
or `qs ipc call theme set <id>` / `next` / `prev`.

## Layout

```
themes/
├── theme                 the script (Python 3.11+, no dependencies)
├── firefox-setup.sh      prepares Firefox profiles once
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
| Neovim      | `current/palette.json` (`colors/theme.lua`) | SIGUSR1 → `:colorscheme theme`        |
| Zed         | `~/.config/zed/themes/theme.json` (copy of `current/zed.json`), theme "Theme" in settings.json | Zed watches its themes directory |
| btop        | `~/.config/btop/themes/theme.theme`, `color_theme = "theme"` | SIGUSR2 (re-reads btop.conf)          |
| fuzzel      | `current/fuzzel.ini` (`include=` in fuzzel.ini) | on every launch                       |
| Firefox     | `chrome/userChrome.css`, `userContent.css`, `user.js` of profiles prepared by `firefox-setup.sh` | when Firefox restarts |

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

In templates: `{{ key }}` → `#rrggbb`, `{{ key_strip }}` → `rrggbb`, `{{ key_rgb }}` → `r, g, b`.
An unknown key aborts the render before anything is written.

## Included themes

| id           | Wallpapers (`walls/`) | Accent |
|--------------|-----------------------|--------|
| orange-black | orange-black          | orange |
| gruvbox      | yellow-orange-ish     | yellow |
| rosso        | red-ish               | red    |
| kanagawa     | blue-ish              | blue   |
| everforest   | green-nature          | green  |
| violet       | violet                | violet |
| monochrome   | black-white-ish       | grey   |

The Violet wallpapers are recolored with `walls/violet/recolor.sh` (same idea as
`walls/orange-black/recolor.sh`).

## First install

`current/` isn't versioned: run `~/.config/themes/theme set orange-black` once. Without it,
Quickshell and Neovim fall back to Orange Black, but sway, GTK and alacritty have no colors.
For Firefox, also run `~/.config/themes/firefox-setup.sh`.

## Cost

Measured on the T490: nothing at idle (one inotify watch in Quickshell, one autocmd in
Neovim). A switch costs ~0.2 s of CPU for the script and ~0.1 s for Quickshell, almost all of
it decoding the new wallpaper; Quickshell's memory stays flat over repeated switches.
