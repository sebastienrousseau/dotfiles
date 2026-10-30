---
render_with_liquid: false
---

# Self-Healing

`.dotfiles` detects, diagnoses, and repairs configuration drift, missing tools, broken symlinks, and environmental damage — often without user intervention.

## The Self-Healing Loop

```
┌─────────────────────┐     ┌─────────────┐     ┌─────────────┐
│  dot doctor check   │ ──► │   detect    │ ──► │   report    │
└─────────────────────┘     └─────────────┘     └─────────────┘
                                   │
                                   ▼
┌─────────────────────┐     ┌─────────────┐     ┌─────────────┐
│   dot doctor fix    │ ──► │   repair    │ ──► │   verify    │
└─────────────────────┘     └─────────────┘     └─────────────┘
                                   │
                                   ▼ (on failure)
┌─────────────────────┐     ┌─────────────┐
│ dot doctor rollback │ ──► │   revert    │
└─────────────────────┘     └─────────────┘
```

## `dot doctor` — Detection

`dot doctor check` (or plain `dot doctor`) runs `scripts/diagnostics/doctor.sh`, which reports its checks in these sections, in order: Core Shells, Modern CLI Tools, Infrastructure, AI CLIs, Environment, Platform, State, Pre-Push Audit Bypass, Atuin History Filter, Git Signing, Update Tooling and Performance. `dot doctor status` is the shorter health dashboard.

Exit codes:

| Code | Meaning |
|:---|:---|
| 0 | No errors (there may be warnings) |
| 1 | At least one error |

Flags:

- `--score` / `-s`: run the scorecard instead (same as `dot doctor score show`)
- `--heal` / `-H`: run the repair instead (same as `dot doctor fix`)
- `--json` / `-j`: one JSON document instead of the text dashboard
- `--ai` / `-A`: when there are errors, ask an AI agent to suggest fixes

## `dot doctor fix` — Repair

