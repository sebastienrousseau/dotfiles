# Node.js Tooling (Optional)

This directory contains optional Node.js-based installation and packaging tools for the dotfiles repository.

## Overview

The core dotfiles functionality (aliases, functions, configurations) is **pure Bash/Zsh** and does not require Node.js.

This tooling provides:
- npm package distribution
- Automated installation workflows
- Bundled deployment options

## Requirements

- Node.js >= 18
- pnpm (recommended) or npm

## Usage

```bash
# Install dependencies
cd ~/.dotfiles/tools/nodejs
pnpm install

# Run tooling (see package.json for scripts)
pnpm run <command>
```

## Core Dotfiles (No Node.js Required)

For standard dotfiles usage, see the main README. You do NOT need Node.js for:
- Shell configuration
- Aliases and functions
- Health checks (`dotfiles doctor`)
- Daily usage

## When to Use This

Only use this Node.js tooling if you:
- Want to distribute dotfiles via npm
- Need automated provisioning workflows
- Prefer Node.js-based installation scripts

**Most users can ignore this directory entirely.**
