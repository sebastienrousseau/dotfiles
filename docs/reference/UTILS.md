# Utilities

Aliases, functions, and the `dot` CLI provide day-to-day tooling across macOS, Linux, and WSL.

## Dot CLI

The `dot` command is the main interface for managing dotfiles. Run `dot version` or `dot --version` to check the installed version.

### Core commands

| Command | Description |
|---------|-------------|
| `dot commit` | Create an AI-assisted conventional commit |
| `dot apply` | Apply dotfiles (`chezmoi apply`) |
| `dot sync` | Alias of apply |
| `dot update` | Pull latest changes and apply |
| `dot add <file>` | Add a file to chezmoi source |
| `dot diff` | Show local changes (excludes scripts) |
| `dot status` | Show configuration drift |
| `dot remove <path>` | Safely remove a managed file |
| `dot cd` | Print source directory path |
| `dot edit` | Open source in your editor |
| `dot clean-cache` | Clear generated shell initialization caches |
| `dot prewarm` | Regenerate shell caches for fast startup |
| `dot bundle` | Create an offline portable archive |
| `dot upgrade` | Update toolchains, plugins, and dotfiles |
| `dot packages` | Show installed packages and package managers |
| `dot cache-refresh` | Rebuild generated shell state |
| `dot search <term>` | Find commands by keyword |
| `dot help` | Show command help and the public reference |
| `dot version` | Show the installed dotfiles version |

### Diagnostics

| Command | Description |
|---------|-------------|
| `dot doctor` | Run system health checks (`--score|-s`, `--heal|-H`) |
| `dot health` | Run the health dashboard (`--verbose|-v`, `--json|-j`, `--fix|-f`, `--force|-F`) |
| `dot heal` | Auto-repair missing tools, chezmoi drift, broken symlinks, and critical files (`--dry-run|-n`, `--force|-f`) |
| `dot smoke-test` | Verify toolchains (Rust, Go, AI CLIs) |
| `dot verify` | Run security and integrity verification (`--security|-s`) |
| `dot chaos` | Simulate config corruption to test self-healing |
| `dot rollback` | Roll back dotfiles to the previous known-good state |
| `dot drift` | Detailed configuration drift dashboard |
| `dot benchmark` | Measure shell startup time (`--detailed|-d`, `--profile|-p`, `--compare|-c`, `--waterfall|-w`) |
| `dot perf` | Show performance mode + quick timing (`--json|-j`, `--profile|-p`, `--runs|-r`, `--target|-t`) |
| `dot score` | Show the high-level system health and security scorecard |
| `dot metrics` | Show recent observability metrics |
| `dot load-bench` | Measure heavy-layer readiness |
| `dot mcp` | Validate MCP policy and registry (`--strict|-s`, `--json|-j`) |
| `dot attest` | Export workstation evidence (`--json|-j`, `--write|-w`, `--fleet-store|-F`) |
| `dot history` | Analyse shell history |
| `dot security-score` | Score workstation security (`--verbose|-v`, `--quiet|-q`, `--json|-j`) |
| `dot snapshot` | Capture workstation state (`--baseline|-b`, `--force|-f`) |
| `dot ai` | Show categorized AI CLI status and launch an installed provider |
| `dot ai-setup` | Bootstrap supported AI CLIs interactively |
| `dot ai-query` | Run context-aware AI queries over the repo |
| `dot mode` | Show or switch the active agent profile |
| `dot agent` | Inspect agent metadata, logs, checkpoints, and conformance |
| `dot agent checkpoint` | Save, list, show, and replay bounded agent checkpoints |
| `dot agent conformance` | Validate A2A discovery and agent card conformance (`--strict|-s`, `--json|-j`) |

### Tools

