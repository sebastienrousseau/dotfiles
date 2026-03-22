# Setup fzf (managed by dotfiles)
# --------------------------------
# ~/.fzf/bin is added to PATH in dot_config/shell/00-core-paths.sh.tmpl

if command -v fzf >/dev/null 2>&1; then
  # Initialize key bindings and completion (requires interactive TTY)
  if [[ -o interactive ]] && [[ -t 1 ]]; then
    # Use _cached_eval when available (sourced from zshrc), else direct init
    if (( ${+functions[_cached_eval]} )) && fzf --zsh &>/dev/null; then
      _cached_eval fzf-init fzf --zsh
    elif fzf --help 2>/dev/null | grep -q -- '--zsh'; then
      source <(fzf --zsh)
    else
      # Fallback for older fzf builds without --zsh
      if [[ -f /usr/share/fzf/completion.zsh ]]; then
        source /usr/share/fzf/completion.zsh
      elif [[ -f /usr/share/doc/fzf/examples/completion.zsh ]]; then
        source /usr/share/doc/fzf/examples/completion.zsh
      fi
      if [[ -f /usr/share/fzf/key-bindings.zsh ]]; then
        source /usr/share/fzf/key-bindings.zsh
      elif [[ -f /usr/share/doc/fzf/examples/key-bindings.zsh ]]; then
        source /usr/share/doc/fzf/examples/key-bindings.zsh
      fi
    fi
  fi

  # Source commands (fd preferred for speed, rg as fallback)
  if command -v fd >/dev/null 2>&1; then
    export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
    export FZF_CTRL_T_COMMAND='fd --type f --hidden --follow --exclude .git'
    export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
  elif command -v rg >/dev/null 2>&1; then
    export FZF_DEFAULT_COMMAND='rg --files --hidden --follow --glob "!.git/*"'
  fi

  # Default options: layout, preview, border
  export FZF_DEFAULT_OPTS="\
    --height=40% --layout=reverse --border=rounded \
    --info=inline --marker='*' --pointer='>' \
    --bind='ctrl-/:toggle-preview'"

  # Ctrl-T: file picker with preview
  export FZF_CTRL_T_OPTS="--preview 'bat --color=always --style=numbers --line-range=:200 {} 2>/dev/null || cat {}'"

  # Alt-C: directory picker with tree preview
  export FZF_ALT_C_OPTS="--preview 'eza --tree --level=2 --color=always {} 2>/dev/null || ls -la {}'"
fi
