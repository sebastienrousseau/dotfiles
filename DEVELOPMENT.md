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
pre-commit install --config config/pre-commit-config.yaml
pre-commit run --all-files --config config/pre-commit-config.yaml
```

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
| `bin/dot` | CLI dispatcher **and the command registry** — `_dot_help_specs`, `_dot_help_details`, `_dot_command_routes`. Adding a command means editing these. |
| `scripts/dot/commands/` | One file per subcommand. |
| `lib/dot/` | Shared bash library sourced by every subcommand. |
| `defaults/` | The chezmoi source tree (everything that lands in `$HOME`), rebased via `.chezmoiroot`. |
| `tests/` | `framework/`, `unit/`, `integration/`, `regression/`, `snapshots/`. |
| `benches/` | Benchmarks. Smoke-run, not asserted. |
| `fuzz/` | Go fuzz harnesses, committed regression corpus, OSS-Fuzz scaffolding. |
| `pkg/` | One directory per packaging format, rendered per release. |
| `tools/` | Repo-only ops: CI helpers, doc generators, release staging. Never ships to users. |
| `supply-chain/` | Provenance policy and the allowlists CI enforces. |

Adding a `dot` subcommand touches four places; the drift gates will
tell you if you miss one:

1. `scripts/dot/commands/<name>.sh` — the implementation
2. `bin/dot` — a `_dot_command_routes` row and a `_dot_help_specs` row
3. `docs/manual/03-reference/01-dot-cli.md` — reference prose
4. `make generate` — regenerates the command index, man page, completions

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
| `tests/unit/<domain>/` | `test_<feature>.sh` | 19 domains. Fast, no network, no `$HOME` writes. |
| `tests/integration/` | End-to-end install/apply | Needs a sandbox; gated behind `RUN_INTEGRATION=1`. |
| `tests/regression/` | Guardrails for fixed bugs | **Must** carry a `# Regression for: GH-1234` header in the first 15 lines (enforced by a pre-commit hook and audited weekly). |
| `tests/snapshots/` | Golden CLI output | Fix the CLI, do not regenerate blindly. |
| `benches/` | Performance | Not asserted; see `benches/README.md`. |
| `fuzz/` | Fuzz harnesses + corpus | `make fuzz`; see `fuzz/README.md`. |

Tests execute shell source files directly, so **never** put Go template
syntax in a non-`.tmpl` file — the runner chokes on the braces.

Coverage is gated at **58%** (`MIN_COVERAGE_PCT` in `coverage.yml`).
The rationale is recorded there: it is the measured floor of the
xtrace-instrumented aggregate, chosen once and ratcheted deliberately,
rather than an aspirational number that would be permanently red.

---

## Reproducing every CI gate locally

51 workflows. Most are one of a handful of scripts; the table maps each
to the command that reproduces it. `make check` runs the everyday
subset (lint + drift + test + examples) in one go.

### Lint and formatting

