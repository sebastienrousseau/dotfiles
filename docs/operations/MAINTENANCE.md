---
render_with_liquid: false
---

# Dotfiles Maintenance Runbook

This runbook captures recovery and release maintenance operations for this repository.

## Updates and scheduled maintenance

`dot update` (short for `dot system update`) is the one update path. It
updates the dotfiles, the mise tools and, after asking, the system
packages (Homebrew, apt, dnf, pacman or zypper) and the app stores (mas,
Flatpak, Snap). `--globals` adds npm, cargo and pipx globals, and `--yes`
answers every question. The AI CLIs stay at their `[ai_tools]` pins;
`dot ai update` moves them past the pins. Topgrade, the
`~/.local/bin/update` script and the `update`/`upd` functions are gone;
`chezmoi apply` deletes the script and the topgrade config, and `update`
and `upd` forward to `dot update` with a warning until 0.2.538.

The maintenance job clears the shell startup caches and rotates the dot
log. Nothing is scheduled until you ask:

```bash
dot system schedule set weekly   # or daily; Sundays (or daily) at 10:00
dot system schedule              # the job, its schedule, whether it is loaded
dot system schedule run          # run it now
dot system                       # OS, disk, schedule and the last run
dot system schedule set off      # unload and delete it
```

On macOS `set` writes and loads
`~/Library/LaunchAgents/com.sebastienrousseau.dot-maintenance.plist`; a
run missed while the Mac slept happens at the next wake. On Linux it
writes `dot-maintenance.service` and `.timer` under
`~/.config/systemd/user` and enables the timer (`Persistent=true`). Each
run records its time and exit code in
`$XDG_STATE_HOME/dot/system/last-run`, and its output in `last-run.log`
beside it. The old `dotfiles-maintenance` units, deployed but never
enabled, are deleted by `chezmoi apply`.

## Signed History Recovery (February 19, 2026)

**Purpose:** Recover from strict signature enforcement failures caused by legacy/non-compliant commit history.

**When to use:**

- Pushes are blocked by signature policy on historical commits.
- Merge ancestry contains commits that can't be validated by the current principal/key policy.

**Procedure:**

1. Create a backup ref for current `main`.
2. Build a rewritten signed baseline commit from the current tree.
3. Push the rewritten branch to remote.
4. Temporarily allow force-push on `main` protections/rulesets.
5. Force-update `main` to the rewritten signed baseline.
6. Disable force-push again immediately.
7. Re-run CI and verify required checks are green.
8. Repoint the release tag/target as needed.

**Verification commands:**

```bash
git verify-commit HEAD
gh run list --workflow ci.yml --branch main --limit 1
gh release view v0.2.501 --json tagName,targetCommitish,url
```

## Release Closeout Checklist

For every release update:

1. `main` branch is clean and synced.
2. CI is green on the release commit.
3. Annotated release tag points to the intended commit.
4. GitHub release target is correct (`main` or explicit commit).
5. Branch protections/rulesets are restored to strict state.
6. Local apply has completed:

```bash
CHEZMOI_SOURCE_DIR="$HOME/.dotfiles" ./bin/dot apply
```

## Security Scan Guardrails

We prevent gitleaks historical-scan regressions with:

- Shallow checkout (`fetch-depth: 1`, `fetch-tags: false`) in gitleaks jobs.
- A workflow-dispatch guard script: `tools/ci/guard-gitleaks-checkout.sh`.

**Manual verification:**

```bash
bash tools/ci/guard-gitleaks-checkout.sh
```
