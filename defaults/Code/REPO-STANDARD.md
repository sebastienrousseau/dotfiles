# Repository Gold Standard — the 10/10 template

A language-agnostic checklist and phase recipe for bringing any repository
to top marks in structure, documentation, distribution, and trust.
Distilled from the noyalib-vs-uutils/coreutils audit (2026-09-02); apply
it to any repo (Rust, shell, JS, Python) by filling the placeholders.

**Placeholders:** `{{PROJECT}}` name · `{{BUILD}}` native build tool
(cargo, npm, uv, go) · `{{REGISTRY}}` package registry (crates.io, npm,
PyPI) · `{{API_DOCS}}` generated API reference (docs.rs, typedoc,
sphinx) · `{{BIN}}` the CLI binary name, if any.

**How to use:** score every category 1–10 against its checklist, put the
scores in a gap table, then run the six phases in order. Each phase is
independently mergeable and ends with acceptance criteria checkable
without reading diffs. Nothing ships unless CI enforces it — a standard
that isn't a CI gate decays.

---

## The eight categories

### 1. Identity and README

Every repo in a family shares one README shape, in this order:

- [ ] Logo/name, one-sentence value proposition, badge row (build,
      registry version, API docs, license, security scorecard)
- [ ] Contents / navigation block
- [ ] **Install** — every method, most frictionless first: pre-built
      binary one-liner, `{{BUILD}} install`, `make install`, distro
      packages
- [ ] **Quick start** — real, runnable code within one screen of the top
- [ ] Requirements (minimum toolchain version, stated + CI-enforced)
- [ ] **Documentation** — the same four links everywhere: User Manual ·
      API reference ({{API_DOCS}}) · Developer docs (DEVELOPMENT.md) ·
      ecosystem/family map
- [ ] When *not* to use this project (honesty section — builds trust)
- [ ] License section (dual grants spelled out) and license + MSRV
      badges in the badge row (SPDX comment at line 1)
- [ ] **Stability guarantees section**: the SemVer breaking axis
      stated explicitly; for parsers/formatters, the output-stability
      rule (a behaviour change to what the tool produces is breaking
      even when no API signature moves); deprecation window
- [ ] **Security & hardening section** leading with the private
      reporting pointer, then the architectural posture (memory
      safety, resource-exhaustion limits) and the fuzzing story
      (targets, per-push regression replay, OSS-Fuzz status)
- [ ] **Minimum-toolchain POLICY**, not just the number: when it may
      raise, on which version axis, and where the reason is recorded.
      Never claim distro-LTS compatibility without a table mapping
      current distro toolchains to the floor — an aspirational claim
      here is worse than none
- [ ] No stale content: versions in install snippets are CI-checked
      against the manifest (a `verify-release-versions` script)

### 2. Documentation

- [ ] `docs/` (never `doc/`) as the single documentation root
- [ ] A **rendered User Manual** (mdBook / Docusaurus / MkDocs) built
      from Markdown that lives in-repo, deployed to Pages on release —
      chapters are *moves of existing files*, not rewrites
- [ ] Root `DEVELOPMENT.md`: toolchain setup, local reproduction of
      every CI gate, test layout, release model — the single dev entry
      point
- [ ] `docs/ARCHITECTURE.md` — how it works, for contributors
- [ ] ADRs (`docs/adr/`) for decisions that will be questioned later
- [ ] Migration guides for every competitor users might come from
- [ ] Link check in CI (broken intra-docs links fail the build)

### 3. Build and install UX

- [ ] `{{BUILD}}`'s native flow works: build, test, install
- [ ] A `Makefile` for dev tasks (test, lint, docs, sbom, clean) —
      the task runner contributors discover by convention
- [ ] For anything shipping a binary: `GNUmakefile` with the Unix
      contract — `make`, `make test`, `make install` / `make uninstall`
      honoring `PREFIX` (default `/usr/local`) and `DESTDIR`, installing
      to FHS paths (bin, `share/man/man1`, completions dirs)
- [ ] Manpages **generated from the CLI definitions** at build time
      (clap_mangen / help2man / argparse-manpage) — never hand-written
      `.1` files that drift from `--help`
- [ ] Shell completions (bash/zsh/fish/powershell) generated, not
      committed
- [ ] CI smoke: `make DESTDIR=/tmp/stage install` produces a correct
      tree on a clean runner

### 4. Releases and pre-built binaries

- [ ] SemVer (or an explicit documented alternative), tags signed,
      CHANGELOG in Keep-a-Changelog form with a heading per release
- [ ] Release pipeline is tag-triggered and fully automated, with a
      `workflow_dispatch` **dry-run mode** exercised before every first
      use of new machinery
- [ ] Pre-built binaries for every release across a target matrix:
      linux gnu + **musl static** (the runs-anywhere artifact) ×
      x86_64/aarch64, macOS both arches, Windows — archives contain the
      binary, manpages, completions, licenses
- [ ] Binaries carry provenance: checksums (SHA256SUMS), sigstore
      bundle, SLSA attestation, dependency list embedded where the
      ecosystem supports it (cargo-auditable)
- [ ] SBOM (CycloneDX) attached to every release
- [ ] Publish to {{REGISTRY}} via trusted publishing / OIDC, not
      long-lived tokens

### 5. Packaging and distribution

- [ ] `pkg/` with one directory per format, generated from the release
      build: deb, rpm, AUR PKGBUILD, Homebrew tap formula, `flake.nix`
