---
render_with_liquid: false
---

# Reference: The `dot` CLI

Complete command reference. Every subcommand, every flag, every exit code.

## Invocation

```
dot [<command>] [<subcommand>] [<flags>] [<args>]
```

With no arguments, `dot` prints the overview (same as `dot help`).

## Global Flags

| Flag | Purpose |
|:---|:---|
| `-h`, `--help` | Show help for the command (or overview if no command given) |
| `-v`, `--verbose` | Verbose output |
| `--version` | Print the dotfiles version and exit |
| `--json` | Machine-readable JSON output (where supported) |

## Start Here

### `dot sync` / `dot apply`

Apply the tracked configuration to the machine. Aliases: `dot sync == dot apply`.

```
dot sync [--dry-run|-n] [--force|-f] [--verbose|-v]
```

| Flag | Effect |
|:---|:---|
| `--dry-run`, `-n` | Preview changes without applying |
| `--force`, `-f` | Skip confirmation prompts |
| `--verbose`, `-v` | Show per-file actions |

Exit codes: 0 (clean apply), 1 (drift reconciled), 2 (apply failed).

### `dot doctor`

Check the environment and surface issues.

```
dot doctor [--score|-s] [--heal|-H] [--json|-j] [--verbose|-v]
```

| Flag | Effect |
|:---|:---|
| `--score`, `-s` | Print numeric score (0-100) only |
| `--heal`, `-H` | Auto-fix detected issues |
| `--json`, `-j` | Machine-readable output |
| `--verbose`, `-v` | Show every check (default: failures only) |

Exit codes: 0 (healthy), 1 (warnings), 2 (critical failures).

### `dot help tour`

Interactive guided tour of the environment. Takes ~5-10 minutes, covers shells, secrets, themes, performance, security. Press `q` to exit at any time.

### `dot help [<command>]`

Show the overview (no arg) or detailed help for a specific command.

## Daily Use

### `dot status` / `dot diff`

Show local drift or preview pending changes.

```
dot status            # list changed managed files
dot diff [<path>]     # show unified diff (all or one path)
```

### `dot edit`

Open the source directory in `$EDITOR`. Shorthand for `cd ~/.dotfiles && $EDITOR`.

### `dot system update`

Update the dotfiles, your mise tools and, if you agree, your system packages.

```
dot system update [--yes]
```

Every question is asked before anything runs:

1. If mise is missing, `dot system update` offers to install it (through Homebrew
   when present, otherwise the pinned mise release, verified against its
   published checksums, into `~/.local/bin`).
2. If a system package manager is found (Homebrew, apt, dnf or pacman), it
   asks whether to upgrade system packages too. apt, dnf and pacman ask for
   your sudo password once, up front. Homebrew asks only when an outdated
   cask may need it (a cask installed from a `.pkg`); with no terminal to
   ask, it names those casks and upgrades everything else.

Then it runs, as tracked steps: the Nix flake update and garbage collection
(when a flake is present), `chezmoi update` (pull and apply the dotfiles),
`mise install` and `mise upgrade` (plus `mise self-update` for a mise that
`dot` installed), the Neovim plugin sync, and the system-package upgrade you
agreed to. A step that cannot run is shown as skipped with the reason.

The answer to every question is **no** unless you say yes. `--yes` (or
`DOTFILES_YES=1`) answers yes to all of them; with no terminal to ask (a pipe,
cron, CI) and no `--yes`, `dot system update` installs nothing extra and says so.

### `dot config save`

Create an AI-assisted conventional commit from staged changes.

```
dot config save
```

Uses the configured AI provider (via `dot agent mode`) to generate a commit message matching the Conventional Commits spec.

### `dot help <term>`

Find commands by keyword.

```
dot help theme      # lists all theme-related commands
dot help secret     # lists all secret-related commands
```

## Inspect & Repair

### `dot doctor fix`

Auto-repair missing tools, chezmoi drift, broken symlinks, and critical files.

```
dot doctor fix [--dry-run|-n] [--force|-f] [--tool <name>]
```

