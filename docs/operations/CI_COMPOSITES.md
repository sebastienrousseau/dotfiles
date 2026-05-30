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

Installs the pinned `chezmoi` binary (using the SHA256-verified
installer at `tools/ci/install-chezmoi-verified.sh` when the repo is
checked out, falling back to `get.chezmoi.io` otherwise), caches the
result, and appends the bin-dir to `$GITHUB_PATH`.

```yaml
- name: Setup Chezmoi
  uses: ./.github/actions/setup-chezmoi
  # `version` defaults to env.CHEZMOI_VERSION. Override explicitly when
  # the calling workflow has no env block (e.g. drift-detection):
  with:
    version: '2.70.3'
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

### `setup-mise`

Path: `.github/actions/setup-mise/action.yml`

Installs `mise` (jdx/mise) and optionally runs `mise install` against
`mise.toml` to materialise the managed toolchain. Caches both the
mise binary and `~/.local/share/mise` (the tool install root, keyed
by lockfile hash).

```yaml
- name: Setup mise
  uses: ./.github/actions/setup-mise
  with:
    install-tools: 'true'
```

Inputs:

| Name | Default | Purpose |
|---|---|---|
| `version` | `latest` | mise version to install. Specify a pinned version to enable bin caching. |
| `cache` | `true` | Cache the mise binary + tool root. |
| `cache-key-prefix` | `mise` | Override the cache scope. |
| `install-tools` | `false` | When `true`, run `mise install` after setup. |
| `bin-dir` | `~/.local/bin` | Install location for the mise binary. |

Outputs: `version` (installed mise version) and `path` (absolute path
to the mise binary).

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

| Workflow | Job(s) |
|---|---|
| `ci-enforced.yml` | `test-matrix` |
| `ci.yml` | `test-linux`, `test-macos`, `quality-idempotency`, `performance` |
| `nightly.yml` | `extended-os-matrix`, `nightly-perf-bench` |
| `drift-detection.yml` | `drift-scan` |

Total: 8 call sites converted. The net workflow LOC delta is
~−34 lines (52 deletions, 18 additions); ongoing additions to either
workflow set will widen the gap.

`setup-mise` ships ready for use but has zero current callers because
no workflow currently installs mise (the maintainer relies on it
locally only). When a future workflow needs `cargo`, `bun`, `go`, or
`rust` toolchains via the canonical version manager, this composite
is the canonical entry point.

## Pinning policy

Both composite actions internally pin every external action they use
to a 40-char commit SHA (e.g.
`actions/cache@27d5ce7f107fe9357f9df03efb73ab90386fccae # v5.0.5`).
Dependabot picks these up via the standard `github-actions` ecosystem
configuration in `.github/dependabot.yml`.

## Bumping a pin

To upgrade `chezmoi` for every CI job at once:

```bash
# Find the new release:
gh api repos/twpayne/chezmoi/releases/latest --jq '.tag_name'

# Update the three workflow-level env declarations:
for f in .github/workflows/{ci.yml,ci-enforced.yml,nightly.yml}; do
  sed -i.bak 's/CHEZMOI_VERSION: "[^"]*"/CHEZMOI_VERSION: "X.Y.Z"/' "$f"
  rm "$f.bak"
done

# Drift-detection has its own pin (no env block):
sed -i.bak "s/version: '[^']*'/version: 'X.Y.Z'/" .github/workflows/drift-detection.yml
rm .github/workflows/drift-detection.yml.bak
```

Or rely on `update-deps.yml`, which already automates the env-block
bump on a weekly schedule.

## References

- `.github/actions/setup-chezmoi/action.yml`
- `.github/actions/setup-mise/action.yml`
- `tools/ci/install-chezmoi-verified.sh` — the SHA-pinned installer
  the chezmoi composite prefers when available.
- Issue [#879](https://github.com/sebastienrousseau/dotfiles/issues/879).
