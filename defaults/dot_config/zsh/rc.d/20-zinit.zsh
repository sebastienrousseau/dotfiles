# Zinit plugin manager
[[ "${DOTFILES_FAST:-0}" == "1" ]] && return 0
[[ "${DOTFILES_ULTRA_FAST:-0}" == "1" ]] && return 0

ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"

_dotfiles_zinit_git_policy() {
  [[ -d "$ZINIT_HOME/.git" ]] || return 0
  command git -C "$ZINIT_HOME" config --local merge.verifySignatures false >/dev/null 2>&1 || true
}

# _dotfiles_zinit_install: clone zinit. Only on an explicit `zinit` call,
# never from a prompt hook: a network clone there blocked the shell.
_dotfiles_zinit_install() {
  print -P "%F{33}▓▒░ %F{220}Installing %F{33}ZDHARMA-CONTINUUM%F{220} Initiative Plugin Manager (%F{33}zdharma-continuum/zinit%F{220})…%f"
  command mkdir -p "${ZINIT_HOME:h}" && command chmod g-rwX "${ZINIT_HOME:h}"
  if command git clone https://github.com/zdharma-continuum/zinit "$ZINIT_HOME"; then
    print -P "%F{33}▓▒░ %F{34}Installation successful.%f%b"
  else
    print -P "%F{160}▓▒░ The clone has failed.%f%b"
    return 1
  fi
}

# _dotfiles_zinit_init: source zinit and queue the plugins, once. Returns 1
# when zinit is not installed.
_dotfiles_zinit_init() {
  (( ${_DOTFILES_ZINIT_LOADED:-0} )) && return 0
  [[ -f "$ZINIT_HOME/zinit.zsh" ]] || return 1
  typeset -g _DOTFILES_ZINIT_LOADED=1
  (( ${+functions[zinit]} )) && unfunction zinit

  _dotfiles_zinit_git_policy

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

# Stub: an explicit `zinit` call installs zinit if needed, loads it, and
# runs the real command.
zinit() {
  if [[ ! -f "$ZINIT_HOME/zinit.zsh" ]]; then
    _dotfiles_zinit_install || return 1
  fi
  _dotfiles_zinit_init || return 1
  zinit "$@"
}

if [[ "${DOTFILES_DEFER_ZINIT}" == "1" ]]; then
  # Load zinit at the first command (or prompt) if it is installed. The
  # check used to ask whether `zinit` was a function, which the stub above
  # always is, so zinit never loaded.
  _dotfiles_zinit_deferred() {
    if [[ "${DOTFILES_DEFER_ZINIT_MODE}" == "preexec" ]]; then
      _dotfiles_del_preexec _dotfiles_zinit_deferred
    else
      _dotfiles_del_precmd _dotfiles_zinit_deferred
    fi
    _dotfiles_zinit_init
    return 0
  }

  if [[ "${DOTFILES_DEFER_ZINIT_MODE}" == "preexec" ]]; then
    _dotfiles_add_preexec _dotfiles_zinit_deferred
  else
    _dotfiles_add_precmd _dotfiles_zinit_deferred
  fi
else
  _dotfiles_zinit_init
fi
