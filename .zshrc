# THEME (OH MY ZSH)
export ZSH="$HOME/.oh-my-zsh"
plugins=(git)
ZSH_THEME="theme"  # ~/.config/themes/zsh/theme.zsh-theme (follows the global theme)
source $ZSH/oh-my-zsh.sh

# LS_COLORS and completion colors: set by the theme (~/.config/themes/current/zsh.zsh)
alias ls='ls --color=auto'

[ -f "$HOME/.local/bin/env" ] && . "$HOME/.local/bin/env"  # uv

# ALIASES 
alias c="clear"
alias wifi="nmtui"
[[ $HOST == T490 ]] && export LIBVA_DRIVER_NAME=iHD  # Intel VA-API, laptop only
export XDG_STATE_HOME="$HOME/.local/state"
