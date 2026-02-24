# Configuration Examples

Ready-to-use configuration examples for common scenarios.

## Table of Contents

- [Quick Start Profiles](#quick-start-profiles)
- [Custom Aliases](#custom-aliases)
- [Theme Configurations](#theme-configurations)
- [Tool Integrations](#tool-integrations)
- [Security Configurations](#security-configurations)
- [Performance Tuning](#performance-tuning)

---

## Quick Start Profiles

### Minimal Profile (CI/Containers)

Optimized for CI environments and containers with sub-50ms startup.

```bash
# ~/.zshrc.local
export DOTFILES_PROFILE=minimal
export DOTFILES_FAST=1
export DOTFILES_NONINTERACTIVE=1

# Skip interactive features
export DOTFILES_AI=0
export DOTFILES_ENABLE_COLORS=0
```

### Developer Workstation

Full-featured development environment with all tools.

```bash
# ~/.zshrc.local
export DOTFILES_PROFILE=workstation

# Enable all features
export DOTFILES_AI=1
export DOTFILES_ENABLE_COLORS=1

# Custom paths
export PROJECTS_DIR="$HOME/Code"
export GOPATH="$HOME/go"
```

### Server Profile

Secure configuration for production servers.

```bash
# ~/.zshrc.local
export DOTFILES_PROFILE=server
export DOTFILES_FAST=1

# Disable GUI features
unset DISPLAY

# Strict history settings
export HISTSIZE=10000
export SAVEHIST=10000
export HISTFILE="$HOME/.zsh_history"
```

### DevOps/SRE Profile

Kubernetes and cloud-focused configuration.

```bash
# ~/.zshrc.local
export DOTFILES_PROFILE=devops

# Cloud provider defaults
export AWS_DEFAULT_REGION=us-west-2
export GOOGLE_CLOUD_PROJECT=my-project

# Kubernetes context
export KUBECONFIG="$HOME/.kube/config"

# Enable cloud CLI completions
export DOTFILES_CLOUD=1
```

---

## Custom Aliases

### Git Workflow Aliases

Add to `~/.config/shell/custom/aliases.sh`:

```bash
# Quick commit with message
gcm() { git commit -m "$*"; }

# Create feature branch
gfeat() { git checkout -b "feat/$1"; }

# Create bugfix branch
gfix() { git checkout -b "fix/$1"; }

# Interactive rebase on main
greb() { git fetch origin && git rebase -i origin/main; }

# Push and create PR
gppr() {
  local branch=$(git branch --show-current)
  git push -u origin "$branch"
  gh pr create --fill
}

# Amend without editing message
gam() { git add -A && git commit --amend --no-edit; }

# Show recent branches
gbr() { git branch --sort=-committerdate | head -10; }
```

### Docker Shortcuts

```bash
# Run with current directory mounted
drun() { docker run -it --rm -v "$PWD:/app" -w /app "$@"; }

# Quick compose commands
alias dcu='docker compose up -d'
alias dcd='docker compose down'
alias dcl='docker compose logs -f'
alias dce='docker compose exec'

# Clean up
alias dprune='docker system prune -af --volumes'

# Build and run
dbuild() { docker build -t "$1" . && docker run -it --rm "$1"; }
```

### Kubernetes Helpers

```bash
# Quick context switch
kctx() { kubectl config use-context "$1"; }

# Get all resources in namespace
kall() { kubectl get all -n "${1:-default}"; }

# Watch pods
kwatch() { watch -n1 "kubectl get pods ${1:+-n $1}"; }

# Quick port forward
kpf() { kubectl port-forward "svc/$1" "$2:$3"; }

# Get logs with follow
klogs() { kubectl logs -f "deploy/$1" "${2:+--container $2}"; }

# Exec into pod
kexec() { kubectl exec -it "deploy/$1" -- "${2:-/bin/sh}"; }
```

### Development Helpers

```bash
# Open project in editor
p() {
  local dir="${PROJECTS_DIR:-$HOME/Code}"
  local project=$(fd -t d -d 2 . "$dir" | fzf --preview 'ls -la {}')
  [[ -n "$project" ]] && cd "$project" && $EDITOR .
}

# Create and enter directory
mkcd() { mkdir -p "$1" && cd "$1"; }

# Find and edit file
fe() { $EDITOR "$(fzf --preview 'bat --color=always {}')" }

# Run tests for current project
t() {
  if [[ -f "Cargo.toml" ]]; then cargo test "$@"
  elif [[ -f "go.mod" ]]; then go test ./... "$@"
  elif [[ -f "package.json" ]]; then npm test "$@"
  elif [[ -f "pytest.ini" ]] || [[ -f "pyproject.toml" ]]; then pytest "$@"
  else echo "Unknown project type"
  fi
}

# Format code
fmt() {
  if [[ -f "Cargo.toml" ]]; then cargo fmt
  elif [[ -f "go.mod" ]]; then go fmt ./...
  elif [[ -f "package.json" ]]; then npm run format || npx prettier --write .
  elif [[ -f "pyproject.toml" ]]; then black . && isort .
  fi
}
```

---

## Theme Configurations

### Catppuccin Mocha (Default)

```bash
export DOTFILES_THEME=catppuccin-mocha

# Terminal colors (for alacritty/kitty)
# ~/.config/alacritty/alacritty.toml
# [colors]
# import = ["~/.config/alacritty/catppuccin-mocha.toml"]
```

### Tokyo Night

```bash
export DOTFILES_THEME=tokyonight-night

# Matching bat theme
export BAT_THEME="tokyonight_night"
```

### Gruvbox

```bash
export DOTFILES_THEME=gruvbox-dark

# FZF colors
export FZF_DEFAULT_OPTS='
  --color=fg:#ebdbb2,bg:#282828,hl:#fabd2f
  --color=fg+:#ebdbb2,bg+:#3c3836,hl+:#fabd2f
  --color=info:#83a598,prompt:#bdae93,pointer:#fb4934
'
```

### Light Theme (Day Mode)

```bash
export DOTFILES_THEME=catppuccin-latte

# Automatically switch based on time
auto_theme() {
  local hour=$(date +%H)
  if (( hour >= 7 && hour < 19 )); then
    export DOTFILES_THEME=catppuccin-latte
  else
    export DOTFILES_THEME=catppuccin-mocha
  fi
}
```

---

## Tool Integrations

### Claude AI Integration

```bash
# ~/.zshrc.local
export DOTFILES_AI=1

# Claude CLI configuration
export CLAUDE_MODEL=claude-sonnet-4-20250514

# Custom AI commit function
aicommit() {
  local diff=$(git diff --cached)
  if [[ -z "$diff" ]]; then
    echo "No staged changes"
    return 1
  fi
  local msg=$(echo "$diff" | claude "Write a conventional commit message for this diff. Be concise.")
  echo "Suggested: $msg"
  read -q "?Use this message? [y/N] " && git commit -m "$msg"
}
```

### GitHub Copilot CLI

```bash
# Enable Copilot suggestions
if command -v gh >/dev/null && gh copilot --help >/dev/null 2>&1; then
  eval "$(gh copilot alias -- zsh)"
fi
```

### Neovim Integration

```bash
# Default editor
export EDITOR=nvim
export VISUAL=nvim

# Quick edit aliases
alias v='nvim'
alias vi='nvim'

# Edit config
alias vconf='nvim ~/.config/nvim/init.lua'

# Open with file picker
alias vf='nvim $(fzf)'
```

### Tmux Integration

```bash
# Auto-start tmux on SSH
if [[ -n "$SSH_CONNECTION" ]] && [[ -z "$TMUX" ]]; then
  tmux attach -t main 2>/dev/null || tmux new -s main
fi

# Quick session management
ts() { tmux switch-client -t "$1" 2>/dev/null || tmux new-session -ds "$1" && tmux switch-client -t "$1"; }
tl() { tmux list-sessions; }
tk() { tmux kill-session -t "$1"; }
```

---

## Security Configurations

### SSH Agent Setup

```bash
# ~/.zshrc.local

# Use 1Password SSH agent
export SSH_AUTH_SOCK="$HOME/.1password/agent.sock"

# Or use system keychain (macOS)
# ssh-add --apple-use-keychain ~/.ssh/id_ed25519

# Or use gpg-agent
# export SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket)
```

### Git Commit Signing

```bash
# ~/.gitconfig.local
[user]
    signingkey = ~/.ssh/id_ed25519.pub

[gpg]
    format = ssh

[gpg "ssh"]
    allowedSignersFile = ~/.ssh/allowed_signers

[commit]
    gpgsign = true

[tag]
    gpgsign = true
```

### Secrets Management

```bash
# Initialize secrets
dot secrets-init

# Add encrypted environment variables
# Edit ~/.config/chezmoi/encrypted_secrets.age
cat <<EOF | chezmoi encrypt >> ~/.config/chezmoi/encrypted_secrets.age
export GITHUB_TOKEN="ghp_..."
export NPM_TOKEN="npm_..."
export AWS_ACCESS_KEY_ID="AKIA..."
export AWS_SECRET_ACCESS_KEY="..."
EOF
```

### Firewall Configuration

```bash
# Enable firewall (requires sudo)
dot firewall enable

# Custom rules
# Add to ~/.config/dotfiles/firewall-rules
# allow 22/tcp  # SSH
# allow 80/tcp  # HTTP
# allow 443/tcp # HTTPS
# deny 3306/tcp # MySQL
```

---

## Performance Tuning

### Ultra-Fast Mode

For ephemeral environments or when speed is critical:

```bash
export DOTFILES_ULTRA_FAST=1
export DOTFILES_DEFER_ZINIT=0
export DOTFILES_AI=0
export DOTFILES_ENABLE_COLORS=0

# Disable expensive completions
zstyle ':completion:*' use-cache off
```

### Selective Plugin Loading

Control which plugins load:

```bash
# ~/.zshrc.local

# Disable specific plugins
export DOTFILES_DISABLE_PLUGINS="docker kubernetes"

# Or enable only specific ones
export DOTFILES_PLUGINS="git fzf"
```

### Background Preloading

Enable background loading of heavy tools:

```bash
# Preload in background after prompt
precmd_dotfiles_preload() {
  # Only run once
  (( ${+_DOTFILES_PRELOADED} )) && return
  _DOTFILES_PRELOADED=1

  # Background load
  {
    command -v kubectl >/dev/null && kubectl version --client >/dev/null 2>&1
    command -v docker >/dev/null && docker info >/dev/null 2>&1
  } &!
}
precmd_functions+=(precmd_dotfiles_preload)
```

### Profiling Startup

Find what's slowing down your shell:

```bash
# Enable zsh profiling
zmodload zsh/zprof

# In your .zshrc.local (at the end):
zprof | head -30

# Or use dot benchmark
dot benchmark
dot benchmark all
```

---

## Complete Example: Full Workstation Setup

```bash
# ~/.zshrc.local - Full developer workstation

# Profile
export DOTFILES_PROFILE=workstation
export DOTFILES_AI=1
export DOTFILES_ENABLE_COLORS=1

# Editor
export EDITOR=nvim
export VISUAL=nvim

# Development directories
export PROJECTS_DIR="$HOME/Code"
export GOPATH="$HOME/go"
export CARGO_HOME="$HOME/.cargo"

# Cloud
export AWS_DEFAULT_REGION=us-west-2
export GOOGLE_APPLICATION_CREDENTIALS="$HOME/.config/gcloud/credentials.json"

# Custom aliases
alias p='cd $PROJECTS_DIR && cd $(fd -t d -d 2 . | fzf)'
alias lg='lazygit'
alias k='kubectl'

# Git defaults
export GIT_AUTHOR_NAME="Your Name"
export GIT_AUTHOR_EMAIL="you@example.com"

# Theme
export DOTFILES_THEME=catppuccin-mocha

# Load work-specific config if present
[[ -f ~/.zshrc.work ]] && source ~/.zshrc.work
```

---

## See Also

- [Installation Guide](INSTALL.md)
- [CLI Reference](CLI_REFERENCE.md)
- [Architecture](ARCHITECTURE.md)
- [Troubleshooting](TROUBLESHOOTING.md)
