---
title: "v0.2.503 Roadmap — Enterprise-Ready, Cross-Platform"
date: 2026-05-17
---

# v0.2.503 — Enterprise-Ready Cross-Platform Polish

## Why this release

The R4 audit (`HARD_AUDIT_2026.md` Part 8) ranked the framework
9.0/10 on internal quality but only 7.5/10 on adoption readiness.
The gap is **distribution + cross-platform polish + visible
organisation** — not feature surface. v0.2.503 closes that gap
without breaking existing user installs.

Reference target: <https://github.com/Debian/aws-cli> — the Debian
packaging of AWS CLI, often cited as a model of simple, focused
top-level structure. We will not blindly copy its layout (it ships
a Python project, we ship a chezmoi-managed shell framework), but
we will adopt its discipline: every top-level path has a clear
purpose, contributors orient in under 30 seconds.

## Scope (non-breaking; v0.2.503)

### A — Visible structure (no file moves)

| | |
|---|---|
| `STRUCTURE.md` at root | Single-page map of every top-level path, why it exists, and what it deploys to. Answers "what is `dot_config/`?", "why are there 25 root files?", "where is the CLI?" — in under 30 seconds. |
| `scripts/README.md` | Map of `scripts/{ci,diagnostics,dot,lib,maintenance,ops,security,tools,tuning}` subtrees. |
| Root `dot_*` files explained | The 20+ `dot_*` / `executable_*` / `private_*` prefixed files at root are not clutter — they are required by chezmoi to render at the corresponding `~/.X` path. STRUCTURE.md makes this contract visible. |

### B — UX polish

| | |
|---|---|
| Sweep remaining tabular `dot` commands through `ui_table_begin/add/end` | Already done: `dot env`, `dot agents list`, `dot registry list/search`, `dot aliases list/search`. Identify any other listing commands not yet on the helper and convert. |
| `dot doctor` rendering | Today emits 100+ lines of `ui_ok / ui_warn / ui_err`. Group into bordered sections with totals at the foot. |
| `dot help` two-column table | The grouped help index could become a gum-table by section. |
| `dot fleet status` widening | Use the table helper for the per-node status block. |

### C — Performance

| | |
|---|---|
| `_cached_eval` coverage audit | Find every `eval "$(<tool> init <shell>)"` in `rc.d/` not already wrapped; add to cache layer. |
| Shell startup p50/p95 in CI | New `dot-cli-bench` workflow exists for the CLI cold-start gate; add an equivalent zsh/bash/fish startup-time gate (sub-150ms cold). |
| Cross-shell `_cached_eval` parity | bash + fish + nu implementations exist; confirm they all do the realpath sidecar pin + suspicious-output check that zsh added. |

### D — Cross-platform CI parity

| | |
|---|---|
| Windows-native smoke test expansion | `scripts/ci/windows-smoke-test.ps1` exists but only covers a few commands. Add `dot version / dot help / dot agents check / dot doctor` Windows-native runs. |
| Real `ubuntu-latest` + `macos-latest` + `windows-latest` matrix for the test runner | Currently `ubuntu` + `macos` only; add `windows-latest` to the regular test workflow. |
| `chezmoi apply --dry-run` on all three OSes | Verify our templates render on every platform on every PR. |

### E — Code dedup + refactor (in-place)

| | |
|---|---|
| Audit `scripts/dot/lib/*` for cross-file duplication | Many small helpers may exist in 2+ places. Consolidate. |
| Consistent error-exit codes | Document the canonical exit-code map (1 = bad usage, 2 = no provider, 3 = empty, etc. — `dot secrets` already follows this). Audit other commands for drift. |
| `set -euo pipefail` header lint | Make sure every script under `scripts/` has the canonical header. |

### F — Distribution + discoverability (R4 Top-5 work)

| | |
|---|---|
| Homebrew tap stub | Create `install/homebrew/dot.rb` formula scaffold. Real publication still needs the v0.3 reorganization. |
| Scoop manifest stub | Same for `install/scoop/dot.json`. |
| `awesome-dotfiles` PR draft | One-line entry + screenshot. Land it after v0.2.503 ships. |

### G — OpenSSF Scorecard 10/10 across every check

