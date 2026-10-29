---
render_with_liquid: false
---

# Script Catalog

Catalog of the executables chezmoi installs into `~/.local/bin/` from `defaults/dot_local/bin/`.

## Core and dotfiles workflows

| Command | Description |
|---------|-------------|
| `dot` | Primary dotfiles command-line interface |
| `dot.ps1` | PowerShell entry point for the `dot` CLI |
| `dot_completion` | Load (in zsh) or print the zsh completion for `dot` |
| `dot-ai` | Legacy AI query wrapper for local dotfiles context |
| `dot-bootstrap` | Deterministic bootstrap entrypoint for fresh machines |
| `dot-launch-or-focus` | Launch or focus desktop applications and sessions |
| `dot-load-benchmark` | Measure heavy shell layer readiness in a fresh shell |
| `dot-load-benchmark-pty` | PTY-based readiness benchmark for shell prewarm flows |
| `dot-theme-sync` | Synchronize managed theme state across tools |
| `tour` | Interactive guided tour of the dotfiles environment |

## AI and git helpers

| Command | Description |
|---------|-------------|
| `ai-update` | Update AI-related CLIs, runtimes, and supporting tools |
| `ai_core` | Local AI runtime wrapper and provider fallback core |
| `dot-ai-serve` | Local proxy that serves the Anthropic and OpenAI APIs through the installed `claude` CLI |
| `dot-ai-proxy` | Start, stop and route AI CLIs through `dot-ai-serve` |
| `dot-ai-log` | Record an AI run in `~/.local/share/dotfiles-ai.db` |
| `git-ai-commit` | Generate commit messages from staged changes with AI |
| `git-ai-diff` | Review diffs and change sets with AI assistance |
| `antigravity` | Safe wrapper for Antigravity updater execution |

## Clipboard, encoding, and data inspection

| Command | Description |
|---------|-------------|
| `b64` | Base64 encode and decode utility |
| `bm` | Directory bookmark manager |
| `cb` | Cross-platform clipboard helper |
| `dtags` | Inspect Docker image tags |
| `epoch` | Convert between human time and Unix epoch values |
| `extract` | Archive extraction helper |
| `hash` | Compute hashes for strings or files |
| `hashsum` | Cross-platform cryptographic hash calculator |
| `hex` | Hex dump and transformation helper |
| `jsonv` | JSON validator and formatter |
| `jwt` | JWT decoder and payload inspector |
| `regex` | Regular expression testing helper |
| `uuid` | UUID generation utility |
| `yamlv` | YAML validator |

## System, network, and session tools

| Command | Description |
|---------|-------------|
| `gd` | Git diff workflow helper |
| `gbd` | Git branch deletion workflow helper |
| `gl` | Git log workflow helper |
| `kill-port` | Terminate processes bound to a TCP or UDP port |
| `lorem` | Lorem ipsum text generator |
| `mkscript` | Create a ready-to-run shell script |
| `monitor` | System monitor and environment inspection helper |
| `myip` | Show public and local IP addresses |
| `notify` | Cross-platform desktop notification helper |
| `open` | Cross-platform opener for files, URLs, and paths |
| `pw` | Password and secret helper utility |
| `rec-start` | Start shell session recording |
| `rec-stop` | Stop shell session recording |
| `start-niri` | Launch a Niri compositor session |
| `tmux-ai` | Show active AI providers in tmux and launch provider sessions |
| `tmux-sessionizer` | Fuzzy tmux session and project switcher |
| `tmux-status` | Helpers for the wallpaper-aware tmux status bar |
| `up` | Jump up directory levels quickly |
| `win` | WSL bridge for launching Windows programs |

## Maintainer and per-host tools

| Command | Description |
|---------|-------------|
| `standards-sync` | Keep the standards repository, `~/Code` and the dotfiles in sync |
| `corralctl-sync.sh` | Scheduled `corralctl` sync into `~/Code` (macOS launchd agent) |
| `corralctl-daily-run.sh` | Daily `corralctl` run started by `corralctl.timer` (Linux, `corral_gitea_mirror` only) |
| `corralctl-gitea-mirror.sh` | Mirror GitHub to a NAS Gitea (Linux, `corral_gitea_mirror` only) |

`defaults/dot_local/bin/remove_update` is not a command: it tells chezmoi to delete a stale `~/.local/bin/update`. Use `dot update` instead.
