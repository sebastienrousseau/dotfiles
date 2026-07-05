---
render_with_liquid: false
---

# Shell Preamble Exemptions

Every bash script in this repo must include `set -euo pipefail` (or
`set -eu` for POSIX `sh`) within its first 50 lines. The rule is
enforced by
[`tools/ci/check-shell-preamble.sh`](https://github.com/sebastienrousseau/dotfiles/blob/main/tools/ci/check-shell-preamble.sh),
wired into `pre-commit` and the `reusable-shell-lint.yml` CI job.
Tests pin the contract under
[`tests/unit/security/test_shell_preamble_lint.sh`](https://github.com/sebastienrousseau/dotfiles/blob/main/tests/unit/security/test_shell_preamble_lint.sh).

## Why the preamble is mandatory

`set -e` fails the script on the first error. `set -u` rejects
reads of unset variables. `set -o pipefail` propagates the exit
code of the last failing command in a pipeline rather than only the
final command's. Together they convert silent failures into loud
ones — which is the only way to catch them.

Real example from this repo's history: `executable_dot-load-benchmark`
shipped with only `set -e`. A failing pipeline (e.g. `cmd | grep`)
where `grep` succeeded would still report success even when `cmd`
crashed. The full triple catches this. The benchmark was upgraded
in commit 970b631d under #854.

## Exemption categories

Two kinds of files legitimately can't enforce the preamble locally:

### 1. Sourced libraries

Files loaded via `source` / `.` into a caller's shell context. The
caller already has `set -euo pipefail`; the library inherits it.
Adding `set -e` locally would persist after the library returns and
break the caller's own error-handling logic.

These files must carry a comment header in their first 15 lines:

```bash
# Sourced by <parent>.sh; inherits set -euo pipefail.
```

The lint accepts files with this marker regardless of preamble
state. Current adopters:

| Path | Sourced by |
|---|---|
| `dot_config/shell/00-core-paths.sh.tmpl` | shell init (zsh/bash/fish) |
| `dot_config/shell/05-core-safety.sh` | shell init |
| `dot_config/shell/10-secrets.sh` | shell init |
| `dot_config/shell/40-fzf-defaults.sh.tmpl` | shell init |
| `dot_config/shell/40-ls-colors.sh` | shell init |
| `dot_config/shell/50-logic-functions-core.sh.tmpl` | shell init + fish bridge |
| `dot_config/shell/50-logic-functions.sh.tmpl` | shell init + fish bridge |
| `dot_config/shell/51-logic-functions-extra.sh.tmpl` | shell init (lazy) |
| `dot_config/shell/90-ux-aliases.sh.tmpl` | shell init + fish bridge |
| `dot_config/shell/91-ux-aliases-lazy.sh.tmpl` | shell init (lazy) |
| `scripts/dot/lib/bento.sh` | dot CLI commands |
| `scripts/dot/lib/log.sh` | dot CLI + diagnostics |
| `scripts/dot/lib/platform.sh` | dot CLI commands |
| `scripts/dot/lib/ui.sh` | dot CLI + diagnostics + ops |
| `scripts/dot/lib/utils.sh` | dot CLI |
| `scripts/ops/heal-chezmoi.sh` | `scripts/ops/heal.sh` |
| `scripts/ops/heal-system.sh` | `scripts/ops/heal.sh` |
| `scripts/ops/heal-tools.sh` | `scripts/ops/heal.sh` |

### 2. Bulk-sourced fragments (path-skipped)

Three directories contain hundreds of alias / function / PATH
snippets that are sourced into the shell. Annotating each one
individually would be 300+ marker comments with no extra signal.
The lint skips them by path:

| Path | Contents |
|---|---|
| `.chezmoitemplates/aliases/**/*.aliases.sh` | alias definitions sourced into the user's shell. |
| `.chezmoitemplates/functions/**` | shell-function definitions sourced into the user's shell. |
| `.chezmoitemplates/paths/**` | `PATH=…:$PATH` snippets concatenated by the shell init. |

### 3. Test scripts (path-skipped)

`tests/**` — every file under the test tree is invoked through
`tests/framework/test_runner.sh` which manages shell options for its
children. The runner itself has the full preamble; children that
source the framework inherit it.

### 4. Explicit opt-outs

Init fragments and completion scripts that must NOT carry their own
preamble (e.g., `dot_local/bin/executable_dot_completion`, a zsh
completion sourced into the interactive shell) can carry an
explicit marker:

```bash
# preamble:skip — opt-out for completion / init fragments.
```

The lint accepts these. Use sparingly.

## Adding a new exemption

When you need to mark a new file:

1. **Decide whether it's actually sourced or executed.** If a user
   ever invokes it directly (chmod +x + `./file.sh`), add the
   preamble. If it's only ever `source`d, mark it.

2. **Pick the right marker.**
   - Sourced library: `# Sourced by <caller>; inherits set -euo pipefail.`
   - Completion / init fragment: `# preamble:skip — <why>.`

3. **Run the checker:**

   ```bash
   ./tools/ci/check-shell-preamble.sh path/to/file.sh
   ```

   Exit 0 = lint passes.

4. **If you're adding a new entire directory of fragments**
   (rare — alias buckets, plugin trees), edit the path-skip rule
   in `tools/ci/check-shell-preamble.sh` and document it in this
   page's "Bulk-sourced fragments" table above.

## CI integration

- **Pre-commit hook** (`config/pre-commit-config.yaml` →
  `shell-preamble-check`): blocks `git commit` if a staged shell
  file fails the lint.
- **CI** (`.github/workflows/reusable-shell-lint.yml`): runs the
  full-repo scan on every PR.

A change to either the checker or the marker convention must update
this page in the same PR.

## References

- `tools/ci/check-shell-preamble.sh` — the lint.
- `tests/unit/security/test_shell_preamble_lint.sh` — contract test.
- `config/pre-commit-config.yaml` (`shell-preamble-check` hook).
- `.github/workflows/reusable-shell-lint.yml` — CI invocation.
- Issue [#854](https://github.com/sebastienrousseau/dotfiles/issues/854).
