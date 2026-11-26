# oh-my-zsh theme following the global theme (~/.config/themes).
# Install: link to ~/.oh-my-zsh/custom/themes/theme.zsh-theme, then ZSH_THEME="theme" in ~/.zshrc.
# Minimal, text only: accent on the current directory, the git * and the prompt.
# Colors and LS_COLORS come from ~/.config/themes/current/zsh.zsh, re-read at the next prompt
# whenever `theme set` rewrites it, so open terminals follow theme switches.

setopt prompt_subst
zmodload -F zsh/stat b:zstat 2>/dev/null

# Orange Black defaults, used while the generated file is missing
typeset -g c_fg='#e5e5e5' c_dim='#888888' c_accent='#ff8800' c_err='#e05252'
typeset -g _theme_file="$HOME/.config/themes/current/zsh.zsh" _theme_mtime=

_theme_sync() {
  local -a st
  zstat -A st +mtime -- "$_theme_file" 2>/dev/null || return
  [[ $st[1] == $_theme_mtime ]] && return
  _theme_mtime=$st[1]
  source "$_theme_file"
  _theme_git_colors
}
# Git: branch name dimmed, * in accent when dirty
_theme_git_colors() {
  ZSH_THEME_GIT_PROMPT_PREFIX="%F{$c_dim}"
  ZSH_THEME_GIT_PROMPT_DIRTY="%F{$c_accent}*%f"
}
ZSH_THEME_GIT_PROMPT_SUFFIX='%f'
ZSH_THEME_GIT_PROMPT_CLEAN=''
_theme_git_colors
_theme_sync
autoload -Uz add-zsh-hook
add-zsh-hook precmd _theme_sync

# SSH: user@host in red, only in remote sessions
_theme_ssh() {
  [[ -n $SSH_CONNECTION ]] && print -n "%F{$c_err}%n@%m%f "
}

# Path: parents dimmed, current directory in accent
_theme_path() {
  local p=${PWD/#$HOME/\~}
  p=${p//\%/%%}
  if [[ $p == "~" || $p == "/" ]]; then
    print -n "%F{$c_accent}${p}%f"
  else
    local parent=${p:h}
    [[ $parent == "/" ]] && parent=""
    print -n "%F{$c_dim}${parent}/%F{$c_accent}${p:t}%f"
  fi
}

# One line: path · branch · ❯ (dimmed, red on error)
PROMPT='$(_theme_ssh)$(_theme_path) $(git_prompt_info)%(?.%F{$c_dim}.%F{$c_err})❯%f '
PROMPT2='%F{$c_dim}·%f '
RPROMPT=''
