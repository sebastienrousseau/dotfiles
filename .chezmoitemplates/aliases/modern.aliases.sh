# Modern Tooling Aliases (Rust Replacements)

# Eza (Replacement for ls)
if command -v eza >/dev/null; then
  alias ls="eza --icons --group-directories-first"
  alias ll="eza -alF --icons --group-directories-first"
  alias la="eza -a --icons --group-directories-first"
  alias lt="eza -aT --icons --group-directories-first"
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
