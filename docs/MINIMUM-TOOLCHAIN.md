---
render_with_liquid: false
---

<!-- SPDX-License-Identifier: Apache-2.0 OR MIT -->
<!-- Copyright (c) 2015-2026 Sebastien Rousseau -->

# Minimum toolchain policy

This project has no compiler and therefore no MSRV. The equivalent
contract is the set of **interpreter and tool versions the framework
runs on**, and — more importantly — the policy for when those floors
may move.

The policy matters more than the numbers. A floor stated without a
policy is a number that drifts silently; a floor stated without CI
behind it is a claim, not a guarantee. Everything marked "enforced"
below is a job in `.github/workflows/`; everything else is labelled
as expectation.

## The floors

| Component | Floor | Why this floor | Enforced by |
|---|---|---|---|
| **bash** (running `dot`, `install.sh`, every script) | **3.2** | macOS still ships bash 3.2 as `/bin/bash` and always will (GPLv3). The CLI must work there or `dot` breaks on a stock Mac. No associative arrays, no `mapfile`/`readarray`, no `${var,,}`. | `cross-platform-test.yml` and `reliability-gate.yml` on `macos-latest` + `macos-14`, whose stock `/bin/bash` is 3.2.57 |
| **bash** (as an *interactive* shell with the full config) | **5.0** | The shell configuration (completions, prompt hooks) uses bash 5 features. This is a different, higher floor than the CLI's. | `reusable-test-suite.yml` on ubuntu-latest |
| **zsh** | **5.8** | The default interactive shell; `rc.d` ordering and the completion system assume 5.8. | `cross-platform-test.yml` (macOS stock zsh 5.9, Ubuntu 5.9) |
| **fish** | **4.0** | `dot`, the alias bridge, and the generated completions target the fish 4 syntax. | `ci.yml` job `Lint / Fish` |
| **nushell** | **0.98** | Tier-3 reference shell; see [ADR-011](adr/ADR-011-nushell-tier3-keep.md). | `ci.yml` job `Lint / Nushell` |
| **PowerShell** | **7.5** | The Windows parity surface. Note `windows-latest` currently ships 7.4 LTS, so CI proves 7.4 and the 7.5 claim covers features gated behind it. | `reliability-gate.yml` job `PowerShell Contract` on `windows-latest` |
| **git** | **2.34** | The oldest release with SSH commit/tag signing (`gpg.format = ssh`), which the signing and verification flow requires. | Not version-gated in CI; the signing workflows exercise it on runner git (≥ 2.40) |
| **chezmoi** | **2.47.1** | The pinned, checksum-verified version `install.sh` and CI install. Newer works; older is untested. | `install.sh` and `CHEZMOI_VERSION` in `ci.yml`, `ci-enforced.yml`, `perf-baseline.yml` |
| **Go** (fuzz harnesses and the two TUIs only — not needed to *use* the framework) | **1.23** | `fuzz/go.mod`. | `fuzz.yml`, `cockpit-test.yml`, `dot-ui-test.yml` |
| **Python** (pre-commit and the docs build only) | **3.12** | `pre-commit.yml`, `requirements-docs.txt`. | `pre-commit.yml`, `pages.yml` |

`make install` additionally needs GNU make or BSD make and a POSIX
`install(1)`; nothing else.

## Distro mapping — what is actually verified

The rule the repository standard sets is: **never claim distro-LTS
compatibility without a table mapping current distro toolchains to the
floor.** Here is that table, with an honest column for whether CI
proves it.

| Platform | Ships bash | Ships zsh | Ships git | Meets the CLI floor? | In CI? |
|---|---|---|---|---|---|
| Ubuntu 24.04 LTS (`ubuntu-latest`) | 5.2 | 5.9 | 2.43 | Yes | **Yes** — the primary Linux runner across ~20 workflows |
| Ubuntu 22.04 LTS | 5.1 | 5.8 | 2.34 | Yes | No — expected to work; not exercised since runners moved to 24.04 |
| Debian 12 (bookworm) | 5.2 | 5.9 | 2.39 | Yes | No — same package versions as Ubuntu 22.04/24.04; expected, unverified |
| Debian 13 (trixie) | 5.2 | 5.9 | 2.47 | Yes | No |
| RHEL 9 / Rocky 9 / Alma 9 | 5.1 | 5.8 | 2.43 | Yes | No — no RHEL-family runner or container in CI |
| RHEL 10 / Rocky 10 | 5.2 | 5.9 | 2.47 | Yes | No |
| Fedora 41+ | 5.2 | 5.9 | 2.47 | Yes | No |
| Arch Linux (rolling) | current | current | current | Yes | No — AUR package published, not CI-tested |
| Alpine (musl, busybox ash) | — | — | 2.45 | **No** — bash is not installed by default and `install.sh` requires it | No |
| macOS 14+, stock `/bin/bash` | **3.2.57** | 5.9 | 2.39+ (Xcode) | Yes — this is why the CLI floor is 3.2 | **Yes** — `macos-latest`, `macos-14` |
| macOS + Homebrew bash | 5.3 | 5.9 | 2.5x | Yes | Yes (same runners, Homebrew bash present) |
| Windows 11 + PowerShell 7.4 | n/a | n/a | 2.4x | Core CLI surface only | **Yes** — `windows-latest` PowerShell contract |
| WSL2 (Ubuntu) | 5.2 | 5.9 | 2.43 | Yes | Partially — `reliability-gate.yml` runs a WSL *contract* check on Linux, not a real WSL VM |

Read the last column as the honest one. "Expected, unverified" means
the package versions clear the floor by inspection but no job proves
it; a bug report from such a platform is legitimate and welcome.

## When a floor may rise

A floor is not a promise never to move — it is a promise about *how*
it moves.

1. **A raise is a breaking change** for the affected surface and gets
   a minor-version bump (a major once this project reaches 1.0), never
   a patch.
2. **A raise needs a reason recorded in the changelog entry**: the
   specific feature or fix that requires it. "Newer is better" is not
   a reason.
3. **The bash 3.2 floor for the CLI does not move while macOS ships
   3.2 as `/bin/bash`.** This one is effectively permanent. Code that
   needs bash 4+ goes in a script that is not on the `dot` startup
   path, and says so in a comment.
4. **A raise must be enforced by CI in the same pull request** that
   raises it. Bumping a documented number without moving the matrix
   produces exactly the aspirational claim this policy exists to
   prevent.
5. **Deprecation window**: one minor release announcing the intent in
   the changelog before the floor actually rises, so a pinned consumer
   sees it coming.

## Where the numbers live

| Number | Source of truth |
|---|---|
| chezmoi version | `CHEZMOI_VERSION` in `.github/workflows/ci.yml`, mirrored into `install.sh` |
| Go version | `fuzz/go.mod` |
| Every other pinned tool | `mise.toml` + `mise.lock` |
| Python docs deps | `requirements-docs.txt` (hash-pinned) |
| Platform/shell support tiers | [`reference/SUPPORT_MATRIX.md`](reference/SUPPORT_MATRIX.md) |

If this document and one of those files disagree, the file wins and
this document is the bug.
