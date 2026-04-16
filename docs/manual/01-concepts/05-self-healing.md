# Self-Healing

`.dotfiles` detects, diagnoses, and repairs configuration drift, missing tools, broken symlinks, and environmental damage — often without user intervention.

## The Self-Healing Loop

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  dot doctor │ ──► │   detect    │ ──► │   report    │
└─────────────┘     └─────────────┘     └─────────────┘
                           │
                           ▼
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  dot heal   │ ──► │   repair    │ ──► │   verify    │
└─────────────┘     └─────────────┘     └─────────────┘
                           │
                           ▼ (on failure)
┌─────────────┐     ┌─────────────┐
│dot rollback │ ──► │   revert    │
└─────────────┘     └─────────────┘
```

## `dot doctor` — Detection

`dot doctor` runs ~40 health checks grouped into categories:

| Category | Checks |
|:---|:---|
| **Paths** | `~/.local/bin`, `~/.cargo/bin`, Mise shim order, Homebrew prefix |
| **Tools** | Required: git, chezmoi. Optional: mise, nix, age, sops, pandoc |
| **Chezmoi** | Source dir exists, data file valid, no uncommitted drift |
| **Shell** | Default shell matches profile, startup time <500ms |
| **Security** | SSH keys present, Age key present, gitleaks baseline |
| **Portability** | Git user.email set, LC_ALL sane, TERM recognized |

Exit codes:

| Code | Meaning |
|:---|:---|
| 0 | All checks passed |
| 1 | Warnings (non-blocking) |
| 2 | Critical failures (tool missing, config broken) |

Flags:

- `--score` / `-s` — numeric health score (0-100)
- `--heal` / `-H` — auto-fix detected issues (equivalent to `dot doctor && dot heal`)
- `--json` / `-j` — machine-readable output for CI/monitoring
- `--verbose` / `-v` — show every check (default shows only failures)

## `dot heal` — Repair

`dot heal` addresses three common failure modes:

### 1. Missing Tools

Reinstalls tools listed in `.chezmoidata.toml` that aren't on PATH:

```sh
dot heal
# [heal] jq not found, installing via mise
# [heal] age not found, installing via homebrew
# [heal] ✓ 2 tools installed
```

Priority order: mise → homebrew (macOS) → apt/dnf (Linux) → nix → manual install script.

### 2. Chezmoi Drift

Runs `chezmoi apply --force` to reconcile local files back to the source state. Skipped files (excluded via `.chezmoiignore`) are left alone.

### 3. Broken Symlinks & Missing Files

Detects dangling symlinks (target doesn't exist) and re-applies chezmoi to recreate them. Missing critical files (e.g. `~/.zshrc`) trigger a targeted re-render.

### Flags

- `--dry-run` / `-n` — show what would be fixed, don't change anything
- `--force` / `-f` — skip confirmation prompts
- `--tool <name>` — heal only a specific tool

### Exit Codes

- 0 — nothing to heal or all fixes succeeded
- 1 — some repairs failed, manual intervention required

## `dot chaos` — Self-Test

`dot chaos` intentionally corrupts the local installation to verify `dot heal` can recover it. This is **destructive** — run only in ephemeral environments (containers, VMs, fresh installs).

Corruption scenarios:

| Scenario | What it breaks |
|:---|:---|
| `symlink` | Delete 3 random managed symlinks |
| `config` | Rewrite `~/.gitconfig` with garbage |
| `tool` | `mv` a critical binary out of PATH |
| `permission` | `chmod 000` on a dotfile |
| `all` | Run all scenarios sequentially |

Typical workflow:

```sh
docker run --rm -it ubuntu bash
# inside container:
bash -c "$(curl -fsSL https://.../install.sh)"
dot doctor    # baseline
dot chaos all # break things
dot heal      # fix
dot doctor    # verify
```

This is part of CI: every PR runs `dot chaos` in a Docker container and validates `dot heal` restores a healthy state.

## `dot rollback` — Revert

Before every `dot apply`, chezmoi writes a snapshot to `~/.local/state/dotfiles/snapshots/YYYY-MM-DD-HHMMSS/`. `dot rollback` restores the most recent snapshot:

```sh
dot rollback              # revert to the most recent snapshot
dot rollback status       # list available snapshots
dot rollback restore 3    # restore snapshot #3
dot rollback clean        # delete snapshots older than 30 days
```

Snapshots include:
- Every file chezmoi would have overwritten
- The previous `.chezmoidata.toml` and `chezmoi.toml`
- A pointer to the Git SHA at apply time

They do **not** include:
- Generated caches (`~/.cache/`)
- Tool binaries (Mise-managed)
- External state (databases, remote repos)

## `dot bundle` — Offline Recovery

`dot bundle` creates a self-contained archive that can restore the workstation without network access:

```
dotfiles-bundle-v0.2.500-20260416.tar.zst
├── source/              # Full git clone at current HEAD
├── tools/               # Pre-built chezmoi binary + mise
├── secrets/             # Age-encrypted snapshot of ~/.config/age/
├── manual/              # Offline manual (HTML + PDF)
├── attestation.json     # Signed state
├── install-offline.sh   # Bootstrap script
└── SHA256SUMS           # Integrity checksums
```

Usage:

```sh
dot bundle                        # create bundle in ~/Downloads/
dot bundle --to /path/to/usb.img  # write to external storage
dot bundle restore bundle.tar.zst # restore from bundle
```

Recovery use case: you're stranded on a new machine with no internet. Copy the bundle over (USB, phone tether, Bluetooth). Run `bash install-offline.sh`. You have a working dotfiles environment in <60 seconds, no network required.

## Observability

### Health Score

`dot score` returns a 0-100 score combining:

| Dimension | Weight |
|:---|---:|
| Tool availability | 30 |
| Chezmoi drift | 20 |
| Security gates (sigs, secrets, Age key) | 20 |
| Performance (shell startup, cache health) | 15 |
| Compliance (policy hash match) | 15 |

Scores:
- 90-100 — healthy
- 70-89 — minor issues
- 50-69 — needs attention
- <50 — run `dot heal` immediately

### Metrics

`dot metrics` shows recent observations: shell startup time, last-apply duration, heal events, chaos self-tests, CVE counts from SBOM scan. Metrics are stored locally in `~/.local/state/dotfiles/metrics.jsonl` (append-only, one line per event).

## Design Principles

1. **Idempotent** — running `dot apply` or `dot heal` twice has the same effect as once
2. **Reversible** — every mutation creates a rollback point
3. **Observable** — failures produce actionable error messages with exit codes
4. **Offline-capable** — core flows (detect, heal, rollback) work without network
5. **Minimally invasive** — repairs are scoped to the smallest unit that fixes the problem

## See Also

- [Reliability Operations](../../operations/RELIABILITY.md)
- [Tutorial: First Install](../02-tutorials/01-first-install.md)
- [Cookbook: Troubleshooting](../04-cookbook/02-troubleshooting.md)
