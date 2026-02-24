#!/usr/bin/env bash
# Generate devcontainer.json with dotfiles integration
# Usage: dot devcontainer [--init|--codespaces|--gitpod]
#
# Supports: VS Code Dev Containers, GitHub Codespaces, Gitpod, DevPod

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../dot/lib/ui.sh
source "$SCRIPT_DIR/../dot/lib/ui.sh"

ui_init

# Default values
OUTPUT_DIR="${1:-.devcontainer}"
DOTFILES_REPO="https://github.com/sebastienrousseau/dotfiles.git"
DOTFILES_INSTALL="install.sh"
IMAGE="mcr.microsoft.com/devcontainers/base:ubuntu"
MODE="vscode"

# =============================================================================
# Parse Arguments
# =============================================================================

show_help() {
  cat <<EOF
Usage: dot devcontainer [OPTIONS] [OUTPUT_DIR]

Generate devcontainer configuration with dotfiles integration.

Options:
  --init         Initialize .devcontainer in current directory (default)
  --codespaces   Generate for GitHub Codespaces
  --gitpod       Generate .gitpod.yml instead
  --image IMAGE  Base image (default: mcr.microsoft.com/devcontainers/base:ubuntu)
  --repo URL     Dotfiles repository URL
  -h, --help     Show this help

Examples:
  dot devcontainer                    # Create .devcontainer/
  dot devcontainer --codespaces       # Optimized for Codespaces
  dot devcontainer --gitpod           # Generate .gitpod.yml
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --init) MODE="vscode"; shift ;;
    --codespaces) MODE="codespaces"; shift ;;
    --gitpod) MODE="gitpod"; shift ;;
    --image) IMAGE="$2"; shift 2 ;;
    --repo) DOTFILES_REPO="$2"; shift 2 ;;
    -h|--help) show_help; exit 0 ;;
    -*) echo "Unknown option: $1"; show_help; exit 1 ;;
    *) OUTPUT_DIR="$1"; shift ;;
  esac
done

# =============================================================================
# Generators
# =============================================================================

generate_vscode() {
  local dir="$OUTPUT_DIR"
  mkdir -p "$dir"

  ui_header "Generating VS Code Dev Container"
  echo ""

  # devcontainer.json
  cat > "$dir/devcontainer.json" <<EOF
{
  "name": "Development Environment",
  "image": "$IMAGE",

  // Dotfiles integration
  "dotfiles.repository": "$DOTFILES_REPO",
  "dotfiles.installCommand": "$DOTFILES_INSTALL",
  "dotfiles.targetPath": "~/.dotfiles",

  // Features to install
  "features": {
    "ghcr.io/devcontainers/features/common-utils:2": {
      "configureZshAsDefaultShell": true
    },
    "ghcr.io/devcontainers/features/git:1": {},
    "ghcr.io/devcontainers/features/github-cli:1": {}
  },

  // VS Code settings
  "customizations": {
    "vscode": {
      "settings": {
        "terminal.integrated.defaultProfile.linux": "zsh",
        "editor.fontFamily": "JetBrains Mono, Fira Code, monospace",
        "editor.fontLigatures": true
      },
      "extensions": [
        "streetsidesoftware.code-spell-checker",
        "editorconfig.editorconfig",
        "github.copilot",
        "ms-azuretools.vscode-docker"
      ]
    }
  },

  // Container settings
  "remoteUser": "vscode",
  "containerEnv": {
    "DOTFILES_PROFILE": "server",
    "DOTFILES_NONINTERACTIVE": "1"
  },

  // Lifecycle scripts
  "postCreateCommand": "zsh -c 'source ~/.zshrc && dot doctor || true'",
  "postStartCommand": "zsh -c 'source ~/.zshrc'"
}
EOF

  ui_ok "Created" "$dir/devcontainer.json"

  # Optional Dockerfile for customization
  cat > "$dir/Dockerfile" <<EOF
# Custom Dev Container
# Uncomment and modify to customize the base image

FROM $IMAGE

# Install additional packages
# RUN apt-get update && apt-get install -y \\
#     neovim \\
#     && rm -rf /var/lib/apt/lists/*

# Pre-install dotfiles for faster startup (optional)
# ARG DOTFILES_REPO=$DOTFILES_REPO
# RUN git clone --depth 1 \$DOTFILES_REPO /tmp/dotfiles \\
#     && cd /tmp/dotfiles && ./install.sh \\
#     && rm -rf /tmp/dotfiles
EOF

  ui_ok "Created" "$dir/Dockerfile (template)"

  echo ""
  ui_info "Next steps" ""
  echo "  1. Review $dir/devcontainer.json"
  echo "  2. Open VS Code and run 'Dev Containers: Reopen in Container'"
  echo "  3. Or push to GitHub and open in Codespaces"
}