`dot doctor fix` (`scripts/ops/heal.sh`) asks for confirmation, backs up the core dotfiles (see [`dot doctor rollback`](#rollback)), then addresses these failure modes:

### 1. Missing Tools

Installs any of a fixed list of tools that is not on PATH: zsh, starship, rg, bat, fzf, zoxide, atuin, yazi, zellij, nushell, pueue, wasmtime, sops, age and hyperfine. nushell, pueue, wasmtime, sops, yazi and zellij go through mise first; starship and atuin use their checksum-verified installers; the rest use the first package manager found (brew, apt, dnf, pacman, zypper, apk, pkg, then nix).

### 2. Chezmoi Drift

Runs `chezmoi apply --force` to reconcile local files back to the source state. Files changed only in the source tree are reported, not applied: commit or revert them in the source repo.

### 3. Broken Symlinks & Missing Files

Removes dangling symlinks (target doesn't exist) found up to three levels deep in `$HOME`. Missing critical files (`.zshrc`, `.bashrc`, `.profile`) are regenerated with `chezmoi apply --force`, and missing XDG config directories are created.

`dot doctor fix --dry-run` output on a drifted machine (the symlink paths replaced by placeholders):

```
== Checking dependencies ==
  ✓    All dependencies present
  ⚠    DRY-RUN                             Would: run 'chezmoi apply --force' to re-sync (25 file(s))
  ⚠    DRY-RUN                             Would: remove broken symlink: <link> -> <missing target>
  ✓ shell configs
  ✓ xdg directories

  Found 2 issue(s). Run without --dry-run to apply fixes.
```

### Flags

- `--dry-run` / `-n`: show what would be fixed, don't change anything
- `--force` / `-f`: skip the confirmation prompt (as does `DOTFILES_NONINTERACTIVE=1`)

### Exit Codes

`dot doctor fix` exits 0 whether or not every repair succeeded; read its summary line. It also exits 0 without doing anything when another instance holds its lock.

## Chaos self-test

The chaos test (`scripts/ops/chaos.sh`, run from the repository) intentionally corrupts the local installation to verify `dot doctor fix` can recover it. It is a test rather than a `dot` command (ADR-020; `dot chaos` exits 127 from 0.2.538). This is **destructive** — run only in ephemeral environments (containers, VMs, fresh installs).

The script takes one flag, `--force`; without it, it prints a warning and exits 1. With it, it:

| Step | What it breaks |
|:---|:---|
| Configuration deletion | Deletes `~/.config/starship.toml`, `~/.zshrc` and `~/.config/alacritty/alacritty.toml` |
| Symlink corruption | Creates the dangling link `~/.config/broken_symlink_test` |
| Path mutation | Sets `PATH=/bin` (inside the script's own process only) |

Typical workflow, in a disposable container or VM that already has the dotfiles installed:

```sh
dot doctor check                               # baseline
bash ~/.dotfiles/scripts/ops/chaos.sh --force  # break things
dot doctor fix                                 # repair
dot doctor check                               # verify
```

No CI workflow runs the chaos test; the unit test `tests/unit/ops/test_ops_chaos.sh` covers the script itself.

## Rollback

`dot doctor rollback` (`scripts/ops/rollback.sh`) works from backups in `~/.local/share/dotfiles/backups/backup_<YYYYMMDD_HHMMSS>_<reason>/`. `dot doctor fix` makes one before it repairs anything (`pre_heal`), a rollback makes one before it restores (`pre_rollback`), and you can make one by hand. `dot apply` does not.

```sh
dot doctor rollback                    # same as 'status'
dot doctor rollback status             # current state and numbered backups
dot doctor rollback backup             # back up now
dot doctor rollback rollback           # restore the most recent backup
dot doctor rollback rollback-to 3      # restore backup #3 from the status list
dot doctor rollback restore .bashrc    # restore one file from the latest backup
dot doctor rollback git-reset          # hard-reset the source to its last tag (HEAD~1 without one)
dot doctor rollback clean              # keep only the 10 newest backups
```

`git-reset` stashes uncommitted source changes first and keeps the old HEAD on a `rollback-backup/*` branch. `-f`/`--force` skips the prompts, `-n`/`--dry-run` shows what would happen and `-v`/`--verbose` lists each file.

A backup includes:

- `~/.bashrc`, `~/.zshrc`, `~/.zshenv`, `~/.profile`, `~/.inputrc`, `~/.vimrc` and `~/.gitconfig`
- `~/.config/shell`, `~/.config/nvim`, `~/.config/git`, `~/.config/tmux` and `~/.config/chezmoi`
- A `.backup_meta` file with the chezmoi version and the source's Git commit

It does **not** include:

- Any other managed file
- Generated caches (`~/.cache/`)
- Tool binaries (Mise-managed)
- External state (databases, remote repos)

`dot doctor snapshot new` is a different thing: it records the system and tooling state as JSON in `~/.local/state/dotfiles/snapshots/` (the first `dot apply` writes `baseline.json`), and nothing restores from it.

## `dot config export` — Offline Recovery

`dot config export [<dir>]` (`scripts/ops/bundle.sh`) writes a `tar --zstd` archive, `dotfiles_offline_bundle_<YYYYMMDD_HHMMSS>.tar.zst`, to `<dir>` (default `~/Downloads`). It needs `tar` and `zstd`, and stores these paths as absolute paths:

- `~/.dotfiles` (the source checkout)
- `~/.config/chezmoi` (your chezmoi config), without the age identity: any file there with an `AGE-SECRET-KEY` line is left out and named, for you to carry to the other machine separately
- `~/.local/share/mise` (installed toolchains)
- With `DOTFILES_BUNDLE_NIX=1`: `/nix/store`, `/nix/var/nix` and `~/.nix-profile`

Because the archive holds your age private key in the clear, treat it like the key itself.

Restore on the offline machine with the commands the export prints:

```sh
tar --zstd -xf dotfiles_offline_bundle_<stamp>.tar.zst -P
cd ~/.dotfiles && ./install.sh --force
```

On a machine that already has `dot`, `dot config import <bundle>` restores it: it lists what it will overwrite and asks first (`--yes` skips the question), and refuses a file that is not such a bundle or holds anything outside those three paths of your home.

## Observability

### Health Score

`dot doctor score show` reports three separate scores out of 100 (health, security and performance) plus the managed drift count, then a status line for each score (`--json` for machine output):

```
== Scores ==
  Health         93/100
  Security       92/100
  Performance    100/100 (avg 34ms, target 250ms)
  Drift          25 file(s)
  ⚠    Security                            Run 'dot security score show' to reach 100/100
  ✓    Performance                         100/100
  ⚠    Health                              Warnings detected (run 'dot doctor fix')
```

### Metrics

`dot doctor metric list [<n>]` prints the last `n` (default 20) lines of `~/.local/state/dotfiles/metrics.jsonl`, an append-only file with one JSON object per measurement. The recorded metrics are shell startup times, `chezmoi apply` duration, doctor error and warning counts, the scorecard scores and bundle size.

## Design Principles

1. **Idempotent** — running `dot apply` or `dot doctor fix` twice has the same effect as once
2. **Reversible**: `dot doctor fix` and a rollback back up the core dotfiles first; before a risky `dot apply`, run `dot doctor rollback backup` yourself
3. **Observable** — failures produce actionable error messages with exit codes
4. **Offline-capable**: detection and rollback work without network; `dot doctor fix` needs it only to install missing tools
5. **Minimally invasive** — repairs are scoped to the smallest unit that fixes the problem

## See Also

- [Reliability Operations](../../operations/RELIABILITY.md)
- [Tutorial: First Install](../02-tutorials/01-first-install.md)
- [Cookbook: Troubleshooting](../04-cookbook/02-troubleshooting.md)