See [Self-Healing concept](../01-concepts/05-self-healing.md).

### `dot doctor rollback`

Return to a previous snapshot.

```
dot doctor rollback              # restore most recent snapshot
dot doctor rollback status       # list snapshots
dot doctor rollback restore <n>  # restore snapshot #n
dot doctor rollback clean        # delete snapshots older than 30 days
```

### Chaos test

Simulate corruption to test self-healing. **Destructive.** Use only in ephemeral environments. It is a test, not a `dot` command (`dot chaos` stops working in 0.2.538):

```
bash scripts/ops/chaos.sh [symlink|config|tool|permission|all]
```

### `dot attest`

Export signed workstation evidence (see [Trust Model](../01-concepts/02-trust-model.md)).

```
dot attest [--output|-o <file>] [--sign|-s]
```

Default output: `~/.local/state/dotfiles/attestation/YYYY-MM-DD-HHMMSS.json`. With `--sign`, the JSON is signed with the user's SSH ED25519 key.

### `dot config check`

Lint shell scripts (shellcheck, shfmt).

```
dot config check [--path <glob>] [--strict]
```

## Performance

### `dot doctor perf show`

Quick performance snapshot.

```
dot doctor perf show [--json|-j] [--profile|-p] [--runs|-r <n>] [--target|-t <ms>]
```

### `dot shell update`

Regenerate shell caches for ultra-fast startup.

### `dot doctor score`

Show system health + security score.

### `dot doctor metric list`

Show recent observability metrics (startup times, heal events, score history).

### `dot doctor perf --ready`

Measure heavy-layer (nvm, rbenv, direnv) readiness time.

## AI & Agents

### `dot ai`

The cockpit for your AI-CLI fleet. Bare `dot ai` opens a Bubble Tea TUI;
a prompt runs a one-shot; `dot ai serve` serves your Claude subscription
locally to any Anthropic/OpenAI-protocol tool.

```
dot ai                      # open the cockpit (TUI)
dot ai "fix the auth bug"   # one-shot on Claude
dot ai codex "add tests"    # one-shot on a named tool
dot ai chat [tool]          # interactive session
dot ai tools                # install / manage the fleet
dot ai install [all|<tool>] # install fleet tools
dot ai serve [stop|status]  # local Claude gateway (start also routes the fleet)
dot ai cost                 # spend report
dot ai login [tool]         # authenticate
dot ai doctor               # health-check fleet + gateway
```

Add `--style <name>` (architect, hardener, refactor) to steer a prompt.
Old forms (`dot cl`, `dot ai dashboard`, `dot ai proxy`, `dot ai-setup`, …)
still work as deprecated aliases. See [AI.md](../../AI.md) for the full guide.

### `dot mcp`

Inspect MCP policy and registry, or run the MCP server.

```
dot mcp [--strict|-s] [--json|-j]   # audit (default: doctor)
dot mcp registry [--json|-j]        # show the tracked MCP server registry
dot mcp serve                       # run the stdio MCP server
```

With `--strict`, validates the active MCP registry matches the policy hash. Exit code 1 on mismatch.

#### `dot mcp serve`

Runs the Model Context Protocol server described by
`.well-known/mcp/server-card.json`: JSON-RPC 2.0 over newline-delimited
frames on stdin/stdout, with stderr reserved for logs. It is meant to be
launched by an MCP client, not typed at a prompt:

```json
{ "mcpServers": { "dotfiles": { "command": "dot", "args": ["mcp", "serve"] } } }
```

It serves four read-only tools — `mcp-doctor`, `agent-mode`,
`workstation-attestation` and `fleet-status`, each a fixed `dot` argument
vector run without a shell — and five resources (the MCP policy, the MCP
registry, the agent profiles and both discovery cards). Mutating paths
(`dot agent mode set`, `dot attest --write`) are deliberately not exposed: a
client cannot change this workstation through the server.

The binary is `~/.local/bin/dot-mcp`, built by chezmoi from
[`defaults/dot_local/share/dot-mcp`](../../../defaults/dot_local/share/dot-mcp/README.md);
when it is missing and a Go toolchain is present, `dot mcp serve` builds
it on demand into the user cache.

