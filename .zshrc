# THEME (OH MY ZSH)
export ZSH="$HOME/.oh-my-zsh"
plugins=(git)
ZSH_THEME="orange-black"
source $ZSH/oh-my-zsh.sh

export LS_COLORS="di=38;2;255;136;0:ow=38;2;255;136;0:tw=38;2;255;136;0:st=38;2;255;136;0\
:ln=38;2;122;162;200:ex=38;2;163;190;140\
:or=38;2;224;82;82:mi=38;2;224;82;82:su=38;2;224;82;82:sg=38;2;224;82;82\
:so=38;2;180;142;173:pi=38;2;180;142;173:bd=38;2;136;136;136:cd=38;2;136;136;136\
:*.zip=38;2;204;120;120:*.tar=38;2;204;120;120:*.gz=38;2;204;120;120:*.xz=38;2;204;120;120:*.7z=38;2;204;120;120\
:*.png=38;2;180;142;173:*.jpg=38;2;180;142;173:*.jpeg=38;2;180;142;173:*.svg=38;2;180;142;173:*.webp=38;2;180;142;173\
:*.mp4=38;2;180;142;173:*.mkv=38;2;180;142;173:*.mp3=38;2;180;142;173:*.flac=38;2;180;142;173"
alias ls='ls --color=auto'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"

. "$HOME/.local/bin/env"

# ALIASES
alias c="clear"
alias wifi="nmtui"
export LIBVA_DRIVER_NAME=iHD
