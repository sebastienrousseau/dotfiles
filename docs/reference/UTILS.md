# Utilities

Aliases, functions, and the `dot` CLI provide day-to-day tooling across macOS, Linux, and WSL.

## Dot CLI

The `dot` command is the main interface for managing dotfiles. Run `dot version` or `dot --version` to check the installed version.

### Core commands

| Command | Description |
|---------|-------------|
| `dot apply` | Apply dotfiles (`chezmoi apply`) |
| `dot sync` | Alias of apply |
| `dot update` | Pull latest changes and apply |
| `dot add <file>` | Add a file to chezmoi source |
| `dot diff` | Show local changes (excludes scripts) |
| `dot status` | Show configuration drift |
| `dot cd` | Print source directory path |
| `dot edit` | Open source in your editor |
| `dot prewarm` | Regenerate shell caches for fast startup |
| `dot bundle` | Create an offline portable archive |

### Diagnostics

| Command | Description |
|---------|-------------|
| `dot doctor` | Run system health checks (`--score|-s`, `--heal|-H`) |
| `dot health` | Run the health dashboard (`--verbose|-v`, `--json|-j`, `--fix|-f`, `--force|-F`) |
| `dot heal` | Auto-repair missing tools and broken state |
| `dot smoke-test` | Verify toolchains (Rust, Go, AI CLIs) |
| `dot verify` | Run security and integrity verification (`--security|-s`) |
| `dot chaos` | Simulate config corruption to test self-healing |
| `dot drift` | Detailed configuration drift dashboard |
| `dot benchmark` | Measure shell startup time (`--detailed|-d`, `--profile|-p`, `--compare|-c`, `--waterfall|-w`) |
| `dot perf` | Show performance mode + quick timing (`--json|-j`, `--profile|-p`, `--runs|-r`, `--target|-t`) |
| `dot mcp` | Validate MCP policy and registry (`--strict|-s`, `--json|-j`) |
| `dot attest` | Export workstation evidence (`--json|-j`, `--write|-w`) |
| `dot history` | Analyse shell history |
| `dot security-score` | Score workstation security (`--verbose|-v`, `--quiet|-q`, `--json|-j`) |
| `dot snapshot` | Capture workstation state (`--baseline|-b`, `--force|-f`) |
| `dot ai` | Show AI helper status (opt-in) |

### Tools

| Command | Description |
|---------|-------------|
| `dot tools` | Show tools documentation |
| `dot tools install` | Enter Nix development shell |
| `dot new <lang> <name>` | Scaffold a project (`python`/`go`/`node`) |
| `dot sandbox` | Launch Docker sandbox preview |
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
| `dot theme` | Switch terminal themes (dark/light) |
| `dot wallpaper` | Apply a wallpaper |
| `dot fonts` | Install Nerd Fonts |

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
| `dot ssh-cert` | Manage short-lived SSH certificates (`issue`/`status`/`revoke`) |