Target the [public Scorecard report](https://scorecard.dev/viewer/?uri=github.com/sebastienrousseau/dotfiles) and drive every check to 10/10:

| Check | Today (baseline) | Path to 10 |
|---|---|---|
| **Binary-Artifacts** | 10 (no binaries committed) | Maintain — pre-commit guard rejecting any committed binary. |
| **Branch-Protection** | needs token | Already configured on `master` (required reviews, signed commits, status-check gating, linear history). Verify in `gh api repos/.../branches/master/protection` and document in `docs/security/`. |
| **CI-Tests** | 10 (CI passes on every PR) | Maintain — current 75-check matrix is comprehensive. |
| **CII-Best-Practices** / OpenSSF Best Practices badge | not present | Apply for the badge at [bestpractices.coreinfrastructure.org](https://www.bestpractices.dev/) and embed the badge in README. |
| **Code-Review** | needs verification | Already enforced via branch protection; document in CONTRIBUTING.md. |
| **Contributors** | low (solo) | Acknowledge — solo-maintained framework. Add `MAINTAINERS.md` + `GOVERNANCE.md` documenting the single-maintainer model and contribution path. |
| **Dangerous-Workflow** | 10 (no `pull_request_target` with checkout-then-build) | Maintain — `.github/workflows/` is already audited. |
| **Dependency-Update-Tool** | 10 (Dependabot + Renovate configured) | Maintain. |
| **Fuzzing** | partial (1 fuzz harness for `install.sh`) | Add OSS-Fuzz integration **OR** expand `tests/fuzz/` coverage (URL parsers, manifest validators, secret-bucket loaders). |
| **License** | 10 (MIT, top-level `LICENSE`) | Maintain. |
| **Maintained** | high (active commits weekly) | Maintain. |
| **Packaging** | low (no distro package) | Address via the Homebrew tap / Scoop manifest / AUR PKGBUILD in §F. SLSA-attested release artefacts now exist (v0.2.502 backfill confirmed). |
| **Pinned-Dependencies** | 9 (one tag-pinned reusable workflow — SLSA, documented exception) | Already documented; verify Scorecard accepts the SLSA exception. |
| **SAST** | 10 (CodeQL + Semgrep + Codacy in CI) | Maintain. |
| **Security-Policy** | 10 (`.github/SECURITY.md` + WKD-published GPG key + disclosure-key-expiry monitor) | Maintain. |
| **Signed-Releases** | 8–10 (Cosign-signed SBOM + SLSA provenance now landing per v0.2.502 backfill) | Verify Scorecard re-scrapes the v0.2.502 release post-backfill; should bump to 10. |
| **Token-Permissions** | 10 (top-level `permissions: contents: read`; per-job overrides) | Maintain — set during R3 hardening. |
| **Vulnerabilities** | 10 (osv-scanner + Dependabot keep open count at 0) | Maintain. |
| **Webhooks** | n/a | No org-level webhooks; check not applicable. |

**Action items:**

1. Run `scorecard` locally with the official Docker image, snapshot current scores into `docs/security/SCORECARD.md`.
2. Apply for OpenSSF Best Practices badge (≤30-min form).
3. Add `MAINTAINERS.md` + `GOVERNANCE.md`.
4. Re-trigger Scorecard workflow after v0.2.502 backfill so the dashboard reflects the fixed Signed-Releases score.
5. Track every sub-10 score with a follow-up issue tagged `scorecard`.

## Out of scope (deferred to v0.3.0 — breaking)

The R4 audit identified the framework / user-config intermingling
as the highest-leverage structural gap. Fixing it cleanly requires
*breaking changes for existing users*:

| Move | Why it's breaking |
|------|-------------------|
| `dot_config/` → `defaults/` (with chezmoi `.chezmoiroot`) | Every existing user's chezmoi source-state would need to re-bootstrap. |
| `dot_local/bin/executable_dot` → `bin/dot` | Same; `~/.local/bin/dot` would be removed before the new path is installed. |
| Split `framework/` (CLI + lib) from user-facing defaults | Major restructuring; needs RFC + migration tool + 2-version deprecation window. |

These will land in v0.3.0 as a coordinated single PR with a
`migrate-v0_2-to-v0_3.sh` script.

## Success criteria (v0.2.503)

- [ ] New contributor can answer "where is the CLI?" / "what is `dot_config/`?" / "how do I add a new command?" in under 30 seconds using only the root `STRUCTURE.md` + `scripts/README.md`.
- [ ] `dot lint` reports 328+ files clean.
- [ ] Shell startup p50 ≤ 100ms in CI on all three OSes.
- [ ] `dot env list` / `dot agents list` / `dot registry list` render with gorgeous gum tables (already done — bake into screenshot for README).
- [ ] `windows-latest` is in the regular test matrix.
- [ ] Pre-existing CI infrastructure failures (SLSA, etc.) stay green after the v0.2.502 fix series.
- [ ] **OpenSSF Scorecard reports 10/10 on every applicable check** at <https://scorecard.dev/viewer/?uri=github.com/sebastienrousseau/dotfiles>.
- [ ] OpenSSF Best Practices badge displayed in README.
