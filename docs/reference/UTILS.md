---
render_with_liquid: false
---

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
| `dot uninstall` | Remove the managed dotfiles environment (prompts unless `--force`) |
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
| `dot doctor` | Run system health checks (`--score/-s`,`--heal/-H`) |
| `dot secret-audit` | Audit secret hygiene and leakage surface |
| `dot health` | Run the health dashboard (`--verbose/-v`,`--json/-j`,`--fix/-f`,`--force/-F`) |
| `dot heal` | Auto-repair missing tools, chezmoi drift, broken symlinks, and critical files (`--dry-run/-n`,`--force/-f`) |
| `dot smoke-test` | Verify toolchains (Rust, Go, AI CLIs) |
| `dot verify` | Run security and integrity verification (`--security/-s`) |
| `dot chaos` | Simulate config corruption to test self-healing |
| `dot rollback` | Roll back dotfiles to the previous known-good state |
| `dot drift` | Detailed configuration drift dashboard |
| `dot benchmark` | Measure shell startup time (`--detailed/-d`,`--profile/-p`,`--compare/-c`,`--waterfall/-w`) |
| `dot perf` | Show performance mode + quick timing (`--json/-j`,`--profile/-p`,`--runs/-r`,`--target/-t`) |
| `dot score` | Show the high-level system health and security scorecard |
| `dot metrics` | Show recent observability metrics |
| `dot load-bench` | Measure heavy-layer readiness |
| `dot mcp` | Validate MCP policy and registry (`--strict/-s`,`--json/-j`) |
| `dot attest` | Export workstation evidence (`--json/-j`,`--write/-w`,`--fleet-store/-F`) |
| `dot history` | Analyse shell history |
| `dot security-score` | Score workstation security (`--verbose/-v`,`--quiet/-q`,`--json/-j`) |
| `dot snapshot` | Capture workstation state (`--baseline/-b`,`--force/-f`) |
| `dot ai` | Open the AI fleet cockpit; run prompts, serve a local Claude gateway, install, cost |
| `dot ai-setup` | Bootstrap AI CLIs interactively (deprecated alias for `dot ai login`) |
| `dot ai-query` | Context-aware RAG query over the repo (deprecated alias for `dot ai ask`) |
| `dot mode` | Show or switch the active agent profile |
| `dot agent` | Inspect agent metadata, logs, checkpoints, and conformance |
| `dot agent checkpoint` | Save, list, show, and replay bounded agent checkpoints |
| `dot agent conformance` | Validate A2A discovery and agent card conformance (`--strict/-s`,`--json/-j`) |

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
| `dot completion <bash\|zsh\|fish\|nu>` | Generate shell completions from the command registry |
| `dot lint` | Lint shell scripts (`--check/-c`,`--fix/-f`) |

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

## AI Bridges (deprecated aliases)

These run a tool with dotfiles context injection. They still work but are
**deprecated** in favour of `dot ai <tool>` (e.g. `dot ai claude "…"`); each
prints a one-line hint. See [AI.md](../AI.md) for the full surface.

| Command | Description |
|---------|-------------|
| `dot cl` | Claude Code with context injection — use `dot ai claude` |
| `dot copilot` | GitHub Copilot CLI — use `dot ai copilot` |
| `dot agy` | Antigravity CLI — use `dot ai agy` |
| `dot kiro` | Kiro CLI — use `dot ai kiro` |
| `dot sgpt` | Shell-GPT — use `dot ai sgpt` |
| `dot ollama` | Ollama — use `dot ai ollama` |
| `dot opencode` | OpenCode — use `dot ai opencode` |
| `dot aider` | Aider — use `dot ai aider` |

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
| `dot policy` | Check and enforce security policies across the environment |
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
| `dot teleport <user@host>` | Deploy the dotfiles environment to a remote host over SSH |

## Subcommands

Every `dot` command's individually-enforced subcommands (see `dot help`).

