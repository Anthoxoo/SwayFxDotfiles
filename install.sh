#!/usr/bin/env bash
# Deploys these dotfiles on a machine (Debian or Arch/CachyOS) — see README.md.
#
#   ./install.sh            copy the configs into ~/.config, ~/.zshrc and ~/.local/share/icons
#   ./install.sh --dry-run  only show what would change
#
# Nothing is deleted: every file that gets replaced is first saved under
# ~/.local/state/dotfiles-backup/<date>/ (same layout as in $HOME).
# Packages, the SDDM theme (needs sudo), Firefox and librepods stay manual: see README.md.
set -euo pipefail

repo=$(cd "$(dirname "$0")" && pwd)
dry=()
[ "${1:-}" = "--dry-run" ] && dry=(--dry-run)
backup="$HOME/.local/state/dotfiles-backup/$(date +%Y%m%d-%H%M%S)"

# Configs in use (the other directories of the repo are kept for reference only)
configs=(alacritty btop fuzzel gtk-3.0 gtk-4.0 nvim quickshell sway themes walls zed)

sync() {  # sync <source> <destination dir> <backup subdir>
    rsync -a --itemize-changes "${dry[@]}" \
        --exclude __pycache__ --exclude 'themes/current/' \
        --backup --backup-dir="$backup/$3" \
        "$1" "$2" | grep -vE '^(\.|cd)' || true
}

for c in "${configs[@]}"; do
    echo "== ~/.config/$c"
    sync "$repo/$c/" "$HOME/.config/$c/" ".config/$c"
done

echo "== ~/.zshrc"
sync "$repo/.zshrc" "$HOME/" ""

echo "== ~/.local/share/icons/Papirus-Dark-Orange (links into the papirus-icon-theme package)"
[ ${#dry[@]} -eq 0 ] && mkdir -p "$HOME/.local/share/icons"
sync "$repo/icons/Papirus-Dark-Orange" "$HOME/.local/share/icons/" ".local/share/icons"

[ ${#dry[@]} -gt 0 ] && { echo; echo "Dry run: nothing changed."; exit 0; }

# oh-my-zsh theme that follows the global theme
if [ -d "$HOME/.oh-my-zsh" ]; then
    mkdir -p "$HOME/.oh-my-zsh/custom/themes"
    ln -sfn "$HOME/.config/themes/zsh/theme.zsh-theme" "$HOME/.oh-my-zsh/custom/themes/theme.zsh-theme"
else
    echo "!! oh-my-zsh is not installed: the zsh prompt needs it (see README.md)"
fi

# Render the current theme (or Orange Black on a first install)
if [ -f "$HOME/.config/themes/current/palette.json" ]; then
    "$HOME/.config/themes/theme" apply
else
    "$HOME/.config/themes/theme" set orange-black
fi

echo
[ -d "$backup" ] && echo "Replaced files saved in $backup"
echo "Done. Reload sway (Super+Shift+C) or log in again."