| Command | Description |
|---------|-------------|
| `dot env` | Show managed runtime and tool versions |
| `dot profile` | Show or switch the active configuration profile |
| `dot keys` | Show the keybindings and signing reference |
| `dot tools` | Show tools documentation |
| `dot tools install` | Enter Nix development shell |
| `dot new <lang> <name>` | Scaffold a project (`python`/`go`/`node`) |
| `dot sandbox` | Launch Docker sandbox preview |
| `dot learn` | Start the guided onboarding tour |
| `dot docs` | Show the main repository documentation |
| `dot log-rotate` | Rotate `~/.local/share/dotfiles.log` |
| `dot lint` | Lint shell scripts (`--check|-c`, `--fix|-f`) |

## Universal Scripts

POSIX scripts in `~/.local/bin/` that work across macOS, Linux, and WSL.

| Command | Description |
|---------|-------------|
| `als` | Interactive alias and script viewer (categorized) |
| `cb` | Universal clipboard utility (detects `pbcopy`/`pbpaste`, `xclip`/`wl-copy`, or `clip.exe`) |
| `open` | Universal file/URL opener (maps to `open`, `xdg-open`, or `explorer.exe`) |
| `notify` | Universal desktop notifications (`osascript`, `notify-send`, or `powershell`) |
| `extract` | Universal archive extractor with robust format support and `gum` UI feedback |
| `up <n>` | Navigate up `n` directory levels |
| `bm` | Directory bookmarking tool (`add`, `goto`, `list`, `remove`, `update`) |
| `win` | WSL-specific shim for running Windows binaries with translated paths |

## Appearance

| Command | Description |
|---------|-------------|
| `dot theme` | Interactive picker (paired wallpaper themes only) |
| `dot theme <name>` | Switch directly (e.g. `dot theme tahoe-dark`) |
| `dot theme toggle` | Swap dark↔light within current family |
| `dot theme rebuild` | Regenerate themes from system + custom wallpapers via K-Means in CIELAB (`--force`, `--list`) |
| `dot theme list` | Show paired wallpaper themes with System/Custom source |
| `dot wallpaper` | Apply a wallpaper independently of theme |
| `dot fonts` | Install Nerd Fonts |
| `dot tune` | Apply supported host tuning changes |

Themes are auto-generated from wallpapers — `themes.toml` is not hand-edited. See [Theming Guide](../guides/THEMING.md) for the K-Means CIELAB extraction model and Apple-compatible dynamic HEIC support.

## AI Bridges

| Command | Description |
|---------|-------------|
| `dot cl` | Invoke Claude Code with dotfiles context injection |
| `dot copilot` | Invoke GitHub Copilot CLI with dotfiles context injection |
| `dot gemini` | Invoke Gemini CLI with dotfiles context injection |
| `dot kiro` | Invoke Kiro CLI with dotfiles context injection |
| `dot sgpt` | Invoke Shell-GPT with dotfiles context injection |
| `dot ollama` | Invoke Ollama with dotfiles context injection |
| `dot opencode` | Invoke OpenCode with dotfiles context injection |
| `dot aider` | Invoke Aider with dotfiles context injection |

## Secrets

| Command | Description |
|---------|-------------|
| `dot secrets-init` | Initialize the local age identity for secrets |
| `dot secrets` | Manage encrypted secrets and environment buckets |
| `dot secrets-create` | Create a new encrypted secrets file |
| `dot ssh-key` | Encrypt a local SSH key with age |
| `dot ssh-cert` | Manage short-lived SSH certificates (`issue`/`status`/`revoke`) |

## Security (opt-in)

| Command | Description |
|---------|-------------|
| `dot backup` | Create a compressed backup |
| `dot encrypt-check` | Check disk encryption status |
| `dot firewall` | Apply firewall hardening |
| `dot telemetry` | Disable telemetry |
| `dot dns-doh` | Enable DNS-over-HTTPS |
| `dot lock-screen` | Enforce lock screen idle settings |
| `dot usb-safety` | Disable automount for removable media |

## Fleet

| Command | Description |
|---------|-------------|
| `dot fleet` | Show fleet node status, namespace, and drift |
| `dot fleet drift` | Check configuration drift across managed files |
| `dot fleet namespace` | Show or set the active fleet namespace |
| `dot fleet events` | Show recent local fleet events |
