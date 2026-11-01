---
render_with_liquid: false
---

# Reference: The `dot` CLI

Command reference for the common `dot` commands, their flags and their exit codes. The complete, current list is always `dot help all`; `dot help --json` prints the same catalog as JSON, and `dot <domain> <verb> --help` shows one command's effect and declared flags.

## Invocation

```
dot <domain> [object] <verb> [args]
```

With no arguments, `dot` prints the overview (same as `dot help`). A domain on its own (`dot doctor`, `dot fleet`) runs that domain's default; `dot help <domain>` lists its commands.

## Global Flags

| Flag | Purpose |
|:---|:---|
| `-h`, `--help` | Show help for the command (or the overview if no command is given) |
| `-V`, `--version` | Print the dotfiles version and source directory, then exit (same as `dot version`) |

There is no global `--json` or `--verbose`: JSON output is a per-command flag (`dot doctor check --json`, `dot mcp check --json`, `dot attest show --json`), listed by that command's `--help`.

## Start Here

### `dot sync` / `dot apply`

Apply the tracked configuration to the machine. `dot apply` is short for `dot config apply`, and `dot sync` for `dot config sync`.

```
dot apply [<chezmoi apply flags>]
dot sync [--pull|--check] [<chezmoi apply flags>]
```

| Form | Effect |
|:---|:---|
| `dot apply` | Run `chezmoi apply` with the repo's diagnostics, then the post-apply repairs and cache prewarm |
| `dot sync` | Same as `dot apply` |
| `dot sync --pull` | Pull the source first, then apply (same as `dot config update`) |
| `dot sync --check` | Preview only (same as `dot diff`) |

Other arguments go to `chezmoi apply`, so `--dry-run`/`-n` and `--verbose`/`-v` are chezmoi's own flags. Apply runs unattended (`--force`) by default; set `DOTFILES_INTERACTIVE_APPLY=1` to get chezmoi's overwrite prompts back.

Exit codes: 0 (applied, or another apply was already running), 1 (`chezmoi apply` failed).

### `dot doctor`

Check the environment and surface issues. Bare `dot doctor` runs the full check, the same as `dot doctor check`.

```
dot doctor check [--heal|-H] [--score|-s] [--json|-j] [--ai|-A]
dot doctor status [--json|-j] [--fix|-f] [--force|-F]
```

| Flag | Effect |
|:---|:---|
| `--heal`, `-H` | Run the repair instead of the check (same as `dot doctor fix`) |
| `--score`, `-s` | Show the scorecard (same as `dot doctor score show`) |
| `--json`, `-j` | Print a JSON summary |
| `--ai`, `-A` | Include AI diagnostics |

`dot doctor status` is the shorter health dashboard; its `--fix` and `--force` apply common fixes.

Exit codes for `dot doctor check`: 0 (healthy, warnings included), 1 (one or more errors).

### `dot help tour`

Interactive guided tour (built on `gum`) of the shell, diagnostics, secrets, security, themes, projects and linting.

### `dot help [<command>]`

Show the overview (no arg) or detailed help for a specific command.

## Daily Use

### `dot status` / `dot diff`

Show local drift or preview pending changes (`dot config status`, `dot config diff`).

```
dot status            # list changed managed files
dot diff [<path>]     # show unified diff (all or one path)
```

### `dot edit`

Open the source directory in `$EDITOR` (falling back to `nvim`, then `vim`). Short for `dot config edit`.

### `dot system update`

Update the dotfiles, your mise tools and, if you agree, your system packages.

```
dot system update [--yes] [--globals]
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
`--globals` also updates npm, cargo and pipx globals.

### `dot config update`

Pull the source and apply the dotfiles only, without the tool and package steps of `dot system update`.

### `dot config save`

Create an AI-assisted conventional commit from staged changes.

```
dot config save [--provider|-p <name>] [--edit|-e]
```

Runs `git-ai-commit`, which picks the first available AI CLI (claude, agy, sgpt, aider or ollama) unless `--provider` or `GIT_AI_PROVIDER` names one.

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
dot doctor fix [--dry-run|-n] [--force|-f]
```