### `dot agent mode [<profile>]`

Show or set the agent profile.

```
dot agent status            # show current profile
dot agent mode set architect    # switch to architect profile
dot agent mode list         # list all profiles
```

Available profiles (see `dot_config/ai/patterns/`): `architect`, `hardener`, `refactor`. Custom profiles can be added by dropping `<name>.md` in the patterns directory.

### `dot agent`

Agent metadata, logs, checkpoints, and conformance reports.

```
dot agent status              # current agent state
dot agent logs [--since <t>]  # recent agent invocations
dot agent conformance         # MCP policy conformance report
```

## Configuration

### `dot theme`

Switch terminal and desktop themes. See [Theme Engine](../01-concepts/03-theme-engine.md) and [Theming Guide](../../guides/THEMING.md).

```
dot theme              # interactive picker
dot theme <name>       # switch directly (e.g. dot theme tahoe-dark)
dot theme toggle       # swap dark↔light within family
dot theme list         # show paired themes with System/Custom source
dot theme rebuild [--force|--list]  # regenerate from wallpapers
```

### `dot tool`

Show managed tool versions.

```
dot tool               # all managed tools
dot tool <tool>        # single tool
```

### `dot config profile [<name>]`

Show or switch the active profile.

```
dot config profile           # show active profile
dot config profile show      # all profiles
dot config profile set laptop    # switch to 'laptop' profile
```

Profiles live in `.chezmoidata.toml` under `[profiles.<name>]`.

### `dot secret`

Edit or manage encrypted secrets.

```
dot secret list              # all encrypted files
dot secret edit <path>       # open in $EDITOR (decrypted)
dot secrets rotate            # re-encrypt with current recipients
dot secrets verify            # integrity check (no decryption)
```

## Fleet

### `dot fleet`

Multi-node status, drift, and namespace.

```
dot fleet              # show all known hosts
dot fleet attest       # collect signed attestations
dot fleet diff         # compare rendered config across hosts
dot fleet sync         # run `dot system update` on every host
dot fleet apply        # SSH out to every host in fleet.toml and run 'dot sync'
```

Fleet hosts are configured in `~/.config/dotfiles/fleet.toml`.

### `dot fleet apply`

Push dotfiles state to every host registered in `~/.config/dotfiles/fleet.toml`.

```
dot fleet apply [--host <name>] [--cmd <shell>] [--dry-run] [--jobs <n>]
```

| Flag | Effect |
|:---|:---|
| `--host <name>` | Apply to a single host only (matches the `[hosts.<name>]` stanza key). |
| `--cmd <shell>` | Run a custom command on every host instead of the default `dot sync && dot doctor --quiet`. **Warning:** this is arbitrary shell on remote hosts; the value is your trust boundary. |
| `--dry-run`, `-n` | Print the resolved hosts + planned command without opening SSH. |
| `--jobs <n>` | Parallelism (default 4). |

Hostnames in `fleet.toml` are validated against `[A-Za-z0-9._@:+/-]+` before fan-out; entries containing other characters abort the apply. First-time SSH connections use `StrictHostKeyChecking=accept-new` (TOFU); pre-populate `~/.ssh/known_hosts` if your threat model requires no TOFU window.

Example `fleet.toml`:

```toml
[hosts.laptop]
ssh     = "user@laptop.local"
profile = "workstation"
```

## Agents

### `dot agent context`

Multi-harness AI agent configuration manager. `CLAUDE.md` is canonical; `dot agent context apply` keeps `AGENTS.md` (the cross-harness standard read by Codex / Copilot / Cursor / Windsurf / Amp / Devin) plus `.cursor/rules/dotfiles.mdc` and `.codex/config.toml` in sync.

```
dot agent context show       # show which harnesses are recognised + their target paths
dot agent context check      # exit 0 if AGENTS.md tracks CLAUDE.md; 1 if drifted
dot agent context apply     # regenerate AGENTS.md + 10 harness-specific files
```

