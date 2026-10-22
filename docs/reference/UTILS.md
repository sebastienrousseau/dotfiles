---
render_with_liquid: false
---

# Utilities

Aliases, functions, and the `dot` CLI provide day-to-day tooling across macOS, Linux, and WSL.

## Dot CLI

The `dot` command is the main interface: `dot <domain> [object] <verb>` (ADR-020). Run `dot help` for the overview, `dot help <term>` to search, and `dot -V` for the version. Old names keep working, with a warning, until 0.2.538; the **Was** column names them.

### Shortcuts

| Command | Short for |
|---------|-----------|
| `dot apply` | `dot config apply` |
| `dot sync` | `dot config sync` |
| `dot diff` | `dot config diff` |
| `dot status` | `dot config status` |
| `dot edit` | `dot config edit` |
| `dot cd` | `dot config path` |
| `dot update` | `dot system update` |

### dot agent

Modes, policy, sandbox, budgets.

| Command | Description | Was |
|---------|-------------|-----|
| `dot agent status` | Mode, policy and budgets | `dot mode current` |
| `dot agent check` | Check modes and policy | `dot mode doctor` |
| `dot agent run` | Run an agent task |  |
| `dot agent mode list` | Available modes | `dot mode list` |
| `dot agent mode show` | One mode in detail | `dot mode show` |
| `dot agent mode set` | Switch mode | `dot mode set` |
| `dot agent context show` | Context files in effect | `dot agents list` |
| `dot agent card show` | The agent card | `dot agent card` |
| `dot agent log show` | The agent log | `dot agent log` |
| `dot agent checkpoint list` | Saved checkpoints |  |
| `dot agent checkpoint save` | Save a checkpoint |  |
| `dot agent delegate list` | Configured delegates |  |
| `dot agent delegate run` | Run a command as a delegate |  |
| `dot agent context check` | Check the rendered context files are current | `dot agents check` |
| `dot agent context apply` | Render the context file for every harness | `dot agents render` |
| `dot agent mode run` | Run a command under a mode | `dot mode run` |
| `dot agent card check` | Check the card against the A2A spec | `dot mode conformance` |

### dot ai

Install, route and run coding agents.

| Command | Description | Was |
|---------|-------------|-----|
| `dot ai list` | Installed agents | `dot ai tools` |
| `dot ai install` | Install agents |  |
| `dot ai update` | Upgrade agent CLIs |  |
| `dot ai start` | Start an agent | `dot ai chat` |
| `dot ai run` | Run an agent once |  |
| `dot ai gateway serve` | Run the gateway in the foreground | `dot ai serve` |
| `dot ai login` | Authenticate an agent |  |
| `dot ai check` | Check agent installs and auth | `dot ai doctor` |
| `dot ai ask` | Ask about the local context | `dot ai-query` |
| `dot ai pattern list` | Prompt patterns | `dot patterns list` |
| `dot ai cost show` | Spend by agent and model | `dot ai cost` |
| `dot ai pattern show` | One prompt pattern | `dot patterns view` |
| `dot ai pattern edit` | Edit a prompt pattern | `dot patterns edit` |

### dot attest

Attestation and verification.

| Command | Description | Was |
|---------|-------------|-----|
| `dot attest show` | The workstation attestation | `dot attest` |
| `dot attest export` | Write attestation evidence | `dot attest --write` |
| `dot attest verify` | Verify evidence | `dot attest --verify` |

### dot cli

Plugins, updates, completions.

| Command | Description | Was |
|---------|-------------|-----|
| `dot cli list` | Installed plugins | `dot registry installed` |
| `dot cli show` | One plugin in detail | `dot registry info` |
| `dot cli install` | Install a plugin | `dot registry install` |
| `dot cli completion show` | Print a completion script | `dot completion` |
| `dot cli registry show` | The plugin registry URL | `dot registry url` |
| `dot cli registry set` | Point at another plugin registry | `dot registry set-url` |

### dot config

Apply, diff and sync the dotfiles.

| Command | Description | Was |
|---------|-------------|-----|
| `dot config status` | Pending changes and last apply | `dot status` |
| `dot config diff` | What apply would change | `dot diff` |
| `dot config apply` | Write the dotfiles to this machine | `dot apply` |
| `dot config sync` | Pull the source, then apply | `dot sync` |
| `dot config update` | Pull and apply the dotfiles only | `dot update` |
| `dot config edit` | Open a managed file in $EDITOR | `dot edit` |
| `dot config add` | Start managing an existing file | `dot add` |
| `dot config save` | Commit source changes | `dot commit` |
| `dot config init` | First-time setup of the dotfiles | `dot init`, `dot setup` |
| `dot config check` | Lint the source and templates | `dot lint` |
| `dot config export` | Write a portable bundle | `dot bundle` |
| `dot config uninstall` | Remove the setup, keeping the source | `dot uninstall` |
| `dot config path show` | Print the source directory | `dot cd` |
| `dot config profile show` | Show the active profile | `dot profile show` |
| `dot config profile set` | Switch profile | `dot profile set` |
| `dot config import` | Restore from an exported bundle | `dot bundle restore` |

### dot doctor

Health, repair, backup and rollback.

| Command | Description | Was |
|---------|-------------|-----|
| `dot doctor status` | Health summary | `dot health` |
| `dot doctor check` | Run every health check | `dot doctor` |
| `dot doctor fix` | Repair what check found | `dot heal` |
| `dot doctor backup` | Back up the setup | `dot backup` |
| `dot doctor restore` | Restore from a backup | `dot restore` |
| `dot doctor rollback` | Return to a previous generation | `dot rollback` |
| `dot doctor score show` | The setup score | `dot scorecard` |
| `dot doctor snapshot new` | Take a snapshot | `dot snapshot` |
| `dot doctor perf show` | Startup timings | `dot perf` |
| `dot doctor perf measure` | Benchmark startup | `dot benchmark` |
| `dot doctor drift show` | Drift from the source | `dot drift` |
| `dot doctor conflict list` | Conflicting files | `dot conflicts` |
| `dot doctor metric list` | Recorded metrics | `dot metrics` |

