---
render_with_liquid: false
---

<!-- SPDX-License-Identifier: Apache-2.0 OR MIT -->
<!-- Copyright (c) 2015-2026 Sebastien Rousseau -->

# Gold-standard audit

Scoring of this repository against the eight categories of the
repository gold standard, before and after the `feat/gold-standard`
work. Every row carries evidence — a file path, a workflow name, or a
command — so a claim here can be checked rather than believed.

Rubric: **1–3** absent or tribal knowledge · **4–6** exists but manual,
partial, or not CI-enforced · **7–8** solid, minor gaps, enforced ·
**9** enforced and documented with rationale · **10** a newcomer, a
packager, and a security auditor each get what they need without
asking anyone.

## Scores

| # | Category | Before | After | Remaining gap |
|---|---|:---:|:---:|---|
| 1 | Identity and README | 6 | 9 | README owned by a separate change; the Repology badge waits on ≥2 distros tracking the package |
| 2 | Documentation | 7 | 10 | — |
| 3 | Build and install UX | 4 | 10 | — |
| 4 | Releases and pre-built binaries | 7 | 9 | New release machinery has not yet run live; the target-matrix item does not apply to a shell project |
| 5 | Packaging and distribution | 5 | 8 | No deb/rpm recipe; nothing submitted to Debian/Fedora/nixpkgs; reproducibility is deterministic archiving, not a verified claim |
| 6 | Quality gates in CI | 8 | 9 | Coverage floor 58%; no API-breakage equivalent for a shell CLI beyond the snapshot tests |
| 7 | Supply chain and security | 7 | 10 | — |
| 8 | Community and governance | 7 | 10 | — |

Two categories moved the most: **build and install UX** (4 → 10),
where `make install` previously shipped no man page and no completions
and the installed binary could not find its own source tree; and
**supply chain** (7 → 10), where the per-file licence headers
contradicted the licence the project actually grants.

---

## 1. Identity and README — 6 → 9

README.md itself is owned by a separate change; this section scores the
material that supports it.

| Item | Before | After | Evidence |
|---|---|---|---|
| Badge row, install methods, quick start | Present | Present | `README.md` |
| Requirements stated **and** CI-enforced | Number only | Policy + table + matrix | `docs/MINIMUM-TOOLCHAIN.md`; floors mapped to the jobs that prove them |
| Four documentation links available to point at | 2 of 4 existed | All four exist | `docs/manual/`, `docs/ARCHITECTURE.md`, `DEVELOPMENT.md`, `docs/ECOSYSTEM.md` |
| Minimum-toolchain **policy**, not just a number | Absent | Present | `docs/MINIMUM-TOOLCHAIN.md` — when a floor may rise, on which axis, and the distro table with an honest "in CI?" column |
| Stability / security sections have targets | Partial | Present | `SECURITY.md`, `docs/security/FUZZING.md`, `supply-chain/README.md` |
| Versions in install snippets CI-checked | 8 surfaces | 16 surfaces | `scripts/verify-release-versions`, gated by `doc-drift.yml` |

**Why not 10:** README.md is another change's remit, and the Repology
badge is legitimately blocked until at least two distributions track
the package.

## 2. Documentation — 7 → 10

| Item | Before | After | Evidence |
|---|---|---|---|
| `docs/` as the single root | Yes | Yes | `mkdocs.yml`, `docs_dir: docs` |
| Rendered manual deployed to Pages | Yes | Yes | `pages.yml`, `manual-publish.yml`, doc.dotfiles.io |
| Root `DEVELOPMENT.md` | **Missing** | Present | `DEVELOPMENT.md` — toolchain setup, test layout, release model, and all 51 workflows mapped to local commands |
| `docs/ARCHITECTURE.md` at the canonical path | At `docs/architecture/` | Canonical, pointer left behind | `docs/ARCHITECTURE.md` |
| ADRs | 12 | 12 | `docs/adr/` |
| Migration guides per competitor | **None** | 4 | `docs/migration/` — yadm, GNU Stow, bare git repo, plain chezmoi |
| Link check gating CI | Advisory only (`fail: false`, schedule-only) | Gating | `docs-link-check.yml` job *Docs / Link Check (offline, gating)* |

