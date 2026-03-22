# shellcheck shell=bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# Modern Tooling Aliases (Rust Replacements) & Listing

# Runtime-select listing backend to avoid duplicate static alias definitions.
dot_ls() {
  if command -v eza >/dev/null; then
    eza --sort Name --icons --group-directories-first "$@"
  else
    command ls "$@"
  fi
}

dot_ll() {
  if command -v eza >/dev/null; then
    eza -alF --sort Name --icons --group-directories-first "$@"
  else
    command ls -lA "$@"
  fi
}

dot_la() {
  if command -v eza >/dev/null; then
    eza -a --sort Name --icons --group-directories-first "$@"
  else
    command ls -a "$@"
  fi
}

dot_lt() {
  if command -v eza >/dev/null; then
    eza -aT --sort Name --icons --group-directories-first "$@"
  else
    command ls -R "$@"
  fi
}

dot_lr() {
  if command -v eza >/dev/null; then
    eza -alF --recurse --sort Name --icons --group-directories-first "$@"
  else
    command ls -lAR "$@"
  fi
}

dot_lra() {
  if command -v eza >/dev/null; then
    eza -alF --recurse --all --sort Name --icons --group-directories-first "$@"
  else
    command ls -lAR "$@"
  fi
}

dot_lta() {
  if command -v eza >/dev/null; then
    eza -aT --all --sort Name --icons --group-directories-first "$@"
  else
    command ls -aR "$@"
  fi
}

alias ls='dot_ls'
alias l='dot_ls'
alias ll='dot_ll'
alias la='dot_la'
alias lt='dot_lt'
alias lr='dot_lr'
alias lra='dot_lra'
alias lta='dot_lta'
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
if command -v zoxide >/dev/null; then
  alias zz='zoxide'
  alias zq='zoxide query'
fi

# Modern repo and package workflow helpers.
if command -v mise >/dev/null; then
  alias ms='mise'
  alias msi='mise install'
  alias msu='mise upgrade'
  alias msl='mise ls'
fi

if command -v nix >/dev/null; then
  alias nx='nix'
  alias nxs='nix shell'
  alias nxf='nix flake'
  alias nxu='nix flake update'
fi

if command -v just >/dev/null; then
  alias j='just'
  alias jl='just --list'
fi

if command -v rg >/dev/null; then
  alias rgi='rg --hidden --glob "!.git"'
fi

if command -v jq >/dev/null; then
  alias jqc='jq -C'
fi

if command -v yq >/dev/null; then
  alias yqv='yq eval'
fi

if command -v direnv >/dev/null; then
  alias de='direnv'
  alias dea='direnv allow'
fi

if command -v gh >/dev/null; then
  alias ghpr='gh pr view --web'
  alias ghck='gh pr checks'
fi

if command -v podman >/dev/null; then
  alias p='podman'
  alias pc='podman compose'
fi

# FZF helper (preview with bat when available).
if command -v fzf >/dev/null; then
  alias fz='fzf --preview "bat --color=always --style=numbers {} 2>/dev/null | head -500 || cat {} 2>/dev/null | head -500"'
fi

# Zellij (modern terminal workspace manager)
if command -v zellij >/dev/null; then
  alias zj='zellij'
fi
