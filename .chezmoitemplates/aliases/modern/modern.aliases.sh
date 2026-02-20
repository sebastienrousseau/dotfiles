# shellcheck shell=bash
# Modern Tooling Aliases (Rust Replacements) & Listing

# Runtime-select listing backend to avoid duplicate static alias definitions.
dot_ls() {
  if command -v eza >/dev/null; then
    eza --icons --group-directories-first "$@"
  else
    command ls "$@"
  fi
}

dot_ll() {
  if command -v eza >/dev/null; then
    eza -alF --icons --group-directories-first "$@"
  else
    command ls -lA "$@"
  fi
}

dot_la() {
  if command -v eza >/dev/null; then
    eza -a --icons --group-directories-first "$@"
  else
    command ls -a "$@"
  fi
}

dot_lt() {
  if command -v eza >/dev/null; then
    eza -aT --icons --group-directories-first "$@"
  else
    command ls -R "$@"
  fi
}

alias ls='dot_ls'
alias ll='dot_ll'
alias la='dot_la'
alias lt='dot_lt'
alias llm='command ls -ltA'
alias lx='command ls -la'

# Tree (fallback to ls -R if not installed)
if ! command -v tree >/dev/null; then
  alias tree='ls -R'
fi

# Bat (Replacement for cat)
dot_cat() {
  if command -v bat >/dev/null; then
    bat "$@"
  elif command -v batcat >/dev/null; then
    batcat "$@"
  else
    command cat "$@"
  fi
}
alias cat='dot_cat'

# Ripgrep: grep="rg" not aliased — breaks scripts expecting grep output format

# Zoxide (Replacement for cd)
# Initialized in .zshrc via query

# FZF helper (preview with bat when available).
if command -v fzf >/dev/null; then
  alias fz='fzf --preview "bat --color=always --style=numbers {} 2>/dev/null | head -500 || cat {} 2>/dev/null | head -500"'
fi

# Zellij (modern terminal workspace manager)
if command -v zellij >/dev/null; then
  alias zj='zellij'
fi