**Verified:** `lychee --config config/lychee.toml --offline '**/*.md'`
→ 0 errors over 386 unique links, after fixing a real broken link in
`GOVERNANCE.md` that pointed at a `LICENSE` file removed by the
relicensing.

## 3. Build and install UX — 4 → 10

The weakest category before, and the one with the most user-visible
bugs.

| Item | Before | After | Evidence |
|---|---|---|---|
| `Makefile` for dev tasks | Mixed dev + install, 6 targets | Dev only, 20 targets with `make help` | `Makefile` |
| `GNUmakefile` with the Unix contract | **Missing** | Present | `GNUmakefile` — `PREFIX` (default `/usr/local`), `DESTDIR`, and per-directory overrides |
| FHS paths incl. `share/man/man1` and completions | **Bin symlink only** | Full FHS tree | `GNUmakefile` install target |
| Manpages generated from the CLI definitions | **Hand-written, drifted** | Generated + drift-gated | `tools/docs/generate-manpage.sh`, `doc-drift.yml` job *Generators / man page* |
| Completions generated, not hand-maintained | **Hand-written, disagreed with the registry and each other** | Generated + drift-gated | `tools/docs/generate-completions.sh`, `doc-drift.yml` job *Generators / completions* |
| CI smoke: `make DESTDIR=… install` on a clean runner | Existed for the tarball | Plus `make installcheck` | `release-install-smoke.yml`; `GNUmakefile` `installcheck` |

Four real bugs were found by making these gates work, not by reading
the code:

1. `make install` placed only a `bin` symlink — `man dot` did not work
   after installing, and no shell picked up completions.
2. `bin/dot` did not resolve symlinks, so the installed
   `$(PREFIX)/bin/dot` resolved relative to the link and fell through
   to `~/.dotfiles`, which a packaged install need not have.
3. `stage-dot.sh` copied the fish *function wrapper* into the fish
   vendor completions directory, so every release shipped a no-op
   completion that also shadowed the `dot` command at shell startup.
4. `stage-dot.sh` refused any destination named `dotfiles` — which is
   exactly `$(PREFIX)/lib/dotfiles` — so `make install` failed outright.

The man page went from documenting roughly 40 commands to all 146,
because it is now rendered from the same registry that drives
`dot help all` and `dot completion`.

**Verified:** `make -n DESTDIR=/tmp/stage install` produces a sane
plan; a real staged install places bin, man, three completions and
both licences; `make installcheck` passes; the installed binary runs
from a sandboxed `HOME` with no source checkout; `make uninstall`
leaves zero files; `mandoc -T lint` is clean.

## 4. Releases and pre-built binaries — 7 → 9

| Item | Before | After | Evidence |
|---|---|---|---|
| SemVer, signed tags, Keep-a-Changelog | Yes | Yes | `verify-tag-signature.yml`, `CHANGELOG.md` |
| Tag-triggered automated pipeline | Yes | Yes | `docs/operations/RELEASE_PIPELINE.md` |
| **`workflow_dispatch` dry-run mode** | **Missing** | Present | `release-package-dot.yml` input `dry_run` (defaults to true), artefacts uploaded for inspection |
| Checksums | Docs bundle only | Plus archives | `dot-<version>.SHA256SUMS` |
| Sigstore bundle | On the SBOM only | Per archive, and verified in-workflow | `release-package-dot.yml` *Sign archives* + *Verify the bundles we just produced* |
| SLSA attestation | Yes | Yes | `actions/attest-build-provenance` |
| **SBOM (CycloneDX)** | SPDX only | Both formats | `release-package-dot.yml`; `security-release.yml` |
| Publish via OIDC, not long-lived tokens | Yes | Yes | keyless cosign; `id-token: write` |

A latent bug was avoided here: naming the new checksum file
`SHA256SUMS` would have collided with the documentation bundle's
existing asset of that name and, with `--clobber`, silently destroyed
it. Hence `dot-<version>.SHA256SUMS`.

**Why not 10:** the new machinery has not yet run against a live tag —
which is precisely what the `dry_run` input exists to de-risk. The
"pre-built binaries across a target matrix, musl static" item does not
apply: this is a shell framework, and its `noarch` archive already
runs everywhere the interpreter does.

## 5. Packaging and distribution — 5 → 8