`DOTFILES_NONINTERACTIVE=1` skips the prompts, like `--force`. Exit codes: 0 (nothing to repair, or every attempted repair worked), 1 (a repair failed: an install, `chezmoi apply`, or removing a broken symlink). See [Self-Healing concept](../01-concepts/05-self-healing.md).

### `dot doctor rollback`

Back up and restore the managed dotfiles. Backups live in `~/.local/share/dotfiles/backups/`; `clean` keeps the newest 10.

```
dot doctor rollback                    # same as 'status'
dot doctor rollback status             # current state and numbered backups
dot doctor rollback backup             # take a backup now
dot doctor rollback rollback           # restore the most recent backup
dot doctor rollback rollback-to <n>    # restore backup #n from the status list
dot doctor rollback restore <file>     # restore one file from the latest backup
dot doctor rollback git-reset          # reset the source to the last tag
dot doctor rollback clean              # delete all but the newest 10 backups
```

Options (anywhere on the line): `--force`/`-f` skips confirmation, `--dry-run`/`-n` previews, `--verbose`/`-v`. Exit code 75 means another rollback held the lock and nothing ran.

`dot doctor backup` is different: it archives the home directory to a `.tgz` under `~/.backups` (`DOTFILES_BACKUP_DIR` overrides). `dot doctor restore` restores from those archives (`--list`, `--latest`, `--git <ref>`, `--diff <ref>`, `--dry-run`).

### Chaos test

Simulate corruption to test self-healing. **Destructive.** Use only in ephemeral environments. It is a script, not a `dot` command (`dot chaos` exits 127 from 0.2.538):

```
bash scripts/ops/chaos.sh --force
```

Without `--force` it only prints a warning. With it, it deletes `~/.config/starship.toml`, `~/.zshrc` and `~/.config/alacritty/alacritty.toml`, creates a broken symlink at `~/.config/broken_symlink_test`, and points `PATH` at `/bin` for that process. Recover with `dot doctor fix`.

### `dot attest`

Workstation attestation: an unsigned JSON record of the dotfiles version, platform, signing setup, MCP posture and agent mode (see [Trust Model](../01-concepts/02-trust-model.md)).

```
dot attest show [--json|-j]                  # print it; without --json also write the default file
dot attest export [<file>] [flags]           # write it to <file>, or to the default file
dot attest verify [<file>] [--json|-j] [--max-age|-a <secs>]  # verify <file>, or a fresh record
```

Bare `dot attest` is `dot attest show`. Default file: `~/.local/state/dotfiles/attestations/workstation-attestation.json`. `dot attest show --fleet-store|-F <dir>` (or `DOTFILES_FLEET_STORE`) also writes the record to `<dir>/<fleet-id>/<hostname>/`, with `--fleet-id|-I <id>` (default `default`). `dot attest export` takes the same flags after the optional file (`dot attest export --fleet-store <dir>` writes the default file and the store). A missing option value, an unknown option or a stray word exits 2.

### `dot config check`

Lint the shell scripts in the source (shellcheck, then `shfmt -i 2 -ci`).

```
dot config check [--check|-c | --fix|-f]
```

`--fix` rewrites the files shfmt would reformat.

## Performance

### `dot doctor perf show`

Quick performance snapshot.

```
dot doctor perf show [--json|-j] [--profile|-p] [--runs|-r <n>] [--target|-t <ms>]
```

### `dot shell update`

Regenerate shell caches for faster startup.

### `dot doctor score show`

Show the scorecard: health, security and performance scores out of 100, plus the count of drifted files. It exits 1 when any score has warnings.

### `dot doctor metric list`

Show recent observability metrics from `~/.local/state/dotfiles/metrics.jsonl` (default 20 lines; `dot doctor metric list <n>` for more).

### `dot doctor perf --ready`

Measure heavy-layer (nvm, rbenv, direnv) readiness time.

## AI & Agents

