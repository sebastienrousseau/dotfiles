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

### `dot learn`

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

### `dot upgrade`

Update tools, plugins, and dotfiles.

```
dot upgrade [--tools-only] [--dotfiles-only]
```

Runs `topgrade`-style upgrade of Mise tools, Nix flakes, homebrew (macOS), and pulls the latest `.dotfiles`.

### `dot commit`

Create an AI-assisted conventional commit from staged changes.

```
dot commit
```

Uses the configured AI provider (via `dot mode`) to generate a commit message matching the Conventional Commits spec.

### `dot search <term>`

Find commands by keyword.

```
dot search theme      # lists all theme-related commands
dot search secret     # lists all secret-related commands
```

## Inspect & Repair

### `dot heal`

Auto-repair missing tools, chezmoi drift, broken symlinks, and critical files.

```
dot heal [--dry-run|-n] [--force|-f] [--tool <name>]
```

See [Self-Healing concept](../01-concepts/05-self-healing.md).

### `dot rollback`

Return to a previous snapshot.

```
dot rollback              # restore most recent snapshot
dot rollback status       # list snapshots
dot rollback restore <n>  # restore snapshot #n
dot rollback clean        # delete snapshots older than 30 days
```

### `dot chaos`

Simulate corruption to test self-healing. **Destructive.** Use only in ephemeral environments.

```
dot chaos [symlink|config|tool|permission|all]
```

### `dot attest`

Export signed workstation evidence (see [Trust Model](../01-concepts/02-trust-model.md)).

```
dot attest [--output|-o <file>] [--sign|-s]
```

Default output: `~/.local/state/dotfiles/attestation/YYYY-MM-DD-HHMMSS.json`. With `--sign`, the JSON is signed with the user's SSH ED25519 key.

### `dot verify`

Verify integrity of the installation.

```
dot verify [--security|-s] [--attestation <path>]
```

| Flag | Effect |
|:---|:---|
| `--security`, `-s` | Run gitleaks + signature checks + policy hash |
| `--attestation <path>` | Verify an external attestation file |

### `dot lint`

Lint shell scripts (shellcheck, shfmt).

```
dot lint [--path <glob>] [--strict]
```

## Performance

### `dot benchmark`

Measure shell startup time.

```
dot benchmark [--detailed|-d] [--profile|-p] [--compare|-c] [--waterfall|-w] [--runs|-r <n>]
```

| Flag | Effect |
|:---|:---|
| `--detailed`, `-d` | Per-module timing breakdown |
| `--profile`, `-p` | Profile with `$SHELL -ixc ""` |
| `--compare`, `-c` | Compare against baseline |
| `--waterfall`, `-w` | Waterfall visualization |
| `--runs`, `-r <n>` | Number of hyperfine runs (default 10) |

Exit codes: 0 (<500ms target), 1 (regression).

### `dot perf`

Quick performance snapshot.

```
dot perf [--json|-j] [--profile|-p] [--runs|-r <n>] [--target|-t <ms>]
```

### `dot prewarm`

Regenerate shell init caches for fast startup.

### `dot cache-refresh`

Rebuild generated shell state (cold-start alternative to prewarm).

### `dot clean-cache`

Clear generated shell initialization caches. Next shell startup will be slow; use `dot prewarm` afterward.

### `dot score`

Show system health + security score.

### `dot metrics`

Show recent observability metrics (startup times, heal events, score history).

### `dot load-bench`

Measure heavy-layer (nvm, rbenv, direnv) readiness time.

## AI & Agents

### `dot ai`

Show installed AI tools with versions and status.

```
dot ai
```

### `dot mcp`

Inspect MCP policy and registry.

```
dot mcp [--strict|-s] [--json|-j]
```

With `--strict`, validates the active MCP registry matches the policy hash. Exit code 1 on mismatch.

### `dot mode [<profile>]`

Show or set the agent profile.

```
dot mode              # show current profile
dot mode architect    # switch to architect profile
dot mode list         # list all profiles
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

### `dot env`

Show managed tool versions.

```
dot env               # all managed tools
dot env <tool>        # single tool
```

### `dot profile [<name>]`

Show or switch the active profile.

```
dot profile           # show active profile
dot profile list      # all profiles
dot profile laptop    # switch to 'laptop' profile
```

Profiles live in `.chezmoidata.toml` under `[profiles.<name>]`.

### `dot secrets`

Edit or manage encrypted secrets.

```
dot secrets list              # all encrypted files
dot secrets edit <path>       # open in $EDITOR (decrypted)
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
dot fleet sync         # run `dot update` on every host
```

Fleet hosts are configured in `~/.config/dotfiles/fleet.toml`.

## Reference

### `dot version`

Show the installed version.

```
dot version [--json]
```

### `dot manual`

Open or download the manual in multiple formats.

```
dot manual            # open latest HTML manual in browser
dot manual pdf        # download + open PDF
dot manual text       # pipe ASCII text to pager
dot manual download <format>  # save to current directory
dot manual --offline  # use bundled offline copy (from `dot bundle`)
```

Formats: `html`, `html-multi`, `pdf`, `epub`, `text`, `markdown`.

### `dot add <path>`

Import a file into chezmoi's source directory.

```
dot add ~/.somefile                    # plaintext
dot add --encrypt ~/.somefile          # encrypted with Age
dot add --template ~/.somefile         # templatize
```

### `dot remove <path>`

Safely remove a managed file (removes from source and unmanages).

### `dot cd`

Print the source directory path. Useful for `cd $(dot cd)`.

### `dot bundle`

Create an offline portable archive.

```
dot bundle                        # default output ~/Downloads/
dot bundle --to <dir|file>        # custom location
dot bundle --manual               # include offline manual
dot bundle restore <bundle.tar.zst>  # restore from bundle
```

### `dot packages`

Show installed packages and package managers.

```
dot packages
dot packages --manager mise|nix|brew|apt
```

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
