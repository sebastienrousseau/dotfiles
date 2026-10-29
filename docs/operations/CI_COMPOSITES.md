---
render_with_liquid: false
---

# CI Composite Actions

This page documents the repo-local composite actions under
`.github/actions/`. These exist so the most-repeated CI setup blocks
have one canonical implementation, one cache key shape, and one place
to bump pins. Managed under
[#879](https://github.com/sebastienrousseau/dotfiles/issues/879).

## Available actions

### `setup-chezmoi`

Path: `.github/actions/setup-chezmoi/action.yml`

Installs the pinned `chezmoi` binary through the SHA256-verified
installer at `tools/ci/install-chezmoi-verified.sh` (the repo must be
checked out), caches the result, and appends the bin-dir to
`$GITHUB_PATH`. There is no unverified fallback: a version with no
SHA-256 pinned in that installer fails, unless a cached binary of that
version is restored first.

```yaml
- name: Setup Chezmoi
  uses: ./.github/actions/setup-chezmoi
  # `version` defaults to env.CHEZMOI_VERSION. Override explicitly when
  # the calling workflow has no env block (e.g. theme-contracts):
  with:
    version: '2.73.3'
```

Inputs:

| Name | Default | Purpose |
|---|---|---|
| `version` | `env.CHEZMOI_VERSION` | Pinned release tag (no leading `v`). |
| `cache` | `true` | When `false`, skip `actions/cache`. |
| `cache-key-prefix` | `chezmoi` | Override if a workflow wants a private cache scope. |
| `bin-dir` | `~/.local/bin` | Install location. |

Outputs:

| Name | Purpose |
|---|---|
| `version` | The version that ended up installed. |
| `path` | Absolute path to the chezmoi binary. |

Cache key shape: `<prefix>-<runner.os>-<runner.arch>-<version>`.
`runner.arch` is included explicitly so the Apple-Silicon (arm64) and
Intel (x64) macOS runners don't share a cache entry — that previously
caused subtle binary-mismatch failures.

## Why composite actions (vs reusable workflows)

The repo already uses reusable workflows for big-grain CI steps
(`reusable-shell-lint.yml`, `reusable-test-suite.yml`, etc.). Composite
actions cover a different need:

- **Reusable workflows** wrap a whole job — same triggers, same runner,
  same job name. Useful for "lint shell" or "run the test suite".
- **Composite actions** wrap a step sequence. Cheap to drop into any
  job without restructuring the job graph.

Setup steps (install + cache + path) are the textbook composite-action
case: they're short, every caller wants the same behaviour, and
inlining them everywhere creates exactly the duplication this issue
called out.

## Current adopters

`setup-chezmoi` is wired into:

| Workflow | Job(s) | Version from |
|---|---|---|
| `ci.yml` | `test-linux`, `test-macos`, `quality-performance`, `quality-idempotency`, `benchmark` | `env.CHEZMOI_VERSION` |
| `ci-enforced.yml` | `test-matrix`, `test-mutation` | `env.CHEZMOI_VERSION` |
| `nightly.yml` | `extended-os-matrix`, `performance-tracking` | `env.CHEZMOI_VERSION` |
| `perf-baseline.yml` | `baseline` | `env.CHEZMOI_VERSION` |
| `reliability-gate.yml` | `powershell-contract` | `env.CHEZMOI_VERSION` |
| `reusable-test-suite.yml` | `test-suite` | `env.CHEZMOI_VERSION` |
| `theme-contracts.yml` | `render` | literal `version:` input |
| `drift-detection.yml` | `drift-scan` | literal `version:` input |

`setup-mise` was removed: it had no callers and installed mise by piping
`mise.run` into `sh`. A workflow that needs mise should install a pinned
release checked against a committed SHA-256, as `setup-chezmoi` does.

## Pinning policy

The composite action internally pins every external action they use
to a 40-char commit SHA (e.g.
`actions/cache@2c8a9bd7457de244a408f35966fab2fb45fda9c8 # v6.0.0`).
Dependabot picks these up via the standard `github-actions` ecosystem
configuration in `.github/dependabot.yml`.

## Bumping a pin

A chezmoi version is pinned in three kinds of place, and a bump has to
move all of them together:

1. The SHA-256 table in `tools/ci/install-chezmoi-verified.sh`
   (one line per OS and architecture, from the release's
   `checksums.txt`). Without it, the installer refuses the version.
2. The same table in `install.sh` (`chezmoi_release_sha256`) and its
   `CHEZMOI_VERSION` default, so the standalone release installer
   stays self-contained.
3. The workflows: `CHEZMOI_VERSION` in the `env:` block of `ci.yml`,
   `ci-enforced.yml`, `nightly.yml`, `perf-baseline.yml`,
   `reliability-gate.yml` and `reusable-test-suite.yml`, plus the
   literal `version:` input in `theme-contracts.yml` and
   `drift-detection.yml`.

```bash
# Find the new release:
gh api repos/twpayne/chezmoi/releases/latest --jq '.tag_name'

# Update the workflow-level env declarations:
for f in .github/workflows/{ci,ci-enforced,nightly,perf-baseline,reliability-gate,reusable-test-suite}.yml; do
  sed -i.bak 's/CHEZMOI_VERSION: "[^"]*"/CHEZMOI_VERSION: "X.Y.Z"/' "$f"
  rm "$f.bak"
done

# The two workflows that pass the version as an input:
for f in .github/workflows/{theme-contracts,drift-detection}.yml; do
  sed -i.bak "s/version: '[^']*'/version: 'X.Y.Z'/" "$f"
  rm "$f.bak"
done
```

`update-deps.yml` does not bump any of these: a `GITHUB_TOKEN` cannot
push workflow files. `nightly.yml` reports when a newer chezmoi
release exists.

## References

- `.github/actions/setup-chezmoi/action.yml`
- `tools/ci/install-chezmoi-verified.sh` — the SHA-pinned installer
  the chezmoi composite prefers when available.
- Issue [#879](https://github.com/sebastienrousseau/dotfiles/issues/879).