### `dot ai`

The cockpit for your AI-CLI fleet. Bare `dot ai` opens a Bubble Tea TUI;
`dot ai run` runs a one-shot; `dot ai gateway serve` serves your Claude
subscription locally to any Anthropic/OpenAI-protocol tool.

```
dot ai                               # open the cockpit (TUI)
dot ai run "fix the auth bug"        # one-shot on Claude
dot ai run codex "add tests"         # one-shot on a named tool
dot ai start [tool]                  # interactive session
dot ai list                          # installed agents
dot ai install [all|<tool>]          # install fleet tools
dot ai gateway serve [stop|status|logs|setup]  # local Claude gateway (start also routes the fleet)
dot ai cost show                     # spend report
dot ai login [tool]                  # authenticate
dot ai check                         # health-check fleet + gateway
```

Add `--style <name>` (architect, hardener, refactor) to `dot ai run` to steer a prompt.
The top-level forms (`dot cl`, `dot claude`, `dot ai-setup`, `dot ai-query`) were removed in 0.2.538 and exit 127. A few old `dot ai` verbs (`dot ai dashboard`, `dot ai proxy`) still run with a deprecation notice. See [AI.md](../../AI.md) for the full guide.

### `dot mcp`

Inspect MCP policy and registry, or run the MCP server.

```
dot mcp check [--strict|-s] [--json|-j]   # audit (bare 'dot mcp' does the same)
dot mcp list                              # show the tracked MCP server registry
dot mcp serve                             # run the stdio MCP server
```

With `--strict`, policy warnings count as errors. Exit code 1 when errors are found.

#### `dot mcp serve`

Runs the Model Context Protocol server described by
`.well-known/mcp/server-card.json`: JSON-RPC 2.0 over newline-delimited
frames on stdin/stdout, with stderr reserved for logs. It is meant to be
launched by an MCP client, not typed at a prompt:

```json
{ "mcpServers": { "dotfiles": { "command": "dot", "args": ["mcp", "serve"] } } }
```

It serves four read-only tools (`mcp-doctor`, `agent-mode`,
`workstation-attestation` and `fleet-status`, each a fixed `dot` argument
vector run without a shell) and five resources (the MCP policy, the MCP
registry, the agent profiles and both discovery cards). Mutating paths
(`dot agent mode set`, `dot attest export`) are deliberately not exposed: a
client cannot change this workstation through the server.

The binary is `~/.local/bin/dot-mcp`, built by chezmoi from
[`defaults/dot_local/share/dot-mcp`](../../../defaults/dot_local/share/dot-mcp/README.md);
when it is missing and a Go toolchain is present, `dot mcp serve` builds
it on demand into the user cache.

### `dot agent mode`

Show or set the agent mode.

```
dot agent status            # current mode and its approval, filesystem, network and MCP settings
dot agent mode list         # list all modes
dot agent mode show <mode>  # one mode in detail
dot agent mode set plan     # switch to the plan mode
```

The modes are `ask` (the default), `plan`, `apply` and `audit`, defined in `defaults/dot_config/dotfiles/agent-profiles.json`. They are separate from the `dot ai run --style` prompt patterns (`architect`, `hardener`, `refactor`) in `defaults/dot_config/ai/patterns/`.

### `dot agent`

Agent metadata, logs, checkpoints, and conformance reports.

```
dot agent status              # current agent state
dot agent log show [<n>]      # last n agent log entries (default 20)
dot agent checkpoint list     # saved checkpoints
dot agent card show           # the agent card
dot agent card check          # check the agent card against the A2A spec
```

## Configuration

### `dot theme`

Switch terminal and desktop themes. See [Theme Engine](../01-concepts/03-theme-engine.md) and [Theming Guide](../../guides/THEMING.md).

```
dot theme              # interactive picker
dot theme show         # current theme and palette
dot theme set <name>   # switch directly (e.g. dot theme set tahoe-dark)
dot theme toggle       # swap dark and light within the family
dot theme list         # show themes with their System/Custom source
dot theme rebuild [--force|--list]  # regenerate from wallpapers
```

