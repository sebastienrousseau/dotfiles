#!/usr/bin/env bash

################################################################################
# 🅳🅾🆃🅵🅸🅻🅴🆂 Bootstrap
# File: scripts/bootstrap.sh
# Version: 0.2.471
# Author: Sebastien Rousseau
# Copyright (c) 2015-2025. All rights reserved
# Description: Main bootstrap script (idempotent)
# Website: https://dotfiles.io
# License: MIT
################################################################################

set -euo pipefail

DOTFILES_ROOT="${HOME}/.dotfiles"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Color output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${BLUE}→${NC} $*"
}

success() {
    echo -e "${GREEN}✓${NC} $*"
}

# 1. Create essential directories
log "Creating directories..."
mkdir -p "${DOTFILES_ROOT}/state"
mkdir -p "${DOTFILES_ROOT}/metrics"
mkdir -p "${HOME}/.local/bin"
success "Directories created"

# 2. Symlink bin/dotfiles to ~/.local/bin if not exists
if [[ ! -L "${HOME}/.local/bin/dotfiles" ]] && [[ -f "${DOTFILES_ROOT}/bin/dotfiles" ]]; then
    log "Creating symlink for dotfiles command..."
    ln -sf "${DOTFILES_ROOT}/bin/dotfiles" "${HOME}/.local/bin/dotfiles"
    chmod +x "${DOTFILES_ROOT}/bin/dotfiles"
    success "dotfiles command linked"
fi

# 3. Ensure ~/.local/bin is in PATH
if [[ ":$PATH:" != *":${HOME}/.local/bin:"* ]]; then
    log "Adding ~/.local/bin to PATH..."
    if [[ -f "${HOME}/.bashrc" ]]; then
        if ! grep -q "~/.local/bin" "${HOME}/.bashrc" 2>/dev/null; then
            echo 'export PATH="${HOME}/.local/bin:${PATH}"' >> "${HOME}/.bashrc"
        fi
    fi
    if [[ -f "${HOME}/.zshrc" ]]; then
        if ! grep -q "~/.local/bin" "${HOME}/.zshrc" 2>/dev/null; then
            echo 'export PATH="${HOME}/.local/bin:${PATH}"' >> "${HOME}/.zshrc"
        fi
    fi
    success "PATH updated"
fi

# 4. Create baseline metrics if not exists
if [[ ! -f "${DOTFILES_ROOT}/metrics/baselines.json" ]]; then
    log "Initializing baseline metrics..."
    cat > "${DOTFILES_ROOT}/metrics/baselines.json" << 'EOF'
{
  "startup_time": {
    "bash_fast_p50_ms": 300,
    "bash_fast_p95_ms": 400,
    "bash_normal_p50_ms": 500,
    "bash_normal_p95_ms": 600,
    "zsh_p50_ms": 20,
    "zsh_p95_ms": 30,
    "threshold_regression_percent": 20,
    "threshold_regression_ms": 50
  },
  "last_updated": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
    success "Baseline metrics created"
fi

# 5. Test core functionality
log "Testing core functionality..."
if bash -n "${DOTFILES_ROOT}/.bashrc" 2>/dev/null; then
    success ".bashrc syntax OK"
fi

if command -v zsh &>/dev/null && zsh -n "${DOTFILES_ROOT}/.zshrc" 2>/dev/null; then
    success ".zshrc syntax OK"
fi

# 6. Clear cache to pick up changes
if [[ -f "${HOME}/.bash_dotfiles_cache" ]]; then
    log "Clearing dotfiles cache..."
    rm -f "${HOME}/.bash_dotfiles_cache"
    success "Cache cleared"
fi

success "Bootstrap complete!"
echo ""
echo "Next steps:"
echo "1. Reload your shell: exec \$SHELL"
echo "2. Check status: dotfiles status"
echo "3. Run doctor: dotfiles doctor"