| Item | Before | After | Evidence |
|---|---|---|---|
| `pkg/` with one directory per format | Templates under `install/` | `pkg/` | `pkg/{aur,brew,scoop,nix,docker}`, `pkg/README.md` |
| `docs/packaging.md` for distro maintainers | **Missing** | Present | `docs/packaging.md` |
| Signature-verification guide for packagers | Scattered | Single page | `pkg/VERIFY.md` |
| Container image, digest-pinned | No image | Documented decision | `pkg/docker/README.md` |
| Reproducible-builds statement | Implicit | Scoped honestly | `docs/packaging.md` — "deterministic archiving", explicitly *not* a reproducible-builds certification, because no diffoscope comparison runs |

**Why not 10:** no deb or rpm recipe ships; nothing has been submitted
to Debian, Fedora or nixpkgs; and the reproducibility claim is
deliberately narrow. **Exact remaining step:** add `pkg/deb/` and
`pkg/rpm/` recipes over `make install`, then file the first
submission — the `DESTDIR` tree they need is already correct.

## 6. Quality gates in CI — 8 → 9

| Item | Before | After | Evidence |
|---|---|---|---|
| OS matrix | Yes | Yes | `cross-platform-test.yml`: ubuntu, macos-latest, macos-14; windows for the PowerShell contract |
| Lint at zero warnings | Yes | Yes | `ci-enforced.yml` |
| Docs build with warnings denied | Yes | Yes | `pages.yml` (`mkdocs build --strict`) |
| Coverage gate at a stated threshold | 58%, rationale in-workflow | Same, now documented for contributors | `coverage.yml`; `DEVELOPMENT.md` |
| Fuzz targets + **regression corpus replayed per push** | Corpus replayed only inside the long fuzz jobs, and only on four path filters | Dedicated fast replay job | `fuzz.yml` job *Fuzz / corpus replay* |
| Examples executed in CI (docs that run) | Already gated | Unchanged, confirmed | `reliability-gate.yml` job *Examples Contract* → `scripts/qa/validate-examples.sh`, on every push and PR |
| Benchmarks smoke-run | `2>/dev/null \|\| true` in `ci.yml` | Plus a real target | `make bench`; `benches/README.md` |
| Generated-artefact drift | 2 gates | 4 gates | `doc-drift.yml` |

**Why not 10:** the coverage floor is 58% rather than a number chosen
for a stated risk model, and there is no API-breakage check — for a
shell CLI the nearest equivalent is the snapshot tests in
`tests/snapshots/`, which cover output but not every flag.
**Exact remaining step:** ratchet the coverage floor with a written
rationale per slice, and extend snapshot coverage to the full flag
surface.

## 7. Supply chain and security — 7 → 10

| Item | Before | After | Evidence |
|---|---|---|---|
| `SECURITY.md` with private channel and SLA | At `.github/` | At the root, pointer left behind | `SECURITY.md` |
| Dependency review + advisory audit | Yes | Yes | `dependency-review.yml`, `deps-dev-validation.yml`, `sbom-diff.yml` |
| Dependency **provenance policy** | Scattered across three docs | One directory, each rule mapped to its enforcing job | `supply-chain/README.md` |
| Everything pinned | Yes | Yes | `tools/ci/lint-reusable-pins.sh` — 16 call sites, 0 failures |
| Scorecard workflow and badge | Yes | Yes | `scorecard.yml` |
| CII best-practices self-assessment | Badge + tracking page | Unchanged | `docs/security/SCORECARD.md` |
| **Signing keys published (`KEYS.asc`)** | **Missing** | Present, with a verified guide | `KEYS.asc` |
| **REUSE/SPDX compliance, linted in CI** | **Non-compliant** | Compliant and gated | `REUSE.toml`, `LICENSES/`, `docs-link-check.yml` job *Docs / REUSE lint* |

The significant finding: commit `21f15024` relicensed the project to
`Apache-2.0 OR MIT` — both licence files ship and `package.json`
declares the pair — but the per-file SPDX headers were never swept.
**898 files still declared bare `MIT`**, a narrower grant than the
project offers and the statement a downstream licence scanner would
actually rely on. After the sweep: **0**, with 916 files declaring the
dual grant, and two independent gates so it cannot recur —
`reuse lint` proves every file *has* licensing information, and
`tools/ci/normalize-spdx-headers.sh --check` proves it is the *right*
grant, with the expected value read from `package.json` rather than
hardcoded.

