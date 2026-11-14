# ~/.oh-my-zsh/custom/themes/waybar.zsh-theme
# Minimaliste : texte seul. Orange uniquement sur le dossier courant, le * git et le prompt.

setopt prompt_subst

typeset -g c_fg='#e5e5e5'       # texte
typeset -g c_dim='#888888'      # discret
typeset -g c_accent='#ff8800'   # orange (accent)
typeset -g c_err='#e05252'      # erreur

# Git : nom de branche en gris, * orange si modifié
ZSH_THEME_GIT_PROMPT_PREFIX="%F{$c_dim}"
ZSH_THEME_GIT_PROMPT_SUFFIX="%f"
ZSH_THEME_GIT_PROMPT_DIRTY="%F{$c_accent}*%f"
ZSH_THEME_GIT_PROMPT_CLEAN=""

# SSH : user@host en rouge, seulement en session distante
_wb_ssh() {
  [[ -n $SSH_CONNECTION ]] && print -n "%F{$c_err}%n@%m%f "
}

# Chemin : parents en gris, dossier courant en orange
_wb_path() {
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

# Une seule ligne : chemin · branche · ❯ (orange, rouge si erreur)
PROMPT='$(_wb_ssh)$(_wb_path) $(git_prompt_info)%(?.%F{$c_dim}.%F{$c_err})❯%f '

PROMPT2='%F{$c_dim}·%f '
RPROMPT=''

ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#555555'