`toggle` and `rebuild` are older verbs of the theme script that `dot theme` still passes through; they are not in `dot help theme`.

### `dot tool`

Show and manage the mise-managed toolchains.

```
dot tool list              # every tool, version and the config file that pins it
dot tool set <tool@version>   # pin a version
dot tool install           # install the configured toolchains
dot tool update            # upgrade toolchains
```

### `dot config profile`

Show or switch the active profile.

```
dot config profile show          # active profile and the [features] flags
dot config profile set laptop    # switch to 'laptop'
```

The profile is the `profile` key in `[data]` of `~/.config/chezmoi/chezmoi.toml` (this host), else in `defaults/.chezmoidata.toml` (the source default); `set` writes this host's value, then `dot apply` renders it. There is no `[profiles.<name>]` table: a profile is a name that templates read as `.profile`.

### `dot secret`

Manage the age-encrypted secrets file (`~/.config/chezmoi/encrypted_secrets.age`).

```
dot secret list              # secret names, without values
dot secret show <KEY>        # one secret
dot secret set <KEY> <VALUE> # store one secret
dot secret edit              # open the encrypted secrets file in $EDITOR (via chezmoi edit)
dot secret check             # audit secret hygiene
```

`dot secret edit` needs the age key at `~/.config/chezmoi/key.txt` (run `dot secret init` first).

## Fleet

### `dot fleet`

Multi-node status, drift, and namespace.

```
dot fleet status [--json]   # this node's fleet status (bare 'dot fleet' does the same)
dot fleet drift show        # check for configuration drift
dot fleet log show          # recent fleet events
dot fleet namespace list    # the active namespace
dot fleet push [user@host]  # push to one host, or to every host like 'apply'
dot fleet apply             # SSH out to every host in fleet.toml: pull, apply, check
```

Fleet hosts are configured in `~/.config/dotfiles/fleet.toml` (`DOTFILES_FLEET_HOSTS` overrides the path). To collect attestations into a shared store, run `dot attest show --fleet-store <dir>` on each host.

### `dot fleet apply`

Push dotfiles state to every host registered in `~/.config/dotfiles/fleet.toml`.

```
dot fleet apply [--host <name>] [--cmd <shell>] [--dry-run] [--jobs <n>] [--verify-hosts]
```

| Flag | Effect |
|:---|:---|
| `--host <name>` | Apply to a single host only (matches the `[hosts.<name>]` stanza key). |
| `--cmd <shell>` | Run a custom command on every host instead of the default `dot config update && dot doctor`. **Warning:** this is arbitrary shell on remote hosts; the value is your trust boundary. |
| `--dry-run`, `-n` | Print the resolved hosts + planned command without opening SSH. |
| `--jobs <n>`, `-j <n>` | Parallelism (default 4). |
| `--verify-hosts` | Refuse to connect unless every target host already has a key in `~/.ssh/known_hosts`. |

Hostnames in `fleet.toml` are validated against `[A-Za-z0-9._@:+/-]+` before fan-out; entries containing other characters abort the apply. First-time SSH connections use `StrictHostKeyChecking=accept-new` (TOFU); pass `--verify-hosts`, or pre-populate `~/.ssh/known_hosts`, if your threat model requires no TOFU window.

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

JSON-indexed module registry. Discover and install reusable dotfile modules from a registry hosted via GitHub Pages (or any HTTPS URL via `dot cli registry set`).

```
dot cli list --available               # list modules in the configured registry
dot cli list --available <query>       # filter modules by keyword
dot cli show <name>                    # full metadata for one module
dot cli install <name> [--yes]         # verify and preview a module; --yes applies it
dot cli registry show                  # show the active registry URL
dot cli registry set <url>             # override the registry URL (HTTPS-only)
```

Default registry: `https://doc.dotfiles.io/registry.json`. Cache lives under `${XDG_CACHE_HOME:-~/.cache}/dotfiles/registry/`, one `index-v2-<digest>.json` per registry URL, with a 6h TTL. One-off override: `DOTFILES_REGISTRY_URL=<url> dot cli list --available`.

