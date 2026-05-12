# Drift Detection & Remediation

This page documents how this repo detects drift between the chezmoi
source-of-truth and what's actually deployed on a host, how to read
the report, and how to remediate. Managed under
[#875](https://github.com/sebastienrousseau/dotfiles/issues/875).

## What "drift" means here

Four distinct classes are tracked. The same `dot drift` command (and
the nightly CI workflow) surfaces all four.

| Class | Meaning | How to detect | Typical fix |
|---|---|---|---|
| **Managed drift** | A chezmoi-managed file's deployed copy differs from what a fresh `chezmoi apply` would produce. The standard case. | `chezmoi status` (M / MM / A / R rows) | Either update the source so apply is idempotent, or accept the deployed change and re-add. |
| **Untracked source** | The chezmoi source tree contains files git doesn't know about — usually in-progress local edits that haven't been committed. | `git -C <source-dir> ls-files --others --exclude-standard` | Commit, stash, or `.gitignore` the file. |
| **Orphan deployed** | A file under `$HOME` was previously chezmoi-managed but the source has since been deleted. Chezmoi no longer claims it, so a fresh apply leaves it behind silently. | Inventoried in `${XDG_STATE_HOME}/dotfiles/orphans` (populated by `dot heal` / `dot drift`) | `chezmoi remove --force` the path, or re-add the source if the file is still wanted. |
| **Stale source** | The deployed file is *newer* than its source. The next `chezmoi apply` would silently revert the user's hand-edit. Reverse-drift trap. | Compare mtimes for each managed target vs the resolved source-path | Promote the deployed change into the source (`chezmoi re-add`) or revert the deployed file. |

## Reading the report

```bash
dot drift          # human-readable (uses the ui.sh formatting)
dot drift --json   # single JSON object — used by the nightly workflow
dot drift --diff   # also print `chezmoi diff` for managed drift
```

JSON shape:

```json
{
  "managed_drift": 0,
  "untracked_source": 0,
  "orphan_deployed": 0,
  "stale_source": 0,
  "total": 0
}
```

Exit code: `0` if every class is clean; `1` if any drift is found;
`2` if a prerequisite (chezmoi, git) is missing.

## How the nightly check works

`.github/workflows/drift-detection.yml` runs `dot drift --json` against
a fresh checkout of `master` every day at 04:00 UTC. If `total != 0`
it opens (or updates) a tracking issue labelled
`type:chore + priority:medium` with the JSON summary, full
`chezmoi diff`, and `chezmoi status` attached as a workflow artifact.

The workflow itself ignores the failing exit code (`|| true`) for the
dashboard step — the actionable signal is the issue, not a red CI
indicator.

## Force a local drift check

```bash
dot drift            # default — what you'd run before opening a PR
dot drift --json | jq '.'   # for scripting / dashboards
```

To force a full re-comparison after a tool upgrade or a force-apply:

```bash
chezmoi apply --refresh-externals   # refetch external sources
dot drift                            # re-scan
```

## Historical incidents

### 2026-05-12 — `core.hooksPath` drift

The deployed `~/.gitconfig` contained a `hooksPath = ~/.git-templates/hooks`
line that wasn't in `dot_gitconfig.tmpl`. The line had been added
directly to the deployed file (manually, not via chezmoi), then sat
silently for weeks while the global `commit-msg` hook (at
`~/.config/git/hooks/commit-msg`) never fired — because `hooksPath`
was pointing at an empty directory. The result: every commit
authored on this machine silently shipped without the
`Assisted-by:` trailer mandated by `dot_claude/CLAUDE.md`.

Detection failure: no nightly drift check existed at the time.

Resolution: commit `f060683b` brought `hooksPath` into the chezmoi
template; this drift class is exactly what the new `stale_source`
signal catches going forward.

This incident is the canonical worked example for why the four-class
report exists rather than just `chezmoi status`.

## Configuration surface

| Variable | Default | Purpose |
|---|---|---|
| `DOTFILES_DRIFT_SHOW_DIFF` | `0` | When `1`, append `chezmoi diff` (excluding scripts/install/tests) to the report. Equivalent to `--diff`. |

## References

- `scripts/diagnostics/drift-dashboard.sh` — the dashboard itself.
- `.github/workflows/drift-detection.yml` — the nightly scanner.
- `tests/unit/diagnostics/test_drift_dashboard.sh` — JSON contract test.
- `dot heal` / `dot rollback` — drift remediation commands.
- Issue [#875](https://github.com/sebastienrousseau/dotfiles/issues/875).
