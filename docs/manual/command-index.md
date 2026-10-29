---
render_with_liquid: false
---

# Command Index

Every `dot` command, generated from the plugin manifests through
`lib/dot/data/commands.txt` (ADR-020). A command marked *planned* is
declared but not built yet. To refresh after changing a manifest, run
`tools/docs/generate-command-index.sh`; the Doc Drift job fails when this
file is stale. `dot help <command>` shows one command and its flags.

| Command | Summary |
|---------|---------|
| `dot agent status` | Mode, policy and budgets |
| `dot agent check` | Check modes and policy |
| `dot agent run` | Run an agent task |
| `dot agent suspend` | Pause running agents *(planned)* |
| `dot agent resume` | Resume paused agents *(planned)* |
| `dot agent export` | Export the AI bill of materials *(planned)* |
| `dot agent mode list` | Available modes |
| `dot agent mode show` | One mode in detail |
| `dot agent mode set` | Switch mode |
| `dot agent context show` | Context files in effect |
| `dot agent card show` | The agent card |
| `dot agent log show` | The agent log |
| `dot agent checkpoint list` | Saved checkpoints |
| `dot agent checkpoint save` | Save a checkpoint |
| `dot agent policy show` | The sandbox policy *(planned)* |
| `dot agent budget show` | Budgets and spend *(planned)* |
| `dot agent delegate list` | Configured delegates |
| `dot agent delegate run` | Run a command as a delegate |
| `dot agent context check` | Check the rendered context files are current |
| `dot agent context apply` | Render the context file for every harness |
| `dot agent mode run` | Run a command under a mode |
| `dot agent card check` | Check the card against the A2A spec |
| `dot ai list` | Installed agents |
| `dot ai install` | Install agents |
| `dot ai update` | Upgrade agent CLIs |
| `dot ai start` | Start an agent |
| `dot ai run` | Run an agent once |
| `dot ai gateway serve` | Run the gateway in the foreground |
| `dot ai login` | Authenticate an agent |
| `dot ai check` | Check agent installs and auth |
| `dot ai ask` | Ask about the local context |
| `dot ai pattern list` | Prompt patterns |
| `dot ai cost show` | Spend by agent and model |
| `dot ai gateway show` | Gateway statistics *(planned)* |
| `dot ai inventory show` | Agents, versions and config *(planned)* |
| `dot ai pattern show` | One prompt pattern |
| `dot ai pattern edit` | Edit a prompt pattern |
| `dot attest show` | The workstation attestation |
| `dot attest export` | Write attestation evidence |
| `dot attest verify` | Verify evidence |
| `dot cli list` | Installed plugins |
| `dot cli show` | One plugin in detail |
| `dot cli install` | Install a plugin |
| `dot cli update` | Update dot and its plugins *(planned)* |
| `dot cli remove` | Remove a plugin *(planned)* |
| `dot cli verify` | Verify plugin provenance *(planned)* |
| `dot cli new` | Create a plugin from the template *(planned)* |
| `dot cli completion show` | Print a completion script |
| `dot cli registry show` | The plugin registry URL |
| `dot cli registry set` | Point at another plugin registry |
| `dot config status` | Pending changes and last apply |
| `dot config diff` | What apply would change |
| `dot config apply` | Write the dotfiles to this machine |
| `dot config sync` | Pull the source, then apply |
| `dot config update` | Pull and apply the dotfiles only |
| `dot config edit` | Open a managed file in $EDITOR |
| `dot config add` | Start managing an existing file |
| `dot config save` | Commit source changes |
| `dot config init` | First-time setup of the dotfiles |
| `dot config check` | Lint the source and templates |
| `dot config export` | Write a portable bundle |
| `dot config uninstall` | Remove the setup, keeping the source |
| `dot config path show` | Print the source directory |
| `dot config profile show` | Show the active profile |
| `dot config profile set` | Switch profile |
| `dot config import` | Restore from an exported bundle |
| `dot doctor status` | Health summary |
| `dot doctor check` | Run every health check |
| `dot doctor fix` | Repair what check found |
| `dot doctor backup` | Back up the setup |
| `dot doctor restore` | Restore from a backup |
| `dot doctor rollback` | Return to a previous generation |
| `dot doctor score show` | The setup score |
| `dot doctor snapshot list` | Snapshots *(planned)* |
| `dot doctor snapshot new` | Take a snapshot |
| `dot doctor perf show` | Startup timings |
| `dot doctor perf measure` | Benchmark startup |
| `dot doctor drift show` | Drift from the source |
| `dot doctor conflict list` | Conflicting files |
| `dot doctor metric list` | Recorded metrics |
| `dot doctor report show` | Weekly posture report *(planned)* |
| `dot fleet status` | Posture across hosts |
| `dot fleet apply` | Apply the fleet configuration |
| `dot fleet push` | Send configuration to a host |
| `dot fleet drift show` | Drift across hosts |
| `dot fleet namespace list` | Namespaces |
| `dot fleet log show` | Fleet events |
| `dot fleet policy show` | Fleet policy |
| `dot fleet policy set` | Enforce a fleet policy |
| `dot mcp list` | Configured MCP servers |
| `dot mcp check` | Check servers and pins |
| `dot mcp serve` | Run dot's read-only MCP server |
| `dot secret status` | Provider, vault state and key counts *(planned)* |
| `dot secret init` | Set up the secret provider |
| `dot secret edit` | Edit the encrypted secrets file |
| `dot secret new` | Create the secrets file |
| `dot secret list` | Secret names without values |
| `dot secret show` | One secret |
| `dot secret set` | Store one secret |
| `dot secret export` | Print secrets as environment |
| `dot secret check` | Audit secret hygiene |
| `dot secret key list` | Keys without their values *(planned)* |
| `dot secret key new` | Create an ED25519 key |
| `dot secret cert list` | Certificates and expiry |
| `dot secret cert new` | Issue a short-lived SSH certificate |
| `dot secret provider show` | The active provider |
| `dot secret provider set` | Switch provider *(planned)* |
| `dot secret cert remove` | Revoke the current SSH certificate |
| `dot security status` | Hardening summary *(planned)* |
| `dot security policy show` | The security policy |
| `dot security disk show` | Disk encryption state |
| `dot security score show` | The security score |
| `dot security firewall show` | Current firewall setting *(planned)* |
| `dot security firewall apply` | Harden the firewall setting |
| `dot security telemetry show` | Current telemetry setting *(planned)* |
| `dot security telemetry apply` | Harden the telemetry setting |
| `dot security dns show` | Current dns setting *(planned)* |
| `dot security dns apply` | Harden the dns setting |
| `dot security lock show` | Current lock setting *(planned)* |
| `dot security lock apply` | Harden the lock setting |
| `dot security usb show` | Current usb setting *(planned)* |
| `dot security usb apply` | Harden the usb setting |
| `dot session select` | Pick a session to open *(planned)* |
| `dot session list` | Sessions on this machine *(planned)* |
| `dot session new` | Start a named session *(planned)* |
| `dot session open` | Attach to a session *(planned)* |
| `dot session stop` | End a session *(planned)* |
| `dot session restore` | Restore saved sessions *(planned)* |
| `dot shell status` | Shell, startup time and cache state *(planned)* |
| `dot shell update` | Regenerate the startup caches |
| `dot shell clean` | Clear the startup caches |
| `dot shell history list` | Recent history |
| `dot shell alias list` | Aliases and where each is defined; a term searches them |
| `dot shell alias check` | Find shadowed or broken aliases |
| `dot shell alias show` | Where one alias comes from |
| `dot shell alias status` | Alias counts; --tiers for the ecosystem tiers |
| `dot shell alias export` | Write the alias cheatsheet |
| `dot system status` | OS, disk, schedule and last run |
| `dot system update` | Update everything, asking first |
| `dot system clean` | Reclaim space, asking first *(planned)* |
| `dot system show` | Hardware and host details *(planned)* |
| `dot system schedule list` | Scheduled jobs |
| `dot system schedule set` | Set the maintenance schedule |
| `dot system schedule run` | Run scheduled maintenance now |
| `dot system settings show` | Current OS settings *(planned)* |
| `dot system settings apply` | Apply the managed OS settings |
| `dot theme show` | Current theme and palette |
| `dot theme list` | Available themes |
| `dot theme set` | Switch theme everywhere |
| `dot theme wallpaper set` | Set the wallpaper and derive a palette |
| `dot theme font list` | Installed terminal fonts *(planned)* |
| `dot theme font install` | Install the configured fonts |
| `dot tool list` | Toolchains and their versions |
| `dot tool install` | Install the configured toolchains |
| `dot tool update` | Upgrade toolchains |
| `dot tool remove` | Remove orphaned toolchains (a dry run without --yes) |
| `dot tool set` | Pin a toolchain version |
| `dot tool export` | Print the tool environment |
| `dot tool new` | Create a project from a template |
| `dot top measure` | Sample once and print the result *(planned)* |
| `dot top report show` | Usage report *(planned)* |
| `dot ui show` | The primitives on offer *(planned)* |
| `dot ui select` | Interactive picker for scripts *(planned)* |
| `dot ui run` | Run a command with progress *(planned)* |
| `dot ui table show` | Render rows as a table *(planned)* |