| Command | Description |
|---|---|
| `dot fleet status` | Show this node's fleet status: id, namespace, version, OS, drift, last apply |
| `dot fleet enforce` | Show or set RBAC enforcement mode (advisory/strict) for agent profiles |
| `dot fleet apply` | SSH to every host in fleet.toml and run dot sync (or a custom --cmd) |
| `dot ai chat` | Start an interactive AI session with a chosen tool |
| `dot ai tools` | Show installed AI CLI tools and their versions |
| `dot ai install` | Install AI CLI tools via mise/native installers |
| `dot ai serve` | Run the local AI gateway/proxy that routes non-Claude providers |
| `dot ai cost` | Report AI spend across every provider from the unified run log |
| `dot ai login` | Interactive setup/authentication for installed AI CLI tools |
| `dot ai doctor` | Diagnose AI tooling configuration and connectivity |
| `dot ai ask` | Context-aware RAG query over your dotfiles |
| `dot ai run` | Run a one-shot prompt with an AI tool |
| `dot ai delegate` | Delegate a coding task to a cheaper AI model under agent policy |
| `dot mode list` | List available agent operating profiles (ask/plan/apply/audit) |
| `dot mode current` | Show the active agent profile and its policy |
| `dot mode show` | Show details of a specific agent profile |
| `dot mode set` | Switch the active agent profile |
| `dot mode run` | Run a command under a given agent profile with a checkpoint |
| `dot mode doctor` | Validate the agent-profiles.json config and default profile |
| `dot agent card` | Show the local agent card metadata |
| `dot agent log` | Tail the agent session audit log |
| `dot agent checkpoint` | Manage agent run checkpoints (save/list/show/replay) |
| `dot agent delegate` | Delegate execution to an allowed sub-agent |
| `dot agent a2a-card` | Show or validate the A2A v0.3 agent card |
| `dot agent conformance` | Run the A2A conformance test suite |
| `dot mcp doctor` | Run the MCP policy/supply-chain/config audit |
| `dot mcp registry` | Show the configured MCP server registry |
| `dot secrets edit` | Edit the encrypted secrets file (age) |
| `dot secrets set` | Store a secret value under a key |
| `dot secrets get` | Retrieve a secret value (--raw for plaintext) |
| `dot secrets list` | List indexed secret keys |
| `dot secrets load` | Emit export lines for a secrets bucket (use with eval) |
| `dot secrets provider` | Show the active secrets provider |
| `dot env list` | List managed tool versions via mise |
| `dot env prune` | Show or remove orphan tool installs (--yes to commit) |
| `dot env install` | Install requested tool versions via mise |
| `dot env use` | Pin a tool version globally/locally via mise |
| `dot registry list` | List modules in the configured module registry |
| `dot registry search` | Filter registry modules by keyword |
| `dot registry info` | Print full metadata for a registry module |
| `dot registry install` | Install a registry module (scaffold) |
| `dot registry url` | Show the active registry URL |
| `dot registry set-url` | Override the registry URL (https only; persists) |
| `dot theme list` | Show all available terminal/wallpaper themes |
| `dot theme set` | Set a theme by name (interactive picker if omitted) |
| `dot theme toggle` | Toggle light/dark within the current theme family |
| `dot theme sync` | Sync the dotfiles theme with system dark/light mode |
| `dot theme family` | Cycle between theme families |
| `dot theme current` | Show the current theme info |
| `dot theme rebuild` | Regenerate themes from system and custom wallpapers |
| `dot wallpaper sync` | Sync wallpaper from your library |
| `dot wallpaper rotate` | Rotate to the next wallpaper in your library |
| `dot tools install` | Enter the Nix development shell with all managed tools |
| `dot tools docs` | Show the full tools markdown documentation |
| `dot profile show` | Show the active configuration profile and feature flags |
| `dot profile set` | Set the active configuration profile (run dot sync to apply) |
| `dot agents list` | Show recognised AI agent harnesses and their config paths |
| `dot agents check` | Verify AGENTS.md tracks CLAUDE.md (exit 1 if drifted) |
| `dot agents render` | Regenerate AGENTS.md and per-harness config from CLAUDE.md |
| `dot aliases list` | List all shell aliases shipped by the dotfiles |
| `dot aliases search` | Search aliases by term |
| `dot aliases why` | Show details and deprecation status for a single alias |
| `dot aliases stats` | Show alias usage counts from shell history |
| `dot aliases cheatsheet` | Generate the alias cheatsheet markdown |
| `dot aliases tiers` | Show which alias tiers/ecosystems are enabled |
| `dot patterns list` | List AI steering patterns |
| `dot patterns view` | View an AI steering pattern |
| `dot patterns edit` | Edit an AI steering pattern in $EDITOR |
| `dot keys sign-check` | Verify git commit-signing configuration and key availability |