Harnesses covered: `AGENTS.md` (canonical cross-harness), Cursor (`.cursor/rules/dotfiles.mdc`), Codex (`.codex/config.toml`), Windsurf (`.windsurf/rules.md`), Zed (`.zed/agent-config.toml`), Roo (`.roo/rules.md`), Cline (`.clinerules`), Aider (`.aider.conf.yml`), Continue (`.continuerc.json`), Jules (`.jules/system.md`), Antigravity (`.agy/AGY.md`).

Edit `CLAUDE.md` first, then run `dot agent context apply`; do not hand-edit `AGENTS.md` or any of the per-harness files. The check subcommand is suitable for pre-commit hooks.

## Registry

### `dot cli`

JSON-indexed module registry. Discover and install reusable dotfile modules from a registry hosted via GitHub Pages (or any HTTPS URL via `set-url`).

```
dot cli list --available                 # list modules in the configured registry
dot cli list --available <query>       # filter modules by keyword
dot cli show <name>          # full metadata for one module
dot cli install <name>       # apply a module (scaffold today)
dot cli registry show                  # show the active registry URL
dot cli registry set <url>        # override the registry URL (HTTPS-only)
```

Default registry: `https://doc.dotfiles.io/registry.json`. Cache lives under `${XDG_CACHE_HOME:-~/.cache}/dotfiles/registry/`, one `index-<digest>.json` per registry URL, with a 6h TTL. One-off override: `DOTFILES_REGISTRY_URL=<url> dot cli list --available`.

The JSON contract + module-contribution flow live in [`docs/operations/REGISTRY.md`](../../operations/REGISTRY.md).

## Reference

### `dot version`

Show the installed version.

```
dot version [--json]
```

### `dot help --manual`

Open or download the manual in multiple formats.

```
dot help --manual            # open latest HTML manual in browser
dot help --manual pdf        # download + open PDF
dot help --manual text       # pipe ASCII text to pager
dot help --manual download <format>  # save to current directory
dot help --manual --offline  # use bundled offline copy (from `dot config export`)
```

Formats: `html`, `html-multi`, `pdf`, `epub`, `text`, `markdown`.

### `dot config add <path>`

Import a file into chezmoi's source directory.

```
dot config add ~/.somefile                    # plaintext
dot config add --encrypt ~/.somefile          # encrypted with Age
dot config add --template ~/.somefile         # templatize
```

### `dot cd`

Print the source directory path. Useful for `cd $(dot cd)`.

### `dot config export`

Create an offline portable archive.

```
dot config export                        # default output ~/Downloads/
dot config export --to <dir|file>        # custom location
dot config export --manual               # include offline manual
dot config import <bundle.tar.zst>  # restore from bundle
```

### `dot tool list --packages`

Show installed packages and package managers.

```
dot tool list --packages
dot tool list --packages --manager mise|nix|brew|apt
```

Each query has a time limit (`DOTFILES_PACKAGES_TIMEOUT`, 10 seconds by
default). A package manager that does not answer in time shows `timed out`
and the rest are still listed.

## Environment Variables

| Variable | Purpose |
|:---|:---|
| `DOTFILES_VERBOSE=1` | Verbose output for all `dot` commands |
| `DOTFILES_NONINTERACTIVE=1` | Skip interactive prompts |
| `DOTFILES_SILENT=1` | Suppress non-error output |
| `DOTFILES_SOURCE_DIR` | Override the source directory |
| `DOTFILES_WALLPAPER_DIR` | Override `~/Pictures/Wallpapers/` |
| `DOTFILES_DEBUG=1` | Print timing info during shell init |

## Exit Codes

| Code | Meaning |
|:---|:---|
| 0 | Success |
| 1 | Warnings or recoverable errors |
| 2 | Critical failure — manual intervention required |
| 127 | Command not found |

## See Also

- [Configuration Files Reference](02-config-files.md)
- [Environment Reference](03-environment.md)
- [Template Variables](04-templates.md)
- [Feature Flags](05-feature-flags.md)