### dot fleet

Many hosts.

| Command | Description | Was |
|---------|-------------|-----|
| `dot fleet status` | Posture across hosts |  |
| `dot fleet apply` | Apply the fleet configuration |  |
| `dot fleet push` | Send configuration to a host | `dot teleport` |
| `dot fleet drift show` | Drift across hosts | `dot fleet drift` |
| `dot fleet namespace list` | Namespaces | `dot fleet namespace show` |
| `dot fleet log show` | Fleet events | `dot fleet events` |
| `dot fleet policy show` | Fleet policy | `dot fleet enforce status` |
| `dot fleet policy set` | Enforce a fleet policy | `dot fleet enforce set` |

### dot mcp

MCP servers as supply chain.

| Command | Description | Was |
|---------|-------------|-----|
| `dot mcp list` | Configured MCP servers | `dot mcp registry` |
| `dot mcp check` | Check servers and pins | `dot mcp doctor` |
| `dot mcp serve` | Run dot's read-only MCP server |  |

### dot secret

Secrets, keys and SSH certificates.

| Command | Description | Was |
|---------|-------------|-----|
| `dot secret init` | Set up the secret provider | `dot secrets-init` |
| `dot secret edit` | Edit the encrypted secrets file | `dot secrets`, `dot secrets edit` |
| `dot secret new` | Create the secrets file | `dot secrets-create` |
| `dot secret list` | Secret names without values | `dot secrets list` |
| `dot secret show` | One secret | `dot secrets get` |
| `dot secret set` | Store one secret | `dot secrets set` |
| `dot secret export` | Print secrets as environment | `dot secrets load` |
| `dot secret check` | Audit secret hygiene | `dot secret-audit` |
| `dot secret key new` | Create an ED25519 key | `dot ssh-key` |
| `dot secret cert list` | Certificates and expiry | `dot ssh-cert status` |
| `dot secret cert new` | Issue a short-lived SSH certificate | `dot ssh-cert`, `dot ssh-cert issue` |
| `dot secret provider show` | The active provider | `dot secrets provider` |
| `dot secret cert remove` | Revoke the current SSH certificate | `dot ssh-cert revoke` |

### dot security

OS hardening.

| Command | Description | Was |
|---------|-------------|-----|
| `dot security policy show` | The security policy | `dot policy` |
| `dot security disk show` | Disk encryption state | `dot encrypt-check` |
| `dot security score show` | The security score | `dot security-score` |
| `dot security firewall apply` | Harden the firewall setting | `dot firewall` |
| `dot security telemetry apply` | Harden the telemetry setting | `dot telemetry` |
| `dot security dns apply` | Harden the dns setting | `dot dns-doh` |
| `dot security lock apply` | Harden the lock setting | `dot lock-screen` |
| `dot security usb apply` | Harden the usb setting | `dot usb-safety` |

### dot shell

Aliases, history, startup caches.

| Command | Description | Was |
|---------|-------------|-----|
| `dot shell update` | Regenerate the startup caches | `dot cache-refresh` |
| `dot shell clean` | Clear the startup caches | `dot clean-cache` |
| `dot shell history list` | Recent history | `dot history` |
| `dot shell alias list` | Aliases and where each is defined; a term searches them | `dot aliases list` |
| `dot shell alias check` | Find shadowed or broken aliases | `dot alias-check` |
| `dot shell alias show` | Where one alias comes from | `dot aliases why` |
| `dot shell alias status` | Alias counts; --tiers for the ecosystem tiers | `dot aliases stats` |
| `dot shell alias export` | Write the alias cheatsheet | `dot aliases cheatsheet` |

### dot system

Updates, cleanup, scheduled maintenance.

| Command | Description | Was |
|---------|-------------|-----|
| `dot system status` | OS, disk, schedule and last run |  |
| `dot system update` | Update everything, asking first | `dot upgrade` |
| `dot system schedule list` | Scheduled jobs |  |
| `dot system schedule set` | Set the maintenance schedule |  |
| `dot system schedule run` | Run scheduled maintenance now |  |
| `dot system settings apply` | Apply the managed OS settings | `dot tune` |

### dot theme

One palette for every app.

| Command | Description | Was |
|---------|-------------|-----|
| `dot theme show` | Current theme and palette | `dot theme current` |
| `dot theme list` | Available themes |  |
| `dot theme set` | Switch theme everywhere |  |
| `dot theme wallpaper set` | Set the wallpaper and derive a palette | `dot wallpaper` |
| `dot theme font install` | Install the configured fonts | `dot fonts` |

Themes are auto-generated from wallpapers — `themes.toml` is not hand-edited. See [Theming Guide](../guides/THEMING.md) for the K-Means CIELAB extraction model and Apple-compatible dynamic HEIC support.

### dot tool

Toolchains, packages, project templates.

| Command | Description | Was |
|---------|-------------|-----|
| `dot tool list` | Toolchains and their versions | `dot env list` |
| `dot tool install` | Install the configured toolchains | `dot env install` |
| `dot tool update` | Upgrade toolchains | `dot env upgrade` |
| `dot tool remove` | Remove orphaned toolchains (a dry run without --yes) | `dot env prune` |
| `dot tool set` | Pin a toolchain version | `dot env use` |
| `dot tool export` | Print the tool environment | `dot env emit` |
| `dot tool new` | Create a project from a template | `dot new` |

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