## Shortcuts

| Shortcut | Runs |
|----------|------|
| `dot apply` | `dot config apply` |
| `dot sync` | `dot config sync` |
| `dot diff` | `dot config diff` |
| `dot status` | `dot config status` |
| `dot edit` | `dot config edit` |
| `dot cd` | `dot config path` |
| `dot update` | `dot system update` |

## Old names

An old name prints its new name. A deprecated one still runs until the release shown; a removed one, and a deprecated one from that release on, exits 127.

| Old name | New name | Release |
|----------|----------|---------|
| `dot mode` | `dot agent mode` | 0.2.538 |
| `dot agents` | `dot agent context` | 0.2.538 |
| `dot ai-setup` | `dot ai install --interactive` | 0.2.538 |
| `dot ai-query` | `dot ai ask` | 0.2.538 |
| `dot patterns` | `dot ai pattern` | 0.2.538 |
| `dot cl` | `dot ai run claude` | 0.2.538 |
| `dot claude` | `dot ai run claude` | 0.2.538 |
| `dot codex` | `dot ai run codex` | 0.2.538 |
| `dot copilot` | `dot ai run copilot` | 0.2.538 |
| `dot kimi` | `dot ai run kimi` | 0.2.538 |
| `dot agy` | `dot ai run agy` | 0.2.538 |
| `dot goose` | `dot ai run goose` | 0.2.538 |
| `dot kiro` | `dot ai run kiro` | 0.2.538 |
| `dot sgpt` | `dot ai run sgpt` | 0.2.538 |
| `dot ollama` | `dot ai run ollama` | 0.2.538 |
| `dot opencode` | `dot ai run opencode` | 0.2.538 |
| `dot aider` | `dot ai run aider` | 0.2.538 |
| `dot autohand` | `dot ai run autohand` | 0.2.538 |
| `dot vibe` | `dot ai run vibe` | 0.2.538 |
| `dot qwen` | `dot ai run qwen` | 0.2.538 |
| `dot zai` | `dot ai run zai` | 0.2.538 |
| `dot attestation` | `dot attest` | 0.2.538 |
| `dot completion` | `dot cli completion` | 0.2.538 |
| `dot registry` | `dot cli list --available` | 0.2.538 |
| `dot search` | `dot help` | 0.2.538 |
| `dot manual` | `dot help --manual` | 0.2.538 |
| `dot docs` | `dot help --readme` | 0.2.538 |
| `dot learn` | `dot help tour` | 0.2.538 |
| `dot add` | `dot config add` | 0.2.538 |
| `dot commit` | `dot config save` | 0.2.538 |
| `dot uninstall` | `dot config uninstall` | 0.2.538 |
| `dot init` | `dot config init` | 0.2.538 |
| `dot setup` | `dot config init` | 0.2.538 |
| `dot profile` | `dot config profile` | 0.2.538 |
| `dot sandbox` | `dot config apply --sandbox` | 0.2.538 |
| `dot bundle` | `dot config export` | 0.2.538 |
| `dot lint` | `dot config check` | 0.2.538 |
| `dot health` | `dot doctor` | 0.2.538 |
| `dot health-check` | `dot doctor` | 0.2.538 |
| `dot scorecard` | `dot doctor score` | 0.2.538 |
| `dot score` | `dot doctor score` | 0.2.538 |
| `dot snapshot` | `dot doctor snapshot new` | 0.2.538 |
| `dot perf` | `dot doctor perf` | 0.2.538 |
| `dot benchmark` | `dot doctor perf --profile` | 0.2.538 |
| `dot load-bench` | `dot doctor perf --ready` | 0.2.538 |
| `dot load-bench-pty` | `dot doctor perf --ready --pty` | 0.2.538 |
| `dot rollback` | `dot doctor rollback` | 0.2.538 |
| `dot heal` | `dot doctor fix` | 0.2.538 |
| `dot drift` | `dot doctor drift` | 0.2.538 |
| `dot conflicts` | `dot doctor conflict` | 0.2.538 |
| `dot restore` | `dot doctor restore` | 0.2.538 |
| `dot metrics` | `dot doctor metric` | 0.2.538 |
| `dot backup` | `dot doctor backup` | 0.2.538 |
| `dot chaos` | `dot doctor` | 0.2.538 |
| `dot smoke-test` | `dot doctor` | 0.2.538 |
| `dot keys` | `dot doctor` | 0.2.538 |
| `dot teleport` | `dot fleet push` | 0.2.538 |
| `dot secrets-init` | `dot secret init` | 0.2.538 |
| `dot secrets` | `dot secret edit` | 0.2.538 |
| `dot secrets-create` | `dot secret new` | 0.2.538 |
| `dot ssh-key` | `dot secret key new` | 0.2.538 |
| `dot ssh-cert` | `dot secret cert new` | 0.2.538 |
| `dot secret-audit` | `dot secret check` | 0.2.538 |
| `dot policy` | `dot security policy` | 0.2.538 |
| `dot encrypt-check` | `dot security disk` | 0.2.538 |
| `dot firewall` | `dot security firewall apply` | 0.2.538 |
| `dot telemetry` | `dot security telemetry apply` | 0.2.538 |
| `dot dns-doh` | `dot security dns apply` | 0.2.538 |
| `dot lock-screen` | `dot security lock apply` | 0.2.538 |
| `dot usb-safety` | `dot security usb apply` | 0.2.538 |
| `dot security-score` | `dot security score` | 0.2.538 |
| `dot history` | `dot shell history` | 0.2.538 |
| `dot aliases` | `dot shell alias` | 0.2.538 |
| `dot alias-check` | `dot shell alias check` | 0.2.538 |
| `dot cache-refresh` | `dot shell update` | 0.2.538 |
| `dot prewarm` | `dot shell update --prewarm` | 0.2.538 |
| `dot clean-cache` | `dot shell clean` | 0.2.538 |
| `dot upgrade` | `dot system update` | 0.2.538 |
| `dot tune` | `dot system settings apply` | 0.2.538 |
| `dot log-rotate` | `dot system clean --logs` | 0.2.538 |
| `dot wallpaper` | `dot theme wallpaper set` | 0.2.538 |
| `dot fonts` | `dot theme font install` | 0.2.538 |
| `dot env` | `dot tool` | 0.2.538 |
| `dot tools` | `dot tool list --nix` | 0.2.538 |
| `dot packages` | `dot tool list --packages` | 0.2.538 |
| `dot locks` | `dot tool list --locked` | 0.2.538 |
| `dot new` | `dot tool new` | 0.2.538 |
| `dot intelligence` | `dot top` | 0.2.538 |
