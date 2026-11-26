# SwayFX dotfiles

SwayFX desktop with a Quickshell shell (bar, launcher, menus, notifications, lock screen,
OSDs) and a global theme switcher that recolors everything at once (`Super+Shift+T`).
One config for both machines:

- **laptop**: ThinkPad T490, Debian 13
- **desktop**: CachyOS

## What's in here

| Directory | Used for |
|-----------|----------|
| `sway/` | SwayFX config (`config.d/*`) and scripts |
| `quickshell/` | the shell |
| `themes/` | global themes and the `theme` command — see `themes/README.md` |
| `alacritty/`, `btop/`, `fuzzel/`, `gtk-3.0/`, `gtk-4.0/`, `nvim/`, `zed/` | app configs, colored by the theme |
| `walls/` | wallpapers, one directory per theme |
| `icons/` | Papirus-Dark-Orange (orange folders for the Orange Black theme) |
| `librepods/` | AirPods daemon: BLE patch, headless service — see `librepods/README.md` |
| `sddm-theme/` | login screen theme ("omarchy") |
| `.zshrc` | zsh + oh-my-zsh (the prompt follows the theme) |

Kept for reference, not deployed: `hypr/`, `hyprshade/`, `waybar/`, `mako/`, `kitty/`,
`nwg-drawer/`, `nwg-look/`, `Thunar/`, `script-import-repos.sh`.

## Install

### 1. Packages

CachyOS / Arch (`paru` also handles the AUR ones):

```sh
paru -S swayfx quickshell swayidle autotiling alacritty polkit-kde-agent xorg-xwayland \
    pipewire pipewire-pulse wireplumber bluez bluez-utils networkmanager upower power-profiles-daemon \
    brightnessctl playerctl wlsunset grim slurp swappy wl-clipboard libnotify jq curl rsync \
    python uv zsh neovim zed btop nautilus gvfs \
    papirus-icon-theme adw-gtk-theme breeze ttf-jetbrains-mono-nerd noto-fonts \
    sddm xdg-desktop-portal-wlr xdg-desktop-portal-gtk
```

Debian 13: SwayFX, Quickshell and Neovim are built from source (`/usr/local`), uv and Zed come
from their install scripts, the rest from apt:

```sh
sudo apt install swayidle autotiling alacritty polkit-kde-agent-1 xwayland \
    pipewire-pulse wireplumber bluez network-manager upower power-profiles-daemon \
    brightnessctl playerctl wlsunset grim slurp swappy wl-clipboard libnotify-bin jq curl rsync \
    zsh btop nautilus gvfs papirus-icon-theme breeze-cursor-theme fonts-noto sddm \
    xdg-desktop-portal-wlr xdg-desktop-portal-gtk
```

On Debian, `adw-gtk3-dark` lives in `~/.local/share/themes` and JetBrainsMono Nerd Font comes
from nerdfonts.com. `fuzzel` is optional: only the unbound `sway/scripts/power_menu.sh` uses it.

Everyday apps: `firefox vlc drawing discord localsend libreoffice github-cli steam gamescope
gamemode ruff flatpak`, then `flatpak install obsidian deezer`, and Rust with
`curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh`.

oh-my-zsh (keeps the repo's `.zshrc`):

```sh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended --keep-zshrc
```

### 2. Configs

```sh
git clone https://github.com/Anthoxoo/SwayFxDotfiles ~/Development/SwayFxDotfiles
cd ~/Development/SwayFxDotfiles
./install.sh --dry-run   # shows what would change
./install.sh
```

`install.sh` copies the configs above into `~/.config`, `~/.zshrc` and
`~/.local/share/icons`, saves every file it replaces under
`~/.local/state/dotfiles-backup/<date>/`, links the zsh theme and renders the current theme
(Orange Black on a first install). It never deletes anything.

### 3. Manual steps

- **Login screen**: `sudo cp -r sddm-theme /usr/share/sddm/themes/omarchy`, then
  `/etc/sddm.conf.d/theme.conf` with `[Theme]` and `Current=omarchy`.
- **Firefox / Zen**: `~/.config/themes/firefox-setup.sh` (see `themes/README.md`). The live theme
  extension is signed by Mozilla (`themes/firefox/theme-sync.xpi`), so it loads in Firefox
  and Zen alike; Zen only gets the extension, not the userChrome.
- **AirPods**: `librepods/install.sh` (see `librepods/README.md`).
- **Calendar** (optional): private files, never committed — `quickshell/ical.conf` and
  `quickshell/google-oauth-client.json`.

## Per-machine settings

No per-machine branches: the differences live in the shared files.

- `sway/config.d/output`: both machines' screens by connector name (sway ignores outputs that
  aren't plugged in). `swaymsg -t get_outputs` lists the names.
- `sway/config.d/input`: the OpenTabletDriver tablet is mapped to the desktop's `DP-1`.
- `sway/scripts/polkit-agent.sh`: finds the polkit agent wherever the distro puts it.
- `sway/scripts/launch-first.sh`: `Super+B` opens Zen if installed, else Firefox; `Super+V`
  opens `zed` (or `zeditor`, its name on Arch).
- `.zshrc`: `LIBVA_DRIVER_NAME=iHD` (Intel) only on the laptop (`$HOST == T490`).
- Quickshell hides the battery module on machines without a battery.

## Updating the repo

The live config in `~/.config` is edited directly, then mirrored here:

```sh
cd ~/Development/SwayFxDotfiles
ex=(--exclude __pycache__ --exclude qmlcache --exclude ical.conf --exclude google-oauth-client.json --exclude '*.bak' --exclude current)
for d in quickshell sway themes alacritty fuzzel gtk-3.0 gtk-4.0 nvim; do
    rsync -a --delete "${ex[@]}" ~/.config/$d/ $d/
done
cp ~/.config/btop/btop.conf btop/; cp ~/.config/zed/settings.json zed/; cp ~/.zshrc .
git status
```