| Workflow | Job | Locally |
|---|---|---|
| `ci.yml` | Lint / Shell | `make lint-shell` (`shellcheck -x --severity=error -e SC1091 -e SC2030 -e SC2031` over `*.sh`) |
| `ci.yml` | Lint / Shell (format) | `shfmt -d -i 2 -ci scripts install.sh defaults/.chezmoitemplates` (CI's `shfmt_targets`; `make lint-shell-all` is the repo-wide superset) |
| `ci.yml` | Lint / Lua | `luacheck .` and `stylua --check .` |
| `ci.yml` | Lint / Fish | `fish --no-execute <file>` per fish file |
| `ci.yml` | Lint / Nushell | `nu --commands 'source <file>'` per nu file |
| `ci.yml` | Lint / Copyright | `bash tools/ci/check-copyright-headers.sh` |
| `ci.yml` | Lint / Reusable Workflow Pins | `bash tools/ci/lint-reusable-pins.sh` |
| `ci.yml` | Lint / Chezmoidata Schema | `bash tools/ci/validate-chezmoidata.sh` |
| `ci.yml` | Security / Link Check | `lychee --offline '**/*.md'` (see below) |
| `ci-enforced.yml` | Lint / * (zero warnings) | `make lint` |
| `pre-commit.yml` | Pre-Commit | `pre-commit run --all-files --config config/pre-commit-config.yaml` |
| `pre-commit.yml` | actionlint hook | `make lint-workflows` (`actionlint -shellcheck=`, matching the hook) |
| `reusable-shell-lint.yml` | Shell Lint | `make lint-shell` |
| `reusable-lua-lint.yml` | Lua Lint | `luacheck . && stylua --check .` |
| `reusable-nix-lint.yml` | Nix Lint | `nix flake check` (root and `nix/`) |
| `reusable-copyright-lint.yml` | Copyright Headers | `make lint-copyright` |
| `docs-link-check.yml` | Docs / Link Check | `make lint-links` |
| `docs-link-check.yml` | Docs / REUSE lint | `make lint-reuse` |

### Tests

| Workflow | Job | Locally |
|---|---|---|
| `ci.yml` | Test / * | `make test` |
| `ci-enforced.yml` | Test / Unit Tests | `make test-unit` |
| `reusable-test-suite.yml` | Test Suite | `RUN_INTEGRATION=1 ./tests/framework/test_runner.sh --jobs auto` |
| `reliability-gate.yml` | Reliability / * | `bash scripts/qa/reliability-audit.sh --with-integration` |
| `reliability-gate.yml` | Examples Contract | `make examples` |
| `reliability-gate.yml` | WSL Contract | `bash scripts/qa/wsl-contract.sh` |
| `reliability-gate.yml` | PowerShell Contract | `pwsh scripts/qa/powershell-contract.ps1` |
| `cross-platform-test.yml` | Test on \<os\> | `bash -n` over every `.sh`, then `bash scripts/diagnostics/health.sh` |
| `coverage.yml` | Coverage / kcov | `MIN_COVERAGE_PCT=58 bash tools/ci/run-coverage.sh` |
| `cockpit-test.yml` | Cockpit / Go Tests | `cd defaults/dot_local/share/dot-ai-tui && go test ./...` |
| `dot-ui-test.yml` | dot-ui / Go Tests | `cd defaults/dot_local/share/dot-ui && go test ./...` |
| `mcp-server-test.yml` | MCP Server / Go Tests | `cd defaults/dot_local/share/dot-mcp && go test ./...` |
| `nightly.yml` | Weekly extended | `make test` plus `make bench` |

### Fuzzing

| Workflow | Job | Locally |
|---|---|---|
| `fuzz.yml` | Fuzz / corpus replay | `make fuzz` |
| `fuzz.yml` | Fuzz / \<harness\> | `make fuzz FUZZTIME=60s` |
| `cflite_pr.yml` | ClusterFuzzLite | `make fuzz FUZZTIME=120s` (same harnesses; the action needs Docker) |
| `install-fuzz.yml` | Fuzz / install.sh | `bash fuzz/install/fuzz_install.sh` |

### Docs and generated artefacts

| Workflow | Job | Locally |
|---|---|---|
| `doc-drift.yml` | Generators / command-index | `bash tools/docs/generate-command-index.sh --check` |
| `doc-drift.yml` | Generators / man page | `bash tools/docs/generate-manpage.sh --check` |
| `doc-drift.yml` | Generators / completions | `bash tools/docs/generate-completions.sh --check` |
| `doc-drift.yml` | Generators / version-consistency | `bash scripts/verify-release-versions` |
| `sync-versions.yml` | Verify Version Sync | `./scripts/version-sync.sh --verify` |
| `pages.yml` | Build site | `make docs` (`mkdocs build --strict`) |
| `manual-publish.yml` | Validate + Build Manual | `bash tools/docs/check-manual.sh` then `bash tools/docs/build-manual.sh` |
| — | all four drift gates at once | `make check-drift` |

### Security and supply chain

| Workflow | Job | Locally |
|---|---|---|
| `ci.yml` | Security / Secrets Scan | `gitleaks detect --config config/gitleaks.toml` |
| `ci.yml` | Security / SBOM Generation | `make sbom` |
| `security-enhanced.yml` | Secrets Detection | `detect-secrets scan --baseline .secrets.baseline` |
| `security-enhanced.yml` | TruffleHog OSS | `trufflehog filesystem .` |
| `security-enhanced.yml` | Infrastructure | `checkov -d . --framework dockerfile,yaml,secrets --skip-path fuzz/oss-fuzz/` |
| `security-enhanced.yml` | Policy Enforcement | `bash scripts/security/enforce-policies.sh` |
| `compliance-guard.yml` | Insecure Patterns | `bash tools/ci/check-insecure-tls.sh` + `bash tools/ci/check-dangerous-chmod.sh` |
| `compliance-guard.yml` | Dockerfile Lint | `hadolint $(git ls-files '*Dockerfile*')` |
| `compliance-guard.yml` | Verify Commit Signatures | `git log --format='%G?' origin/main..HEAD` (expect `G` on every line) |
| `deps-dev-validation.yml` | deps.dev / direct deps | `bash tools/ci/check-deps-dev.sh` |
| `sbom-diff.yml` | SBOM / Diff + CVE Scan | `make sbom` then `grype sbom:build/sbom.cyclonedx.json` |
| `codeql.yml` | Security / CodeQL | Not reproducible locally without the CodeQL CLI; run `codeql database create` if you have it |
| `scorecard.yml` | Scorecard / Analysis | `scorecard --local .` (needs the OpenSSF binary) |
| `dependency-review.yml` | Dependency Review | PR-only, GitHub-side; no local equivalent |
| `verify-gpg-wkd.yml` | in-repo ↔ WKD fingerprint | `bash scripts/security/check-disclosure-key-expiry.sh` |
| `verify-tag-signature.yml` | Signed annotated tag | `git -c gpg.ssh.allowedSignersFile=KEYS.asc tag -v <tag>` |
| `dco.yml` | Check sign-off | `git log --format='%(trailers:key=Signed-off-by)' origin/main..HEAD` (no empty lines) |
| `pr-signature.yml` | PR description signature | GitHub-side; check the PR body before pushing |
| `regression-trace-audit.yml` | Regression traceability | `bash tools/ci/check-regression-traceability.sh` |

### Performance

| Workflow | Job | Locally |
|---|---|---|
| `dot-cli-bench.yml` | dot CLI cold start | `DOT_BENCH_BUDGET_MS=150 DOT_BENCH_RUNS=11 bash tools/ci/dot-cli-startup-bench.sh` |
| `perf-baseline.yml` | Perf / Baseline | `bash scripts/diagnostics/perf.sh --json` |
| — | benchmarks | `make bench` |

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

`bump-reusable-pins.yml`, `update-deps.yml`, `drift-detection.yml`,
`mirror-main-to-master.yml`, `devcontainer-prebuild.yml` — scheduled
housekeeping with no local equivalent worth running by hand.

---

## Generated artefacts

Four things are generated from the command registry in `bin/dot` and
gated against drift. Never hand-edit the outputs:

| Output | Generator | Gate |
|---|---|---|
| `docs/manual/command-index.md` | `tools/docs/generate-command-index.sh` | `doc-drift.yml` |
| `share/man/man1/dot.1` | `tools/docs/generate-manpage.sh` (prose in `tools/docs/man/dot.1.in`) | `doc-drift.yml` |
| `share/completions/zsh/_dot`, `defaults/dot_local/share/bash-completion/completions/dot` | `tools/docs/generate-completions.sh` → `dot completion <shell>` | `doc-drift.yml` |
| `AGENTS.md` and the per-harness stubs | `dot agents render` (from `CLAUDE.md`) | `dot agents check` |

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
Sixteen human-visible surfaces are checked against it by
`scripts/verify-release-versions` on every push.

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