generate_codespaces() {
  local dir="$OUTPUT_DIR"
  mkdir -p "$dir"

  ui_header "Generating GitHub Codespaces Configuration"
  echo ""

  cat > "$dir/devcontainer.json" <<EOF
{
  "name": "GitHub Codespaces",
  "image": "$IMAGE",

  // Dotfiles - GitHub automatically clones to ~/dotfiles
  // Configure in: github.com/settings/codespaces
  // Or specify here:
  "dotfiles.repository": "$DOTFILES_REPO",
  "dotfiles.installCommand": "$DOTFILES_INSTALL",

  "features": {
    "ghcr.io/devcontainers/features/common-utils:2": {
      "configureZshAsDefaultShell": true
    },
    "ghcr.io/devcontainers/features/git:1": {},
    "ghcr.io/devcontainers/features/github-cli:1": {},
    "ghcr.io/devcontainers/features/docker-in-docker:2": {}
  },

  "customizations": {
    "vscode": {
      "settings": {
        "terminal.integrated.defaultProfile.linux": "zsh"
      },
      "extensions": [
        "github.copilot",
        "github.copilot-chat",
        "ms-azuretools.vscode-docker"
      ]
    },
    "codespaces": {
      "openFiles": ["README.md"]
    }
  },

  "containerEnv": {
    "DOTFILES_PROFILE": "server",
    "DOTFILES_NONINTERACTIVE": "1",
    "CODESPACES": "true"
  },

  // Optimizations for Codespaces
  "hostRequirements": {
    "cpus": 4,
    "memory": "8gb",
    "storage": "32gb"
  },

  "postCreateCommand": "zsh -c 'dot doctor || true'"
}
EOF

  ui_ok "Created" "$dir/devcontainer.json (Codespaces)"

  echo ""
  ui_section "GitHub Settings"
  echo ""
  echo "  Configure dotfiles in your GitHub account:"
  echo "  https://github.com/settings/codespaces"
  echo ""
  echo "  Repository: $DOTFILES_REPO"
  echo "  Install command: $DOTFILES_INSTALL"
}

generate_gitpod() {
  ui_header "Generating Gitpod Configuration"
  echo ""

  cat > ".gitpod.yml" <<EOF
# Gitpod configuration
# https://www.gitpod.io/docs/references/gitpod-yml

image:
  file: .gitpod.Dockerfile

tasks:
  - name: Setup
    init: |
      # Clone and install dotfiles
      git clone --depth 1 $DOTFILES_REPO ~/.dotfiles
      cd ~/.dotfiles && DOTFILES_NONINTERACTIVE=1 DOTFILES_PROFILE=server ./install.sh
    command: |
      # Start with zsh
      exec zsh

# VS Code extensions
vscode:
  extensions:
    - streetsidesoftware.code-spell-checker
    - editorconfig.editorconfig

# Ports (if needed)
# ports:
#   - port: 3000
#     onOpen: open-preview
EOF

  ui_ok "Created" ".gitpod.yml"

  cat > ".gitpod.Dockerfile" <<EOF
FROM gitpod/workspace-full

# Install zsh and common tools
RUN sudo apt-get update && sudo apt-get install -y \\
    zsh \\
    neovim \\
    && sudo rm -rf /var/lib/apt/lists/*

# Set zsh as default shell
RUN sudo chsh -s /usr/bin/zsh gitpod

# Environment
ENV DOTFILES_PROFILE=server
ENV DOTFILES_NONINTERACTIVE=1
EOF

  ui_ok "Created" ".gitpod.Dockerfile"

  echo ""
  ui_info "Next steps" ""
  echo "  1. Commit .gitpod.yml and .gitpod.Dockerfile"
  echo "  2. Open in Gitpod: gitpod.io/#<your-repo-url>"
}

# =============================================================================
# Main
# =============================================================================

main() {
  case "$MODE" in
    vscode) generate_vscode ;;
    codespaces) generate_codespaces ;;
    gitpod) generate_gitpod ;;
  esac

  echo ""
  ui_ok "Done" "Dev container configuration generated"
}

main
