# Zinit plugin manager
[[ "${DOTFILES_FAST:-0}" == "1" ]] && return 0
[[ "${DOTFILES_ULTRA_FAST:-0}" == "1" ]] && return 0

ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"

_dotfiles_zinit_init() {
  if [[ ! -f "$ZINIT_HOME/zinit.zsh" ]]; then
     print -P "%F{33}▓▒░ %F{220}Installing %F{33}ZDHARMA-CONTINUUM%F{220} Initiative Plugin Manager (%F{33}zdharma-continuum/zinit%F{220})…%f"
     command mkdir -p "$(dirname "$ZINIT_HOME")" && command chmod g-rwX "$(dirname "$ZINIT_HOME")"
     command git clone https://github.com/zdharma-continuum/zinit "$ZINIT_HOME" && \
        print -P "%F{33}▓▒░ %F{34}Installation successful.%f%b" || \
        print -P "%F{160}▓▒░ The clone has failed.%f%b"
  fi

  source "$ZINIT_HOME/zinit.zsh"
  autoload -Uz _zinit
  (( ${+_comps} )) && _comps[zinit]=_zinit

  # Load Zsh Plugins (Turbo mode - deferred loading, pinned to stable releases)
  zinit ice wait lucid ver"0.8.0"
  zinit light zsh-users/zsh-syntax-highlighting
  zinit ice wait lucid ver"v0.7.1" atload"_zsh_autosuggest_start"
  zinit light zsh-users/zsh-autosuggestions
  zinit ice wait lucid ver"0.35.0" blockf atpull"zinit creinstall -q ."
  zinit light zsh-users/zsh-completions
}

# Defer Zinit init for faster first prompt (opt-out by setting DOTFILES_DEFER_ZINIT=0)
: ${DOTFILES_DEFER_ZINIT:=1}
: ${DOTFILES_DEFER_ZINIT_MODE:=preexec}

if [[ "${DOTFILES_DEFER_ZINIT}" == "1" ]]; then
  # Stub to auto-load zinit on first call (e.g. by topgrade)
  zinit() {
    unfunction zinit
    _dotfiles_zinit_init
    zinit "$@"
  }

  _dotfiles_zinit_deferred() {
    if [[ "${DOTFILES_DEFER_ZINIT_MODE}" == "preexec" ]]; then
      _dotfiles_del_preexec _dotfiles_zinit_deferred
    else
      _dotfiles_del_precmd _dotfiles_zinit_deferred
    fi
    # If zinit was already loaded via the stub, this is a no-op
    (( ${+functions[zinit]} )) && [[ "$(whence -w zinit)" == "zinit: function" ]] || _dotfiles_zinit_init
  }

  if [[ "${DOTFILES_DEFER_ZINIT_MODE}" == "preexec" ]]; then
    _dotfiles_add_preexec _dotfiles_zinit_deferred
  else
    _dotfiles_add_precmd _dotfiles_zinit_deferred
  fi
else
  _dotfiles_zinit_init
fi