`KEYS.asc` was verified rather than assumed: with the file,
`git -c gpg.ssh.allowedSignersFile=KEYS.asc tag -v v0.2.519` prints
`Good "git" signature for sebastian.rousseau@gmail.com`; without it,
`No principal matched`. Every command in its guide was run before it
was committed.

## 8. Community and governance — 7 → 10

| Item | Before | After | Evidence |
|---|---|---|---|
| CODE_OF_CONDUCT, CONTRIBUTING, GOVERNANCE | Present | Present | root |
| **SUPPORT.md** | **Missing** | Present | `SUPPORT.md` |
| Issue + PR templates | Present | Present | `.github/ISSUE_TEMPLATE/`, `PULL_REQUEST_TEMPLATE.md` |
| **CITATION.cff** | **Missing** | Present, validated | `CITATION.cff`; `cffconvert --validate` |
| `AGENTS.md` | Present | Present | `AGENTS.md`, generated from `CLAUDE.md` |
| `.editorconfig`, pre-commit, markdownlint + codespell | codespell unconfigured | Configured and clean | `config/codespellrc`, `config/markdownlint-cli2.jsonc` |
| `.devcontainer/` booting to a working `make` | Present | Present | `.devcontainer/` |
| Family table for multi-repo layouts | **Missing** | Present | `docs/ECOSYSTEM.md` |

`docs/ECOSYSTEM.md` answers the family-table item for a repository
that is deliberately singular: what lives in-repo, the three tap
repositories that must be separate because their tooling demands it,
and the case for each of MCP, LSP and WASM — with the command that
checks each claim and a note on what would change the decision.

---

## Gates run

Every gate below was executed in this worktree.

| Gate | Command | Result |
|---|---|---|
| Shell lint | `git ls-files '*.sh' \| xargs shellcheck --severity=error -e SC1091 -e SC2030 -e SC2031` | pass |
| Shell format | `shfmt -d -i 2 -ci` on every added or edited script | pass |
| Markdown | `npx markdownlint-cli2` | 0 issues in 253 files |
| Spelling | `codespell --config config/codespellrc` | pass |
| Spelling | `typos --config config/typos.toml` | pass |
| Copyright + SPDX grant | `bash tools/ci/check-copyright-headers.sh` | 939 files pass |
| SPDX sweep | `bash tools/ci/normalize-spdx-headers.sh --check` | pass |
| REUSE | `reuse lint` | compliant, 1831/1831 files |
| Links | `lychee --config config/lychee.toml --offline '**/*.md'` | 0 errors |
| Action pins | `bash tools/ci/lint-reusable-pins.sh` | 16 call sites, 0 failures |
| Workflow syntax | `actionlint` on every edited workflow | pass |
| Generated-artefact drift | `make check-drift` | 4/4 in sync |
| Version surfaces | `bash scripts/verify-release-versions` | 16/16 match |
| Man page | `mandoc -T lint share/man/man1/dot.1` | clean |
| CFF | `cffconvert --validate` | valid |
| Fuzz corpus | `cd fuzz && go vet ./... && go test ./...` | pass |
| Examples | `bash scripts/qa/validate-examples.sh` | pass |
| Install contract | `make DESTDIR=… install`, `installcheck`, `uninstall` | pass; 0 files left |
| bash 3.2 compatibility | CLI, generators and version gate under macOS `/bin/bash` 3.2.57 | pass |
| Tag signature | `git -c gpg.ssh.allowedSignersFile=KEYS.asc tag -v v0.2.519` | Good signature |

## Standing caveats

Recorded so the scores above are not read as more than they are:

- The release additions (dry-run, checksums, CycloneDX SBOM, sigstore
  bundles) are **verified by workflow linting and local equivalents,
  not by a live release run**. The `dry_run` input exists to be
  exercised before the first live use.
- `docs/MINIMUM-TOOLCHAIN.md` marks Debian, RHEL and Fedora as
  *expected but unverified*, because no job in CI runs on them. That
  is a deliberate refusal to make an unbacked distro-LTS claim, not an
  oversight.
- The reproducibility statement covers **deterministic archiving**
  only.
- Coverage is gated at 58%, a measured floor rather than a target.
