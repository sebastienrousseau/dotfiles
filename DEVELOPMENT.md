<!-- SPDX-License-Identifier: Apache-2.0 OR MIT -->
<!-- Copyright (c) 2015-2026 Sebastien Rousseau -->

# Development

The single entry point for working on this repository. If you are
*using* the dotfiles rather than changing them, you want the
[manual](https://doc.dotfiles.io/) instead. If you are about to open a
pull request, read [`CONTRIBUTING.md`](CONTRIBUTING.md) too — it covers
commit signing, DCO sign-off, and branch naming, which this file does
not repeat.

- [Toolchain setup](#toolchain-setup)
- [Repository layout](#repository-layout)
- [The test suite](#the-test-suite)
- [Reproducing every CI gate locally](#reproducing-every-ci-gate-locally)
- [Generated artefacts](#generated-artefacts)
- [The release model](#the-release-model)

---

## Toolchain setup

Three supported paths. Pick one; they are equivalent for the purposes
of `make check`.

### 1. mise (what CI and the maintainer use)

```bash
git clone https://github.com/sebastienrousseau/dotfiles
cd dotfiles
mise install          # reads mise.toml + mise.lock, pinned versions
mise exec -- make test
```

### 2. Nix

```bash
nix develop           # root flake.nix devShell: shells, linters, chezmoi, go
make test
```

`direnv allow` wires the same shell automatically via `.envrc`.

### 3. Dev container / Codespaces

Open the repository in a dev container (`.devcontainer/`) and wait for
`postCreateCommand`. It boots to a working `make`.

### Minimum host tooling

`bash`, `git`, `curl`, and `chezmoi` are enough to *run* the framework.
Contributing additionally needs `shellcheck`, `shfmt`, `go` (for the
fuzz harnesses), and `python3` (for `pre-commit`). Exact floors and the
policy for raising them: [`docs/MINIMUM-TOOLCHAIN.md`](docs/MINIMUM-TOOLCHAIN.md).

### Pre-commit hooks

```bash
GIT_CONFIG_GLOBAL=/dev/null pre-commit install --hook-type pre-commit --hook-type commit-msg --hook-type pre-push -f
pre-commit run --all-files --config config/pre-commit-config.yaml
```

`pre-commit install` refuses to run while any `core.hooksPath` is set,
and these dotfiles set a global one, hence `GIT_CONFIG_GLOBAL=/dev/null`.
See [`CONTRIBUTING.md`](CONTRIBUTING.md#pre-commit-hooks) for what the
`pre-push` type replaces.

The hook set mirrors CI: shellcheck, shfmt, hadolint, gitleaks,
detect-secrets, checkov, conventional-commits, typos, actionlint,
yamllint, markdownlint-cli2, luacheck, stylua, plus the repo-local
drift gates (command index, man page, completions, version surfaces).

---

## Repository layout

Full map: [`docs/architecture/REPO_LAYOUT.md`](docs/architecture/REPO_LAYOUT.md)
and [`docs/STRUCTURE.md`](docs/STRUCTURE.md). The parts you touch most:

| Path | What |
|---|---|
| `bin/dot` | CLI dispatcher. |
| `plugins/<domain>/dot-plugin.toml` | **The command names** (ADR-020): each domain's objects, commands, flags and aliases. A plugin with an `[entry]` runs its own commands through `plugins/<domain>/dot-<domain>`; a plugin without one (today `ui` and `session`) only declares planned commands. |
| `plugins/<domain>/commands.txt` | The plugin's route fragment, generated from its manifest. `bin/dot` merges the fragments (with `lib/dot/data/groups.txt`, through `lib/dot/table-merge.awk`) into its command table, cached at `$XDG_CACHE_HOME/dot/cli/commands.txt`. |
| `lib/dot/data/` | `commands.txt` and `commands.json`, generated from the manifests by `tools/ci/cli_command_table.py` (the full table: the build tools read it, and `bin/dot` falls back to it when the fragments cannot be merged); `routes.txt` (top-level word → module). `help-specs.txt` and `help-details.txt` still back `dot help <old-name>` until the old names are removed. |
| `scripts/dot/commands/` | The route modules behind `routes.txt` (`diagnostics.sh`, `manual.sh`, `meta.sh`); every domain runs from its plugin's entry. |
| `lib/dot/` | Shared bash library sourced by every subcommand. |
| `defaults/` | The chezmoi source tree (everything that lands in `$HOME`), rebased via `.chezmoiroot`. |
| `tests/` | `framework/`, `unit/`, `integration/`, `regression/`, `snapshots/`, `consumer/`, `visual/`, `fixtures/`. |
| `benches/` | Benchmarks. Smoke-run, not asserted. |
| `fuzz/` | Go fuzz harnesses, committed regression corpus, OSS-Fuzz scaffolding. |
| `pkg/` | One directory per packaging format, rendered per release. |
| `tools/` | Repo-only ops: CI helpers, doc generators, release staging. Never ships to users. |
| `supply-chain/` | Provenance policy and the allowlists CI enforces. |

Adding a `dot` command touches four places; the drift gates will tell
you if you miss one:

1. The implementation: a case in `plugins/<domain>/dot-<domain>`, which
   gets the words after the domain (and, with `fallback = true`, the bare
   domain and any word the table does not take); larger plugins keep their
   code in `plugins/<domain>/libexec/`
2. `plugins/<domain>/dot-plugin.toml` — a `[[commands]]` entry with an
   approved verb, its effect and its summary, plus `planned = true` until
   it is built, checked by `tools/ci/check-cli-contract.py`
3. `docs/reference/UTILS.md` (the docs coverage gate) and
   `docs/manual/03-reference/01-dot-cli.md` — reference prose
4. `make generate` — regenerates the command table, command index, command
   reference, man pages, completions and PowerShell cmdlets

---

## The test suite

```bash
make test              # full reliability audit (what reliability-gate.yml runs)
make test-unit         # unit only
make test-integration  # unit + integration
make test-quick        # fast subset for the edit loop
./tests/framework/test_runner.sh --jobs auto          # the runner directly
RUN_INTEGRATION=1 ./tests/framework/test_runner.sh    # what reusable-test-suite.yml runs
bash tests/unit/dot-cli/test_dot_completion.sh        # a single file
```

Layout and conventions:

| Directory | Contains | Rule |
|---|---|---|
| `tests/framework/` | `test_runner.sh`, `assertions.sh`, `mocks.sh` | The harness itself. |
| `tests/unit/<domain>/` | `test_<feature>.sh` | One directory per domain. Fast, no network, no `$HOME` writes. |
| `tests/integration/` | End-to-end install/apply | Needs a sandbox; gated behind `RUN_INTEGRATION=1`. |
| `tests/regression/` | Guardrails for fixed bugs | **Must** carry a `# Regression for: GH-1234` header in the first 15 lines (enforced by a pre-commit hook and audited weekly). |
| `tests/snapshots/` | Golden CLI output | Fix the CLI, do not regenerate blindly. |
| `benches/` | Performance | Not asserted; see `benches/README.md`. |
| `fuzz/` | Fuzz harnesses + corpus | `make fuzz`; see `fuzz/README.md`. |

Tests execute shell source files directly, so **never** put Go template
syntax in a non-`.tmpl` file — the runner chokes on the braces.

Coverage is gated at **98%**, and at **96%** for the behavioural-only
run that switches off the exercise-only probes (`MIN_COVERAGE_PCT` in
`coverage.yml`). The floor history is recorded there: each floor is
ratcheted deliberately from what CI measured, rather than an
aspirational number that would be permanently red.

---

## Reproducing every CI gate locally

Most workflows are one of a handful of scripts; the tables map each
to the command that reproduces it. `make check` runs the everyday
subset (lint + drift + test + examples) in one go.

### Local environment

Three things this table assumes, each learnt from a check that failed
locally while CI passed:

- **Load the repository's mise tools first.** Several tests start the
  tools through mise shims under a test `HOME`, where a shim cannot find
  its tool unless the environment already points at it:
  `eval "$(mise env -s bash)"` (or `zsh`) before `make test` or
  `./tests/framework/test_runner.sh`.
- **`make check-drift` needs `jsonschema`** for
  `tools/ci/check-cli-contract.py`:
  `uv run --no-project --with jsonschema make check-drift`.
- **Build the WASM verifier once** so the real-module checks of
  `test_diagnostics_attest_verify.sh` run instead of being skipped:
  `cargo build --release --target wasm32-wasip1 --manifest-path lib/wasm-tools/Cargo.toml`.

### Every job

One row per job of every workflow. The command comes from
[`docs/ci-gates.toml`](docs/ci-gates.toml); the job list, its egress
policy (Harden Runner: `blocked`, `allow-listed`, `unrestricted`, or
`reusable` for a job that calls another workflow) and the secrets it
reads come from the workflow file. `make check-drift` fails when a
workflow has no entry or a command names a make target or script that
does not exist.

<!-- BEGIN GENERATED: docs/ci-gates.toml -->
<!-- Do not edit: run `make generate` after changing docs/ci-gates.toml or a workflow. -->

| Workflow | Job | Locally | Egress | Secrets |
|---|---|---|---|---|
| `branch-drift-guard.yml` | Long-lived branches are not drifting | none: compares open branches with main on GitHub | unrestricted | — |
| `cflite_pr.yml` | ClusterFuzzLite / Build | `make fuzz` (the ClusterFuzzLite build itself needs Docker) | unrestricted | — |
| `ci-enforced.yml` | Lint / Shell (Zero Warnings) | `make lint-shell` | reusable | — |
| `ci-enforced.yml` | Lint / Lua (Zero Warnings) | `luacheck . && stylua --check .` | reusable | — |
| `ci-enforced.yml` | Lint / Nix (Zero Warnings) | `nix flake check` (root and nix/) | reusable | — |
| `ci-enforced.yml` | Lint / Copyright Headers (Zero Tolerance) | `make lint-copyright` | reusable | — |
| `ci-enforced.yml` | Security / Secrets Scan | `gitleaks detect --config config/gitleaks.toml` | unrestricted | — |
| `ci-enforced.yml` | Security / Dependency Audit | `make sbom` | unrestricted | — |
| `ci-enforced.yml` | Security / Infrastructure Scan | `checkov -d . --framework dockerfile,yaml,secrets --skip-path fuzz/oss-fuzz/` | unrestricted | — |
| `ci-enforced.yml` | Test / ${{ matrix.os }} | `make test` | unrestricted | — |
| `ci-enforced.yml` | Test / Unit Tests | `make test-unit` | reusable | — |
| `ci-enforced.yml` | Lint / Tests run the code | `python3 tools/ci/check-source-grep-tests.py` | unrestricted | — |
| `ci-enforced.yml` | Lint / Install pins | `make lint` | unrestricted | — |
| `ci-enforced.yml` | Lint / Complexity ratchet | `python3 tools/ci/complexity.py && python3 tools/ci/complexity_polyglot.py --lang python` | unrestricted | — |
| `ci-enforced.yml` | Lint / Complexity ratchet (Go) | `python3 tools/ci/complexity_polyglot.py --lang go` | unrestricted | — |
| `ci-enforced.yml` | Test / Mutation | `python3 tools/ci/mutation-test.py --base origin/main --min-score 80` | unrestricted | — |
| `ci-enforced.yml` | Security / Policy Script | `bash scripts/security/enforce-policies.sh` | unrestricted | — |
| `ci-enforced.yml` | Toolchain / mise install (Linux) | `mise install` | unrestricted | — |
| `ci-enforced.yml` | Merge Gate | none: aggregates the jobs above | unrestricted | — |
| `ci.yml` | Detect Changes | none: path filter for the jobs below | unrestricted | — |
| `ci.yml` | Lint / Shell | `make lint-shell` | reusable | — |
| `ci.yml` | Lint / Lua | `luacheck . && stylua --check .` | reusable | — |
| `ci.yml` | Lint / Fish | `fish --no-execute <file> per fish file` | unrestricted | — |
| `ci.yml` | Lint / Nushell | `nu --commands 'source <file>' per nu file` | unrestricted | — |
| `ci.yml` | Lint / Copyright | `bash tools/ci/check-copyright-headers.sh` | reusable | — |
| `ci.yml` | Lint / Reusable Workflow Pins | `bash tools/ci/lint-reusable-pins.sh` | unrestricted | — |
| `ci.yml` | Lint / Chezmoidata Schema | `bash tools/ci/validate-chezmoidata.sh` | unrestricted | — |
| `ci.yml` | Security / Secrets Scan | `gitleaks detect --config config/gitleaks.toml` | reusable | — |
| `ci.yml` | Security / Dependency Audit | `make sbom` | reusable | — |
| `ci.yml` | Security / TruffleHog | `trufflehog filesystem .` | unrestricted | — |
| `ci.yml` | Security / SBOM Generation | `make sbom` | unrestricted | — |
| `ci.yml` | Security / Link Check | `make lint-links` | unrestricted | — |
| `ci.yml` | Test / Linux | `make test` | unrestricted | — |
| `ci.yml` | Test / macOS | `make test` | unrestricted | — |
| `ci.yml` | Test / Windows | `pwsh scripts/qa/powershell-contract.ps1` | unrestricted | — |
| `ci.yml` | Test / Integration (Docker) | `docker build .` (needs Docker) | unrestricted | — |
| `ci.yml` | Quality / Performance budgets (${{ matrix.os }}) | `bash scripts/diagnostics/perf.sh --json` | unrestricted | — |
| `ci.yml` | Quality / Idempotency | `chezmoi apply twice; the second apply changes nothing` | unrestricted | — |
| `ci.yml` | Quality / Nix | `nix flake check` | reusable | — |
| `ci.yml` | Benchmark / Linux | `make bench` | unrestricted | — |
| `ci.yml` | Quality Gate | none: aggregates the jobs above | unrestricted | — |
| `cockpit-test.yml` | Cockpit / Test + Coverage (go ${{ matrix.go }}) | `cd defaults/dot_local/share/dot-ai-tui && go test ./... && go vet ./...` | unrestricted | — |
| `cockpit-test.yml` | Cockpit / staticcheck + golangci-lint | `cd defaults/dot_local/share/dot-ai-tui && go test ./... && go vet ./...` | unrestricted | — |
| `codeql.yml` | Security / CodeQL | none: needs the CodeQL CLI (codeql database create) | unrestricted | — |
| `compliance-guard.yml` | Verify Commit Signatures | `git log --format='%G?' origin/main..HEAD` (G on every line) | unrestricted | — |
| `compliance-guard.yml` | Scan for Insecure Patterns | `bash tools/ci/check-insecure-tls.sh && bash tools/ci/check-dangerous-chmod.sh` | unrestricted | — |
| `compliance-guard.yml` | Portability Shell Lint | `make lint-shell` | reusable | — |
| `compliance-guard.yml` | Cross-Platform Portability | `bash tools/ci/check-insecure-tls.sh && bash tools/ci/check-dangerous-chmod.sh` | unrestricted | — |
| `compliance-guard.yml` | Dockerfile Lint | `hadolint $(git ls-files '*Dockerfile*')` | unrestricted | — |
| `compliance-guard.yml` | Compliance Summary | none: aggregates the jobs above | unrestricted | — |
| `core-contracts.yml` | Core / ${{ matrix.os }} | `python3 tools/ci/check-cli-contract.py` (with jsonschema installed) | unrestricted | — |
| `core-contracts.yml` | contracts | `python3 tools/ci/check-cli-contract.py` (with jsonschema installed) | unrestricted | — |
| `core-contracts.yml` | visual | `python3 tools/ci/check-cli-contract.py` (with jsonschema installed) | unrestricted | — |
| `core-contracts.yml` | npm-consumer | `python3 tools/ci/check-cli-contract.py` (with jsonschema installed) | unrestricted | — |
| `coverage.yml` | Coverage / kcov | `MIN_COVERAGE_PCT=98 bash tools/ci/run-coverage.sh` | unrestricted | — |
| `coverage.yml` | Coverage / behavioural tests only | `DOTFILES_COV_EXERCISE=0 MIN_COVERAGE_PCT=96 bash tools/ci/run-coverage.sh` | unrestricted | — |
| `cross-platform-test.yml` | Detect Changes | none: path filter for the jobs below | unrestricted | — |
| `cross-platform-test.yml` | Test on ${{ matrix.os }} | `bash -n over every .sh, then bash scripts/diagnostics/health.sh` | unrestricted | — |
| `cross-platform-test.yml` | Scheduled maintenance on ${{ matrix.os }} | `bash -n over every .sh, then bash scripts/diagnostics/health.sh` | unrestricted | — |
| `cross-platform-test.yml` | Compatibility Report | `bash -n over every .sh, then bash scripts/diagnostics/health.sh` | unrestricted | — |
| `cross-platform-test.yml` | Cross-Platform Tests | none: aggregates the jobs above | unrestricted | — |
| `dco.yml` | Check sign-off | `git log --format='%(trailers:key=Signed-off-by)' origin/main..HEAD` (no empty lines) | allow-listed | — |
| `dependency-review.yml` | Security / Dependency Review | none: pull-request only, run by GitHub | unrestricted | — |
| `deps-dev-validation.yml` | deps.dev / direct deps | `bash tools/ci/check-deps-dev.sh` | unrestricted | — |
| `devcontainer-prebuild.yml` | Build Devcontainer Image | none: scheduled devcontainer image build | unrestricted | — |
| `doc-drift.yml` | Generators / command-index | `make check-drift` (with jsonschema installed) | allow-listed | — |
| `doc-drift.yml` | Generators / README template | `python3 tools/ci/check-readme-template.py --enforce && python3 tools/docs/gen_ecosystem.py --check && python3 tools/docs/gen_ci_gates.py --check` | allow-listed | — |
| `doc-drift.yml` | Generators / version-consistency | `bash scripts/verify-release-versions && python3 tools/ci/check-readme-toolchain.py` | allow-listed | — |
| `doc-drift.yml` | Generators / man page | `make check-drift` (with jsonschema installed) | allow-listed | — |
| `doc-drift.yml` | Generators / completions | `make check-drift` (with jsonschema installed) | allow-listed | — |
| `docs-link-check.yml` | Docs / Link Check (offline, gating) | `make lint-links` | allow-listed | — |
| `docs-link-check.yml` | Docs / Link Check (online, advisory) | `make lint-links` | unrestricted | — |
| `docs-link-check.yml` | Docs / REUSE lint | `make lint-reuse` | unrestricted | — |
| `dot-cli-bench.yml` | dot CLI / ${{ matrix.os }} | `DOT_BENCH_BUDGET_MS=150 DOT_BENCH_RUNS=11 bash tools/ci/dot-cli-startup-bench.sh` | unrestricted | — |
| `dot-cli-bench.yml` | agent hook / ${{ matrix.os }} | `DOT_BENCH_BUDGET_MS=150 DOT_BENCH_RUNS=11 bash tools/ci/dot-cli-startup-bench.sh` | unrestricted | — |
| `dot-cli-bench.yml` | dot CLI sweep / ${{ matrix.os }} | `DOT_BENCH_BUDGET_MS=150 DOT_BENCH_RUNS=11 bash tools/ci/dot-cli-startup-bench.sh` | unrestricted | — |
| `dot-ui-test.yml` | dot-ui / Test + Coverage (go ${{ matrix.go }}) | `cd defaults/dot_local/share/dot-ui && go test ./... && go vet ./...` | unrestricted | — |
| `dot-ui-test.yml` | dot-ui / staticcheck + golangci-lint | `cd defaults/dot_local/share/dot-ui && go test ./... && go vet ./...` | unrestricted | — |
| `drift-detection.yml` | Drift / Master | none: scheduled housekeeping | unrestricted | — |
| `flake-detector.yml` | Flakes / ${{ matrix.os }} | `./tests/framework/test_runner.sh --jobs auto, several times, then python3 tools/ci/flake-report.py <logs>` | unrestricted | — |
| `fuzz.yml` | Fuzz / Replay corpus (${{ matrix.name }}) | `make fuzz` | unrestricted | — |
| `fuzz.yml` | Fuzz / Harness self-containment | `make fuzz FUZZTIME=60s` | unrestricted | — |
| `fuzz.yml` | Fuzz / ${{ matrix.harness }} | `make fuzz FUZZTIME=60s` | unrestricted | — |
| `govulncheck.yml` | govulncheck / ${{ matrix.dir }} | `govulncheck ./... in each Go module` | unrestricted | — |
| `install-fuzz.yml` | Fuzz / install.sh | `bash fuzz/install/fuzz_install.sh` | unrestricted | — |
| `install-fuzz.yml` | Open tracking issue on schedule failure | none: opens an issue when the scheduled run fails | unrestricted | — |
| `manual-publish.yml` | Validate Manual (fast — pandoc only) | `bash tools/docs/check-manual.sh && bash tools/docs/build-manual.sh` | unrestricted | — |
| `manual-publish.yml` | Build Manual (9 formats) | `bash tools/docs/check-manual.sh && bash tools/docs/build-manual.sh` | unrestricted | — |
| `manual-publish.yml` | Attach to Release | none: attaches the manual to a release | unrestricted | — |
| `mcp-server-test.yml` | MCP / Test + Coverage (go ${{ matrix.go }}) | `cd defaults/dot_local/share/dot-mcp && go test ./... && go vet ./...` | unrestricted | — |
| `mcp-server-test.yml` | MCP / staticcheck + golangci-lint | `cd defaults/dot_local/share/dot-mcp && go test ./... && go vet ./...` | unrestricted | — |
| `mise-toolchain.yml` | Mise install / ${{ matrix.os }} | `mise install` | unrestricted | — |
| `mutation-nightly.yml` | Mutation / core scripts | `python3 tools/ci/mutation-test.py --full --min-score 90 $(grep -vE '^\s*(#\|$)' tools/ci/mutation-core.txt)` | unrestricted | — |
| `nightly.yml` | Dependency Updates | `make test && make bench` | unrestricted | — |
| `nightly.yml` | Nightly / Test Suite | `make test && make bench` | reusable | — |
| `nightly.yml` | Extended OS Testing (${{ matrix.os }}) | `make test && make bench` | unrestricted | — |
| `nightly.yml` | Beta/Nightly Tools Test | `make test && make bench` | unrestricted | — |
| `nightly.yml` | Extended Security Scan | `make test && make bench` | unrestricted | — |
| `nightly.yml` | Performance Regression Tracking | `make test && make bench` | unrestricted | — |
| `nightly.yml` | Nightly Summary Report | none: aggregates the jobs above | unrestricted | — |
| `npm-publish.yml` | publish-npm | none: publishes on release | unrestricted | — |
| `npm-publish.yml` | publish-gpr | none: publishes on release | unrestricted | — |
| `pages.yml` | Build site (ssg + Lucid) | `make docs` | unrestricted | — |
| `pages.yml` | Deploy to Pages | none: deploys to GitHub Pages | unrestricted | — |
| `perf-baseline.yml` | Perf / Baseline | `bash scripts/diagnostics/perf.sh --json` | unrestricted | — |
| `policy-bundle-release.yml` | Package Policy Bundle | none: packages policy bundles on release (bash tools/release/package-policy-bundles.sh builds them) | unrestricted | — |
| `policy-bundle-release.yml` | Attest Policy Bundle | none: packages policy bundles on release (bash tools/release/package-policy-bundles.sh builds them) | unrestricted | — |
| `policy-bundle-release.yml` | Policy Bundle Release Summary | none: packages policy bundles on release (bash tools/release/package-policy-bundles.sh builds them) | unrestricted | — |
| `policy-test.yml` | Policy / Test + Coverage (go ${{ matrix.go }}) | `cd defaults/dot_local/share/dot-policy && go test ./... && go vet ./...` | unrestricted | — |
| `policy-test.yml` | Policy / staticcheck + golangci-lint | `cd defaults/dot_local/share/dot-policy && go test ./... && go vet ./...` | unrestricted | — |
| `pr-signature.yml` | Verify PR description signature | none: checks the pull request description on GitHub | allow-listed | — |
| `pre-commit.yml` | Pre-Commit | `pre-commit run --all-files --config config/pre-commit-config.yaml` | unrestricted | — |
| `regression-trace-audit.yml` | audit | `bash tools/ci/check-regression-traceability.sh` | unrestricted | — |
| `release-attestation-check.yml` | Verify last release has full attestation bundle | none: checks a published release's attestations | unrestricted | — |
| `release-distribute-aur.yml` | Distribute AUR Package | none: publishes to the AUR on release | allow-listed | `AUR_SSH_KEY` |
| `release-distribute-homebrew.yml` | Distribute Homebrew Formula | none: opens the tap pull request on release | allow-listed | `TAP_PUSH_TOKEN` |
| `release-distribute-scoop.yml` | Distribute Scoop Manifest | none: updates the bucket on release | allow-listed | `TAP_PUSH_TOKEN` |
| `release-install-smoke.yml` | Clean install / ${{ matrix.os }} | `make DESTDIR=/tmp/stage install installcheck uninstall` | unrestricted | — |
| `release-package-dot.yml` | Package dot CLI tarball + zip | none: builds and signs release archives (workflow_dispatch with dry_run builds without publishing) | unrestricted | — |
| `reliability-gate.yml` | Reliability / ${{ matrix.os }} | `bash scripts/qa/reliability-audit.sh --with-integration` | unrestricted | — |
| `reliability-gate.yml` | Examples Contract | `make examples` | unrestricted | — |
| `reliability-gate.yml` | Feature Matrix | `bash scripts/qa/check-feature-matrix.sh` | unrestricted | — |
| `reliability-gate.yml` | WSL Contract | `bash scripts/qa/wsl-contract.sh` | unrestricted | — |
| `reliability-gate.yml` | PowerShell Contract | `pwsh scripts/qa/powershell-contract.ps1` | unrestricted | — |
| `reliability-gate.yml` | Reliability Summary | none: aggregates the jobs above | unrestricted | — |
| `reusable-copyright-lint.yml` | Copyright Headers | `make lint-copyright` | unrestricted | — |
| `reusable-lua-lint.yml` | Lua Lint | `luacheck . && stylua --check .` | unrestricted | — |
| `reusable-nix-lint.yml` | Nix Lint | `nix flake check` (root and nix/) | unrestricted | — |
| `reusable-secrets-scan.yml` | Secrets Scan | `gitleaks detect --config config/gitleaks.toml` | unrestricted | — |
| `reusable-security-baseline.yml` | Security Baseline | `make sbom` | allow-listed | — |
| `reusable-shell-lint.yml` | Shell Lint | `make lint-shell` | unrestricted | — |
| `reusable-test-suite.yml` | Test Suite | `RUN_INTEGRATION=1 ./tests/framework/test_runner.sh --jobs auto` | unrestricted | — |
| `rust.yml` | Test / ${{ matrix.toolchain }} / ${{ matrix.os }} | `cd lib/wasm-tools && cargo test` | unrestricted | — |
| `rust.yml` | WebAssembly / wasm32-wasip1 under wasmtime | `cd lib/wasm-tools && cargo build --target wasm32-wasip1` | unrestricted | — |
| `rust.yml` | Lint / rustfmt | `cd lib/wasm-tools && cargo fmt --check` | unrestricted | — |
| `rust.yml` | Lint / clippy (pedantic) | `cd lib/wasm-tools && cargo clippy --all-targets` | unrestricted | — |
| `rust.yml` | Docs / rustdoc -D warnings | `cd lib/wasm-tools && cargo doc --no-deps` | unrestricted | — |
| `rust.yml` | Coverage / llvm-cov >= 98% | `cd lib/wasm-tools && cargo test` | unrestricted | — |
| `rust.yml` | Miri / nightly | `cd lib/wasm-tools && cargo test` | unrestricted | — |
| `rust.yml` | Fuzz / ${{ matrix.target }} | `cd lib/wasm-tools && cargo test` | unrestricted | — |
| `rust.yml` | Bench / criterion smoke | `cd lib/wasm-tools && cargo test` | unrestricted | — |
| `rust.yml` | Examples / run all | `cd lib/wasm-tools && cargo test` | unrestricted | — |
| `rust.yml` | Supply chain / cargo-deny | `cd lib/wasm-tools && cargo deny check` | unrestricted | — |
| `rust.yml` | Supply chain / cargo-audit | `cd lib/wasm-tools && cargo audit` | unrestricted | — |
| `sbom-diff.yml` | SBOM / Diff | `make sbom && grype sbom:build/sbom.cyclonedx.json` | unrestricted | — |
| `sbom-diff.yml` | SBOM / CVE Scan | `make sbom && grype sbom:build/sbom.cyclonedx.json` | unrestricted | — |
| `scorecard.yml` | Scorecard / Analysis | `scorecard --local .` (needs the OpenSSF binary) | unrestricted | `SCORECARD_TOKEN` |
| `scorecard.yml` | Scorecard / Regression Tracker | none: compares the result with the last snapshot | unrestricted | — |
| `security-enhanced.yml` | Security / Secrets Detection | `detect-secrets scan --baseline .secrets.baseline` | reusable | — |
| `security-enhanced.yml` | Security / TruffleHog OSS | `trufflehog filesystem .` | unrestricted | — |
| `security-enhanced.yml` | Security / Dependencies | `detect-secrets scan --baseline .secrets.baseline` | unrestricted | — |
| `security-enhanced.yml` | Security / Infrastructure | `checkov -d . --framework dockerfile,yaml,secrets --skip-path fuzz/oss-fuzz/` | unrestricted | — |
| `security-enhanced.yml` | Security / Container | `detect-secrets scan --baseline .secrets.baseline` | unrestricted | — |
| `security-enhanced.yml` | Security / Policy Enforcement | `bash scripts/security/enforce-policies.sh` | reusable | — |
| `security-enhanced.yml` | Security / Attestation | `detect-secrets scan --baseline .secrets.baseline` | unrestricted | — |
| `security-enhanced.yml` | Security Summary | none: aggregates the jobs above | unrestricted | — |
| `security-release.yml` | Release / SBOM | none: SBOM, signatures and provenance for a release | unrestricted | — |
| `security-release.yml` | Release / Signed Asset Manifest | none: SBOM, signatures and provenance for a release | unrestricted | — |
| `security-release.yml` | Release / SLSA Provenance | none: SBOM, signatures and provenance for a release | reusable | — |
| `security-release.yml` | Release / Verify Integrity | none: SBOM, signatures and provenance for a release | unrestricted | — |
| `sync-versions.yml` | Verify Version Sync | `./scripts/version-sync.sh --verify` | allow-listed | — |
| `sync-versions.yml` | Verify Version Sync (Protected Branch) | `./scripts/version-sync.sh --verify` | allow-listed | — |
| `sync-versions.yml` | Sync Version Numbers | `./scripts/version-sync.sh --verify` | allow-listed | — |
| `theme-contracts.yml` | Theme renders / ${{ matrix.os }} | `bash tests/unit/theme/test_render_goldens.sh && python3 scripts/theme/check-render-goldens.py` | unrestricted | — |
| `update-deps.yml` | Update Dependencies | none: scheduled dependency update | unrestricted | — |
| `update-deps.yml` | Update Neovim Plugins | none: scheduled dependency update | unrestricted | — |
| `verify-gpg-wkd.yml` | Verify in-repo ↔ WKD fingerprint | `bash scripts/security/check-disclosure-key-expiry.sh` | unrestricted | — |
| `verify-tag-signature.yml` | Signed annotated tag | `git -c gpg.ssh.allowedSignersFile=KEYS.asc tag -v <tag>` | allow-listed | — |

<!-- END GENERATED -->

### Release-only (not reproducible on a branch)

`release-package-dot.yml`, `release-distribute-{aur,homebrew,scoop}.yml`,
`release-install-smoke.yml`, `release-attestation-check.yml`,
`security-release.yml`, `npm-publish.yml`, `policy-bundle-release.yml`.

Every one of these has a `workflow_dispatch` trigger, and
`release-package-dot.yml` has a **`dry_run` input** that builds,
checksums, SBOMs and attests without publishing anything — use it
before the first run of any new release machinery. The install
contract itself *is* locally reproducible:

```bash
make DESTDIR=/tmp/stage install
make DESTDIR=/tmp/stage installcheck
make DESTDIR=/tmp/stage uninstall
```

### Maintenance-only

`update-deps.yml`, `drift-detection.yml`,
`devcontainer-prebuild.yml` — scheduled housekeeping with no local
equivalent worth running by hand.

Same-repository reusable workflows use `./.github/workflows/...`, so a pull
request executes the reusable definition from its own commit and no pin-bump
workflow is needed. External actions and reusable workflows remain SHA-pinned.

---

## Generated artefacts

These are generated from the plugin manifests
(`plugins/<domain>/dot-plugin.toml`, through the command table) and
gated against drift. Never hand-edit the outputs:

| Output | Generator | Gate |
|---|---|---|
| `lib/dot/data/commands.txt`, `lib/dot/data/commands.json`, `plugins/<domain>/commands.txt` | `tools/ci/cli_command_table.py` | `core-contracts.yml` (`tools/ci/check-cli-contract.py`) |
| `docs/manual/command-index.md` | `tools/docs/generate-command-index.sh` | `doc-drift.yml` |
| `examples/command-reference.txt` | `tools/docs/generate-command-reference.sh` | `doc-drift.yml` |
| `share/man/man1/dot.1` and one `dot-<domain>.1` per domain | `tools/docs/generate-manpage.sh` (prose in `tools/docs/man/dot.1.in`) | `doc-drift.yml` |
| `share/powershell/DotCommands.psm1` | `tools/docs/gen_cmdlets.py` | `doc-drift.yml` |
| `share/completions/zsh/_dot`, `defaults/dot_local/share/bash-completion/completions/dot` | `tools/docs/generate-completions.sh` → `dot cli completion show <shell>` | `doc-drift.yml` |
| `AGENTS.md` and the per-harness stubs | `dot agent context apply` (from `CLAUDE.md`) | `dot agent context check` |

```bash
make generate     # regenerate everything
make check-drift  # fail if anything is stale (what CI does)
```

The release tarball generates the man page and all three completions
at build time (`tools/release/stage-dot.sh`), so a packaged install can
never ship a page that drifted from the CLI.

---

## The release model

Versioning is SemVer-shaped (`0.2.PATCH` during 0.x), with a single
source of truth: `dotfiles_version` in `defaults/.chezmoidata.toml`.
Every human-visible version surface is checked against it by
`scripts/verify-release-versions` on every push to `main`.

The stability axis and deprecation window are stated in the README;
the short version is that the `dot` CLI's *output* is part of the
contract, not just its flags.

```bash
# 1. Bump the manifest, then propagate. NEW is the version you are
#    releasing, e.g. NEW=0.2.520
$EDITOR defaults/.chezmoidata.toml
./scripts/version-sync.sh
bash scripts/verify-release-versions

# 2. Update CHANGELOG.md (Keep-a-Changelog; heading per release).

# 3. Prove it green.
make check

# 4. Tag — signed, annotated. Unsigned tags are rejected by CI.
git tag -s "v$NEW" -m "dotfiles v$NEW"

# 5. Dry-run the pipeline BEFORE pushing the tag.
gh workflow run release-package-dot.yml -f release_tag="v$NEW" -f dry_run=true

# 6. Push.
git push origin "v$NEW"
```

What happens then, in order: `release-package-dot.yml` builds the
deterministic tarball + zip, SHA256SUMS, a CycloneDX SBOM and a
sigstore bundle, and attaches SLSA build provenance;
`security-release.yml` adds the SPDX SBOM, the signed unified
`ALL_SHA256SUMS` manifest and SLSA provenance;
`release-distribute-*.yml` bump Homebrew, Scoop and AUR;
`release-install-smoke.yml` proves a clean install on Linux and macOS.
Full diagram: [`docs/operations/RELEASE_PIPELINE.md`](docs/operations/RELEASE_PIPELINE.md).
Consumer-side verification: [`pkg/VERIFY.md`](pkg/VERIFY.md).
