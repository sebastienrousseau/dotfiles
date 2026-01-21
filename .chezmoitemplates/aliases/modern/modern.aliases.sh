# shellcheck shell=bash
#!/usr/bin/env bash
# Modern Tooling Aliases (Rust Replacements) & Listing

# Eza (Replacement for ls) OR Fallback
if command -v eza >/dev/null; then
  alias ls="eza --icons --group-directories-first"
  alias ll="eza -alF --icons --group-directories-first"
  alias la="eza -a --icons --group-directories-first"
  alias lt="eza -aT --icons --group-directories-first"
else
  # Fallback to ls
  alias ls='ls'
  alias l='ls'
  alias ll='ls -lA'
  alias llm='ls -ltA'
  alias la='ls -a'
  alias lx='ls -la'
fi

# Tree (or fallback)
if command -v tree >/dev/null; then
    alias tree='tree'
else
    alias tree='ls -R'
fi

# Bat (Replacement for cat)
if command -v bat >/dev/null; then
  alias cat="bat"
fi

# Ripgrep (Replacement for grep)
if command -v rg >/dev/null; then
  alias grep="rg"
fi

# Zoxide (Replacement for cd)
# Initialized in .zshrc via query
