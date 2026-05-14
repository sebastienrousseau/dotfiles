# shellcheck shell=bash
# Cognitive Shell Enhancements
#
# Carapace is deferred to first `preexec` (closes #862). The eager
# `_cached_eval carapace ...` call previously cost ~15ms on every
# interactive shell start even with the cache warm — that work is
# only needed when the user invokes tab-completion, which happens
# after the first command at the earliest. Opt out by setting
# `DOTFILES_DEFER_CARAPACE=0` (rarely useful).
if [[ -o interactive ]]; then
  : ${DOTFILES_DEFER_CARAPACE:=1}

  _dotfiles_carapace_init() {
    if command -v carapace >/dev/null 2>&1; then
      if typeset -f _cached_eval >/dev/null 2>&1; then
        _cached_eval carapace carapace _carapace zsh
      else
        source <(carapace _zsh)
      fi
    fi
  }

  if [[ "${DOTFILES_DEFER_CARAPACE}" == "1" ]] && typeset -f _dotfiles_add_preexec >/dev/null 2>&1; then
    _dotfiles_carapace_deferred() {
      _dotfiles_del_preexec _dotfiles_carapace_deferred
      _dotfiles_carapace_init
    }
    _dotfiles_add_preexec _dotfiles_carapace_deferred
  else
    # Fallback to eager init when preexec helpers aren't available
    # (e.g., DOTFILES_FAST=1 paths that skip the zshrc helper block).
    _dotfiles_carapace_init
  fi

  # thefuck — lazy-loaded to avoid ~200ms startup penalty
  if command -v thefuck >/dev/null 2>&1; then
    _lazy_load_thefuck() {
      unset -f fuck _lazy_load_thefuck 2>/dev/null
      _cached_eval "thefuck-alias" thefuck --alias
    }
    fuck() { _lazy_load_thefuck; fuck "$@"; }
    alias fix='fuck'
  fi
fi

# Fallback command shims for environments with aliases disabled.
# These are lightweight functions to ensure core shortcuts still work.

# Opt-out with: export DOTFILES_ALIAS_SHIMS=0
if [[ "${DOTFILES_ALIAS_SHIMS:-1}" != "1" ]]; then
  return 0
fi

# Avoid redefining if already present.
if ! typeset -f c >/dev/null 2>&1; then
  c() { clear; }
fi
if ! typeset -f q >/dev/null 2>&1; then
  q() { exit; }
fi
if ! typeset -f e >/dev/null 2>&1; then
  e() { "${EDITOR:-nano}" "$@"; }
fi
if ! typeset -f h >/dev/null 2>&1; then
  h() { history; }
fi
if ! typeset -f l >/dev/null 2>&1; then
  l() { command -v eza >/dev/null 2>&1 && eza --sort Name --icons --group-directories-first "$@" || command ls "$@"; }
fi
if ! typeset -f ll >/dev/null 2>&1; then
  ll() { command -v eza >/dev/null 2>&1 && eza -alF --sort Name --icons --group-directories-first "$@" || command ls -lA "$@"; }
fi
if ! typeset -f la >/dev/null 2>&1; then
  la() { command -v eza >/dev/null 2>&1 && eza -a --sort Name --icons --group-directories-first "$@" || command ls -a "$@"; }
fi
if ! typeset -f lt >/dev/null 2>&1; then
  lt() { command -v eza >/dev/null 2>&1 && eza -aT --sort Name --icons --group-directories-first "$@" || command ls -R "$@"; }
fi
if ! typeset -f lr >/dev/null 2>&1; then
  lr() { command -v eza >/dev/null 2>&1 && eza -alF --recurse --sort Name --icons --group-directories-first "$@" || command ls -lAR "$@"; }
fi
if ! typeset -f lra >/dev/null 2>&1; then
  lra() { command -v eza >/dev/null 2>&1 && eza -alF --recurse --all --sort Name --icons --group-directories-first "$@" || command ls -lAR "$@"; }
fi
if ! typeset -f lta >/dev/null 2>&1; then
  lta() { command -v eza >/dev/null 2>&1 && eza -aT --all --sort Name --icons --group-directories-first "$@" || command ls -aR "$@"; }
fi
if ! typeset -f d >/dev/null 2>&1; then
  d() { command -v dot >/dev/null 2>&1 && dot "$@" || command -v docker >/dev/null 2>&1 && docker "$@"; }
fi
if ! typeset -f i >/dev/null 2>&1; then
  i() { command -v epoch >/dev/null 2>&1 && epoch "$@"; }
fi
if ! typeset -f a >/dev/null 2>&1; then
  a() { command -v ai_core >/dev/null 2>&1 && ai_core query "$@"; }
fi
if ! typeset -f _ >/dev/null 2>&1; then
  _() { sudo "$@"; }
fi