- [ ] `docs/packaging.md` **addressed to distro maintainers**: license
      grant, minimum-toolchain policy, dependency pin model, offline
      test instructions (vendored deps), signature verification
- [ ] Submitted where it matters for the language: Debian + Fedora
      team/SIG for libraries, nixpkgs/AUR/brew for CLIs
- [ ] Repology badge once ≥2 distros track it
- [ ] Container image if the tool makes sense containerized, digest-
      pinned base images (Scorecard checks this)
- [ ] For libraries that could serve as a system library: a C-FFI
      evaluation (cdylib + cbindgen headers) as its own satellite,
      decided deliberately, not bolted on
- [ ] Reproducible-builds statement only after verifying it (build
      twice, compare; diffoscope in CI if claimed)

### 6. Quality gates in CI (every push, not weekly)

- [ ] Test matrix across OS × toolchain (stable, minimum version, beta)
- [ ] Lint at zero warnings; formatting checked
- [ ] Docs build with warnings denied; public API 100% documented
- [ ] Coverage gate at a *stated* threshold with a written rationale
      (a threshold chosen once and defended beats chasing 100%)
- [ ] Every feature/flag/config combination built at least singly per
      push (each-feature), pairwise on a schedule (powerset)
- [ ] Where input parsing exists: fuzz targets, a committed seed +
      **fixed-bug regression corpus replayed per push**, and (for the
      ambitious) differential fuzzing against reference implementations
- [ ] Examples and README snippets executed in CI (docs that run)
- [ ] Benchmarks smoke-run (not asserted, just kept compiling)
- [ ] API-breakage check against the last release (cargo-semver-checks
      or the ecosystem equivalent)

### 7. Supply chain and security

- [ ] `SECURITY.md` with a private reporting channel and response SLA
- [ ] Dependency review + advisory audit in CI (cargo-deny/audit,
      osv-scanner, npm audit — whatever the ecosystem has)
- [ ] Dependency **provenance** policy: cargo-vet or equivalent, with
      exemptions regenerated on every dep change
- [ ] Everything pinned: actions by SHA, container bases by digest,
      lockfiles committed and `--locked` in CI
- [ ] OpenSSF Scorecard workflow, badge in README, score ≥ 9 chased
      deliberately; CII best-practices self-assessment
- [ ] Signing keys published (`KEYS.asc`) with a verification guide
- [ ] REUSE/SPDX compliance (every file's license machine-readable),
      linted in CI

### 8. Community and governance

- [ ] CODE_OF_CONDUCT.md, CONTRIBUTING.md, GOVERNANCE.md, SUPPORT.md
- [ ] Issue templates + PR template, consistent across the family
- [ ] `CITATION.cff` for anything citable
- [ ] `AGENTS.md` — the repo's invariants for AI-assisted contributors
      (versioning policy, signing rules, CI-green expectations)
- [ ] `.editorconfig`, pre-commit config, markdownlint + codespell in a
      cheap docs-lint CI job
- [ ] `.devcontainer/` that boots to a working `make` in minutes
- [ ] For multi-repo families: a CI-checked table of which repo has
      what, so the layout can't silently drift

---

## The canonical layout

```
{{PROJECT}}/
├── README.md  CHANGELOG.md  LICENSE-*  DEVELOPMENT.md
├── CODE_OF_CONDUCT.md  CONTRIBUTING.md  GOVERNANCE.md
├── SECURITY.md  SUPPORT.md  AGENTS.md  CITATION.cff  KEYS.asc
├── Makefile            # dev tasks
├── GNUmakefile         # install contract (CLI repos only)
├── docs/               # manual source (mdBook/MkDocs root) + ADRs
├── examples/  benches/  tests/  fuzz/
├── pkg/                # deb/ rpm/ aur/ brew/ nix/ docker/ VERIFY.md
├── scripts/            # verify-release-versions, release helpers
├── supply-chain/       # vet/deny state
├── .devcontainer/  .editorconfig  .pre-commit-config.yaml
└── .github/workflows/  # ci, release (dry-runnable), docs, scorecard
```

## The six phases

| # | Phase | Ships | Done when |
|---|-------|-------|-----------|
| 1 | **Normalize layout** | `docs/` root, DEVELOPMENT.md, editorconfig, docs-lint CI | No stray layouts; lint green everywhere |
| 2 | **Install UX** | GNUmakefile, generated manpages + completions | `make DESTDIR=/tmp/stage install` correct on a clean runner |
| 3 | **Rendered manual** | mdBook/MkDocs on Pages, README doc links unified | Manual live; link check gating CI |
| 4 | **Release binaries** | Target matrix, provenance-carrying archives | Dry-run yields all archives; binary runs on a bare container |
| 5 | **Distro packaging** | pkg/ formats, packaging.md, submissions | deb+rpm install in CI containers; first submission filed |
| 6 | **Polish** | devcontainer, pre-commit, CITATION, Scorecard ≥9 | Codespaces boots to working `make` |

Rules that make the phases stick: one phase per release; CI green at
every merge, in the same session the red appears; every "done when" is
a CI job, not a promise; and never couple a structure cleanup to code
changes — that is how cleanups die.

## Scoring rubric

For each category: **1–3** = absent or tribal knowledge only ·
**4–6** = exists but manual, partial, or not CI-enforced ·
**7–8** = solid, minor gaps, enforced · **9** = enforced and documented
with rationale · **10** = a newcomer, a packager, and a security auditor
each get what they need without asking anyone.
