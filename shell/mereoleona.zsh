# ~/.mereoleona/shell/mereoleona.zsh
# Mereoleona Vermillion fire layer for zsh. Sourced from ~/.zshrc between the
# MEREOLEONA markers. Removing those markers fully disables this layer.
# Your Powerlevel10k config is NOT edited — colors are layered on top at runtime.

[[ -o interactive ]] || return

# ---- palette (truecolor escapes for art / fzf / misc) ----
typeset -g _M_CRIMSON=$'\e[38;2;200;52;30m'
typeset -g _M_EMBER=$'\e[38;2;232;101;14m'
typeset -g _M_GOLD=$'\e[38;2;242;168;30m'
typeset -g _M_CREAM=$'\e[38;2;245;230;204m'
typeset -g _M_EYE=$'\e[38;2;111;168;181m'
typeset -g _M_DIM=$'\e[38;2;120;80;50m'
typeset -g _M_RST=$'\e[0m'

# ---- fire-tuned file/grep colors ----
export LS_COLORS="di=1;38;5;214:ln=38;5;80:so=38;5;202:pi=38;5;202:ex=1;38;5;208:bd=38;5;208:cd=38;5;208:su=38;5;196:sg=38;5;196:tw=38;5;214:ow=38;5;214:*.tar=38;5;160:*.gz=38;5;160:*.zip=38;5;160:*.jpg=38;5;172:*.png=38;5;172:*.mp4=38;5;172:*.md=38;5;223"
export GREP_COLORS='ms=01;38;5;208:mc=01;38;5;202:sl=:cx=:fn=38;5;214:ln=38;5;130:bn=38;5;130:se=38;5;240'
alias grep='grep --color=auto'
alias ls='ls --color=auto'
alias ll='ls -lah --color=auto'

# ---- the blazing banner ----
mereoleona_banner() {
  local -a art grad
  art=(
"          )                        (          "
"         ) \\          |          / (         "
"        (   \\        /|\\        /   )        "
"         \\   \\      / | \\      /   /         "
"    (     \\   \\    /  ^  \\    /   /     )    "
"     \\     .   \\  /  / \\  \\  /   .     /     "
"      \\_____________/   \\_____________/       "
"     M E R E O L E O N A   VERMILLION         "
"        Calidos Brachium - House Vermillion   "
"           \"Burn everything to ash.\"          "
  )
  grad=( "200;52;30" "216;64;26" "228;84;20" "232;101;14" "238;128;18" "242;152;24" "242;168;30" "255;201;77" "200;52;30" "120;80;50" )
  print ""
  local i
  for i in {1..${#art[@]}}; do
    printf '\e[1;38;2;%sm%s\e[0m\n' "${grad[$i]}" "${art[$i]}"
  done
  print ""
}

# show banner exactly once, after the first prompt is ready (avoids p10k
# instant-prompt console-output warnings)
autoload -Uz add-zsh-hook
_m_banner_once() {
  add-zsh-hook -d precmd _m_banner_once
  [[ -n ${MEREOLEONA_NO_BANNER:-} ]] && return
  mereoleona_banner
}
if [[ $SHLVL -le 1 && -z ${MEREOLEONA_BANNER_SHOWN:-} ]]; then
  export MEREOLEONA_BANNER_SHOWN=1
  add-zsh-hook precmd _m_banner_once
fi

# ---- fire-recolor Powerlevel10k (runtime overlay; your .p10k.zsh untouched) ----
# Disable with: export MEREOLEONA_PROMPT=0  (before this is sourced)
if [[ ${MEREOLEONA_PROMPT:-1} == 1 ]] && (( ${+functions[p10k]} )); then
  # text foregrounds only — your segment layout & backgrounds are preserved
  POWERLEVEL9K_OS_ICON_FOREGROUND='#E84B2E'
  POWERLEVEL9K_DIR_FOREGROUND='#F2A81E'
  POWERLEVEL9K_DIR_ANCHOR_FOREGROUND='#FFC94D'
  POWERLEVEL9K_DIR_SHORTENED_FOREGROUND='#B5471B'
  POWERLEVEL9K_VCS_FOREGROUND='#E8650E'
  POWERLEVEL9K_VCS_CLEAN_FOREGROUND='#9D9A2E'
  POWERLEVEL9K_VCS_MODIFIED_FOREGROUND='#FFC94D'
  POWERLEVEL9K_VCS_UNTRACKED_FOREGROUND='#E8650E'
  POWERLEVEL9K_VCS_CONFLICTED_FOREGROUND='#C8341E'
  POWERLEVEL9K_STATUS_OK_FOREGROUND='#9D9A2E'
  POWERLEVEL9K_STATUS_ERROR_FOREGROUND='#E84B2E'
  POWERLEVEL9K_COMMAND_EXECUTION_TIME_FOREGROUND='#F2A81E'
  POWERLEVEL9K_TIME_FOREGROUND='#B5471B'
  POWERLEVEL9K_CONTEXT_FOREGROUND='#F5E6CC'
  POWERLEVEL9K_CONTEXT_ROOT_FOREGROUND='#C8341E'
  POWERLEVEL9K_BACKGROUND_JOBS_FOREGROUND='#F2A81E'
  POWERLEVEL9K_ROOT_INDICATOR_FOREGROUND='#C8341E'
  POWERLEVEL9K_VIRTUALENV_FOREGROUND='#6FA8B5'
  POWERLEVEL9K_PYENV_FOREGROUND='#6FA8B5'
  POWERLEVEL9K_NODE_VERSION_FOREGROUND='#9D9A2E'
  POWERLEVEL9K_GO_VERSION_FOREGROUND='#6FA8B5'
  local _vm
  for _vm in VIINS VICMD VIVIS VIOWR; do
    eval "POWERLEVEL9K_PROMPT_CHAR_OK_${_vm}_FOREGROUND='#E8650E'"
    eval "POWERLEVEL9K_PROMPT_CHAR_ERROR_${_vm}_FOREGROUND='#C8341E'"
  done
  p10k reload 2>/dev/null
fi

# ---- magical aliases ----
alias mana='mereoleona_banner'                       # reprint the banner
alias blaze='command cmatrix -ab -u 2 -C red 2>/dev/null || echo "install cmatrix for the flames (see ~/.mereoleona/README.md)"'
alias ember='command cbonsai -li -t 0.03 2>/dev/null || echo "install cbonsai for a living ember tree"'
