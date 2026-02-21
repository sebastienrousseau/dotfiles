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