The JSON contract + module-contribution flow live in [`docs/operations/REGISTRY.md`](../../operations/REGISTRY.md).

## Reference

### `dot version`

Show the installed version and the source directory.

```
dot version
```

### `dot help --manual`

Open or download the manual in multiple formats.

```
dot help --manual                     # open the HTML manual in the browser
dot help --manual pdf                 # download + open PDF
dot help --manual text                # pipe ASCII text to pager
dot help --manual download <format>   # save to current directory
dot help --manual --offline           # use the copy in ~/.local/share/dotfiles/manual/
dot help --manual --local             # use a local build in _build/manual/
```

Formats: `html`, `html-multi`, `pdf`, `epub`, `text`, `markdown`. Downloads are cached in `~/.cache/dotfiles/manual/` and fetched again after 7 days.

### `dot config add <path>`

Import a file into chezmoi's source directory. Arguments go to `chezmoi add`.

```
dot config add ~/.somefile                    # plaintext
dot config add --encrypt ~/.somefile          # encrypted with Age
dot config add --template ~/.somefile         # templatize
```

### `dot cd`

Print the source directory path (short for `dot config path show`). Useful for `cd $(dot cd)`.

### `dot config export`

Create an offline portable archive.

```
dot config export            # writes ~/Downloads/dotfiles_offline_bundle_<timestamp>.tar.zst
dot config export <dir>      # writes the bundle into <dir>
```

The bundle holds `~/.dotfiles`, `~/.config/chezmoi` and `~/.local/share/mise` (plus the Nix store when `DOTFILES_BUNDLE_NIX=1`). It leaves out the age key (any file in `~/.config/chezmoi` with an `AGE-SECRET-KEY` line) and names it, for you to copy separately. It needs `tar` and `zstd`. To restore on another machine, unpack it with `tar --zstd -xf <bundle> -P`, then run `cd ~/.dotfiles && ./install.sh --force`.

`dot config import <bundle> [--yes|-y]` restores a bundle on a machine that already has `dot`: it names the paths it will overwrite and asks first (`--yes` skips the question, and without a terminal it restores nothing). It refuses a file that is not a `dot config export` bundle, or one holding anything outside the checkout (`$DOTFILES_DIR`, else `~/.dotfiles`), `~/.config/chezmoi` and `~/.local/share/mise` of the current home (so a bundle made under another home, or with the Nix store, is refused: unpack those with `tar`).

### `dot tool list --packages`

Show installed packages and package managers.

```
dot tool list --packages
```

Each query has a time limit (`DOTFILES_PACKAGES_TIMEOUT`, 10 seconds by
default). A package manager that does not answer in time shows `timed out`
and the rest are still listed.

## Environment Variables

| Variable | Purpose |
|:---|:---|
| `DOTFILES_NONINTERACTIVE=1` | Skip interactive prompts |
| `DOTFILES_YES=1` | Answer yes to `dot system update` and `dot ai install` questions |
| `DOTFILES_INTERACTIVE_APPLY=1` | Bring back chezmoi's overwrite prompts during `dot apply` |
| `DOTFILES_WALLPAPER_DIR` | Override `~/Pictures/Wallpapers/` |
| `DOTFILES_DEBUG=1` | Print timing info during zsh init |

See [Environment Reference](03-environment.md) for the full list.

## Exit Codes

| Code | Meaning |
|:---|:---|
| 0 | Success |
| 1 | The command ran and found errors or failed |
| 2 | Usage error (a missing option value or an unknown option, where the command checks) |
| 75 | `dot doctor rollback`: another instance held the lock, nothing ran |
| 127 | Unknown, removed or not-yet-built (planned) command |

## See Also

- [Configuration Files Reference](02-config-files.md)
- [Environment Reference](03-environment.md)
- [Template Variables](04-templates.md)
- [Feature Flags](05-feature-flags.md)
