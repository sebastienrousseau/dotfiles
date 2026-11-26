<!-- SPDX-License-Identifier: Apache-2.0 OR MIT -->
<p align="center">
  <img src="https://cloudcdn.pro/dotfiles/v2/images/logos/dotfiles.svg" alt="Dotfiles logo" width="128" />
</p>

<h1 align="center">.dotfiles</h1>

<p align="center">
  Declarative dotfiles for macOS, Linux, WSL, and Windows-native
  PowerShell 7.5+. Multi-shell by default. Sub-100ms
  <code>dot</code> cold-start. Wallpaper-driven themes. Signed and
  attested releases. Fleet apply over SSH.
</p>

<p align="center">
  <a href="https://github.com/sebastienrousseau/dotfiles/actions"><img src="https://img.shields.io/github/actions/workflow/status/sebastienrousseau/dotfiles/ci.yml?style=for-the-badge&logo=githubactions&logoColor=white" alt="Build" /></a>
  <a href="https://github.com/sebastienrousseau/dotfiles/releases/latest"><img src="https://img.shields.io/badge/Version-v0.2.555-blue?style=for-the-badge&logo=semanticrelease&logoColor=white" alt="Version" /></a>
  <a href="https://www.npmjs.com/package/@sebastienrousseau/dotfiles"><img src="https://img.shields.io/npm/v/@sebastienrousseau/dotfiles?style=for-the-badge&logo=npm&logoColor=white&label=npm" alt="npm" /></a>
  <a href="https://doc.dotfiles.io/"><img src="https://img.shields.io/badge/Manual-doc.dotfiles.io-66c2a5?style=for-the-badge&labelColor=555555" alt="Manual" /></a>
  <a href="https://github.com/sebastienrousseau/dotfiles/releases"><img src="https://img.shields.io/github/downloads/sebastienrousseau/dotfiles/total?style=for-the-badge&logo=github&logoColor=white" alt="Downloads" /></a>
  <a href="https://codespaces.new/sebastienrousseau/dotfiles"><img src="https://img.shields.io/badge/Open%20in-Codespaces-blue?style=for-the-badge&logo=github&logoColor=white" alt="Open in GitHub Codespaces" /></a>
  <a href="https://scorecard.dev/viewer/?uri=github.com/sebastienrousseau/dotfiles"><img src="https://img.shields.io/ossf-scorecard/github.com/sebastienrousseau/dotfiles?style=for-the-badge&logo=linuxfoundation&logoColor=white&label=OpenSSF%20Scorecard" alt="OpenSSF Scorecard" /></a>
  <a href="https://www.bestpractices.dev/projects/12840"><img src="https://img.shields.io/cii/level/12840?style=for-the-badge&logo=linuxfoundation&logoColor=white&label=OpenSSF%20Best%20Practices" alt="OpenSSF Best Practices" /></a>
  <a href="#license"><img src="https://img.shields.io/badge/License-Apache--2.0%20OR%20MIT-green?style=for-the-badge&logo=opensourceinitiative&logoColor=white" alt="License: Apache-2.0 OR MIT" /></a>
  <a href="#requirements"><img src="https://img.shields.io/badge/toolchain-bash%205.0%20%C2%B7%20chezmoi%202.74.1-93450a?style=for-the-badge&logo=gnubash&logoColor=white" alt="Minimum toolchain: bash 5.0, chezmoi 2.74.1" /></a>
</p>

---

## Contents

**Getting started:** [Install](#install) · [Requirements](#requirements) · [Quick Start](#quick-start)

**The .dotfiles ecosystem:** [`dot`, its satellites and the module registry](#the-dotfiles-ecosystem)

**Reference:** [Capabilities at a glance](#capabilities-at-a-glance) · [Ecosystem comparison](#ecosystem-comparison) · [Benchmarks](#benchmarks) · [Features](#features) · [Configuration](#configuration) · [Examples](#examples)

**Operational:** [When not to use .dotfiles](#when-not-to-use-dotfiles) · [Development](#development) · [Security](#security) · [Documentation](#documentation) · [Stability guarantees](#stability-guarantees) · [License](#license)

---

## Install

The installer is pinned to a release and does not run unless its SHA-256
matches the one below ([why](docs/security/INSTALL_VERIFICATION.md)):

```bash
installer_dir="$(mktemp -d)" && curl -fsSLo "$installer_dir/dotfiles-install.sh" https://github.com/sebastienrousseau/dotfiles/releases/download/v0.2.555/dotfiles-install-0.2.555.sh
echo "146b94b2c492ffc99e4246a7110379c9df407162fa09de30c0d9e57333b5a7d0  $installer_dir/dotfiles-install.sh" | $(command -v sha256sum || echo shasum -a 256) -c - && bash "$installer_dir/dotfiles-install.sh"
```

It needs `git` and `curl`, clones the release to `~/.dotfiles`, applies
it, and puts `dot` in `~/.local/bin`. Other ways in, each with its
section in the manual's [install methods](docs/manual/02-tutorials/07-install-methods.md):

| Method | Command |
| :--- | :--- |
| [Homebrew](docs/manual/02-tutorials/07-install-methods.md#package-managers) | `brew install sebastienrousseau/tap/dot` |
| [AUR](docs/manual/02-tutorials/07-install-methods.md#package-managers) | `paru -S dot-cli-git` |
| [Scoop](docs/manual/02-tutorials/07-install-methods.md#package-managers) | `scoop bucket add sebastienrousseau https://github.com/sebastienrousseau/scoop-bucket && scoop install dot` |
| [Nix](docs/manual/02-tutorials/07-install-methods.md#package-managers) | `nix profile install ~/.dotfiles/nix#dot-utils` after cloning |
| [npm](docs/manual/02-tutorials/07-install-methods.md#package-managers) | `npx -p @sebastienrousseau/dotfiles dotfiles-install` |
| [From source](docs/manual/02-tutorials/07-install-methods.md#build-from-source) | `git clone https://github.com/sebastienrousseau/dotfiles.git ~/.dotfiles && ~/.dotfiles/install.sh` |

---

## Requirements

| Requirement | Floor |
| :--- | :--- |
| Shells | bash 5.0+ and zsh 5.8+ (Tier 1); fish, nushell and PowerShell 7.5+ at lower tiers |
| chezmoi | 2.74.1+ (the installer fetches it, checksum-verified) |
| git | 2.34+ |
| curl | any current release |
| Platforms | macOS 15+, Ubuntu 22.04+, Debian 12+, WSL2; Fedora and Arch community-supported |
| Windows | PowerShell 7.5+ runs the native `dot.ps1` for the daily workflow |

Each floor is what CI runs, and it rises only in a release whose changelog
says why: [`docs/MINIMUM-TOOLCHAIN.md`](docs/MINIMUM-TOOLCHAIN.md).

---

## Quick Start

```bash
export PATH="$HOME/.local/bin:$PATH"  # or open a new terminal
dot doctor            # audit tools, paths, portability, security
dot theme list        # the themes generated from this machine's wallpapers
dot theme set maui    # switch every app to one palette, following the OS appearance
dot sync              # apply the source tree; the next shell hydrates its caches
```

`dot help tour` walks through shells, secrets, themes and performance.
Per-machine settings live in `~/.config/chezmoi/chezmoi.toml`
([profiles](docs/reference/PROFILES.md)), features are flags in
`.chezmoidata.toml` ([feature flags](docs/reference/FEATURES.md)), and
upgrades between versions are in
[`docs/operations/MIGRATION.md`](docs/operations/MIGRATION.md).

---

## The .dotfiles ecosystem

One repository, one release train: the `dot` framework plus five
satellites that ship inside it and version with it. The version
number in `defaults/.chezmoidata.toml` is the compatibility contract:
CI's `Generators / version-consistency` job checks it against every
human-visible version surface (among them `package.json`, `bin/dot`,
the man page, the `bento` banner, this README's badge, `CLAUDE.md`
and [`AGENTS.md`](AGENTS.md)) on every push to `main`.

| Component | What it is | Use case |
|---|---|---|
| **`dot`** ([`bin/dot`](bin/dot) + [`lib/dot`](lib/dot/README.md)) | Bash dispatcher and shared library — lifecycle, diagnostics, themes, secrets, fleet, agents | Everything below; also shipped alone as the release archive. |
| **`dot-ui`** ([`defaults/dot_local/share/dot-ui`](defaults/dot_local/share/dot-ui)) | Go renderer for tables, pickers, and progress used by `dot` | Consistent terminal UI across every subcommand; built on apply by a `run_onchange` hook. |
| **`dot-ai-tui`** ([`defaults/dot_local/share/dot-ai-tui`](defaults/dot_local/share/dot-ai-tui)) | Go Bubble Tea cockpit behind `dot ai` | Install, run, chat with, and meter Claude, Codex, Copilot, Aider, OpenCode and friends from one screen. |
| **`dot mcp`** ([`docs/security/MCP_POLICY.md`](docs/security/MCP_POLICY.md)) | MCP policy, supply-chain, and registry audit over `mcp-policy.json` / `mcp-registry.json` | Keep Model Context Protocol servers inside an allowlist before an agent touches them. |
| **`dot-mcp`** ([`defaults/dot_local/share/dot-mcp`](defaults/dot_local/share/dot-mcp)) | Go stdio MCP server behind `dot mcp serve` — JSON-RPC 2.0, four read-only tools, five resources | Let an MCP client audit this workstation's policy, agent mode, attestation and drift without being able to change it. |
| **`dot-sys`** ([`lib/wasm-tools`](lib/wasm-tools/README.md)) | Rust crate built for `wasm32-wasip1` and run under `wasmtime` | `dot attest verify`: check a workstation evidence record in a sandbox with no filesystem, network or environment, so the verdict does not depend on the machine being reviewed. |
| **Module registry** ([`docs/operations/REGISTRY.md`](docs/operations/REGISTRY.md)) | JSON index of reusable dotfile modules, schema at [`docs/schema/dot-registry-v1.json`](docs/schema/dot-registry-v1.json) | `dot cli list --available` and `dot cli install` with SHA-256-verified archives and a chezmoi preview before apply. The published index carries this repository's own modules (`ai-policy-pack`, `claude-statusline`), and `--available` lists the whole index (a search term is ignored). |

### Install the pieces

```bash
# The framework (everything, chezmoi-managed)
bash "$installer_dir/dotfiles-install.sh"  # after the verified download above

# Only the dot CLI, from the attested release archive
gh release download v0.2.555 --repo sebastienrousseau/dotfiles --pattern 'dot-*.tar.gz'

# The Go satellites are (re)built on apply by
#   defaults/run_onchange_24-build-dot-ui.sh.tmpl
#   defaults/run_onchange_25-build-dot-ai-tui.sh.tmpl
#   defaults/run_onchange_26-build-dot-mcp.sh.tmpl

# A registry module
dot cli list --available && dot cli install <module> --yes
```

### Per-host quick links

| If you use… | Drop-in config |
|---|---|
| **Claude Code** | the shipped [`dotfiles-bootstrap` skill](defaults/dot_claude/skills/dotfiles-bootstrap/SKILL.md) — `/skills` discovers it and runs `dot config init` with profile-aware safety defaults |
| **Cursor / Codex / Windsurf / Zed / Roo / Cline / Aider / Continue / Jules / Antigravity** | `dot agent context apply` regenerates every harness stub from [`CLAUDE.md`](CLAUDE.md); `dot agent context check` fails when they drift |
| **A2A-capable agents** | the agent card at [`.well-known/agent.json`](.well-known/agent.json), shown by `dot agent card show` and checked by `dot agent card check` ([`docs/interop/A2A.md`](docs/interop/A2A.md)) |
| **Ghostty / Alacritty / Kitty / WezTerm / Warp / iTerm2 / tmux / Neovim / VS Code** | themed on every `dot theme` switch — see [Wallpaper-driven themes](docs/manual/01-concepts/03-theme-engine.md#wallpaper-driven-themes) |

### How good is this, really?

The rating is a set of programs, and each one prints the command
next to the number.

```sh
dot doctor score             # system health and security scorecard
dot security score show -j   # workstation security posture, JSON
dot doctor --score           # tools, paths, portability, AI analysis
make test                    # the reliability audit CI runs
```

What the repository can show today:

- **OpenSSF Scorecard 8.3 / 10** at the last recorded snapshot
  (2026-10-29), written into
  [`docs/security/SCORECARD.md`](docs/security/SCORECARD.md) with
  the per-check breakdown by `scripts/qa/scorecard-snapshot.sh`, run
  by hand. `scorecard.yml` runs the analysis weekly, and the badge
  above is live.
- **OpenSSF Best Practices: passing (100%)**, project
  [12840](https://www.bestpractices.dev/projects/12840).
- **Unit, integration, and regression suites**, a golden-snapshot suite for `dot --help` / `version` /
  `doctor` / `perf` / `health`, and an `install.sh` fuzz harness —
  see [`tests/README.md`](tests/README.md).
- **Bash line coverage floor 98%** (96% for behavioural tests
  alone) measured by pure `xtrace`, no kcov, ratcheted up slice by
  slice with the history recorded in
  [`coverage.yml`](.github/workflows/coverage.yml).
- **Every third-party action SHA-pinned**, and Harden Runner in
  every workflow except `branch-drift-guard.yml`.

The gaps, so nobody has to find them:

- Scorecard's `Code-Review` check scores **0**: one maintainer,
  merges gated by CI rather than by a second reviewer.
- OSS-Fuzz onboarding is prepared under
  [`fuzz/oss-fuzz/`](fuzz/oss-fuzz/project.yaml) but
  **not yet submitted**; ClusterFuzzLite runs in the meantime.
- Repology tracks one packaging (AUR `dot-cli-git`); Homebrew and
  Scoop go through this project's own tap and bucket.
- Nushell sits at Tier 3 with under 5% feature parity
  ([ADR-011](docs/adr/ADR-011-nushell-tier3-keep.md)).

Each number above names the command or the file that produced it.
The Scorecard breakdown is
[`docs/security/SCORECARD.md`](docs/security/SCORECARD.md), the
coverage history is in
[`coverage.yml`](.github/workflows/coverage.yml), and
[`docs/STRUCTURE.md`](docs/STRUCTURE.md) maps every top-level path
to the component that owns it. The rest of this README covers the
**framework** surface.

---

## Capabilities at a glance

| Theme | Headline deliverables |
| :--- | :--- |
| Wallpaper-driven themes | K-Means clustering in CIELAB extracts terminal palettes from any wallpaper; WCAG AAA enforced; Apple-compatible dynamic HEIC dark/light; 296 generated themes; `dot theme rebuild` |
| AI and MCP native | Agent profiles (`dot agent mode`), MCP policy and registry audit (`dot mcp`), agent card, checkpoints and conformance (`dot agent`), AI commit messages (`dot config save`), the `dot ai` cockpit and local gateway |
| Cryptographic attestation | Signed commits and tags, machine-readable workstation evidence (`dot attest`), policy-bundle releases, the signing check in `dot doctor`, `dot secret check` |
| Fleet management | Multi-node status, drift, events, namespaces and RBAC enforcement mode (`dot fleet`); `dot fleet apply` over SSH; `dot fleet push` to bring up a remote host |
| Self-healing | `dot doctor fix`, `dot doctor rollback`, `dot config export`; chezmoi drift, broken symlinks, missing files, checksum-verified tool recovery |
| Sub-second startup | Lazy loading, `_cached_eval`, mtime-based cache invalidation, realpath sidecar pins; `dot doctor perf show`, `dot doctor perf measure`, `dot doctor status` |
| Multi-shell parity | Tier 1 (full): zsh, bash. Tier 2 (bridged): fish. Tier 3 (compatible): nushell. PowerShell as a contract-tested parity target ([`tests/integration/test_shell_parity.sh`](tests/integration/test_shell_parity.sh)) |
| Private build caches | Go, pip, uv, and Zig caches live under `~/.cache/dot/builds` via `mise [env]`; Cargo keeps a per-project `./target` (no shared lock), with sccache sharing dependencies and `rust-target-tmp` moving `./target` out of the repository |
| Encrypted secrets | age and SOPS at rest; macOS Keychain, `pass`, or age-encrypted store selected by policy; `dot secret`, `dot secret check`, `dot secret key new`, `dot secret cert` |
| Portable runtimes | mise for managed toolchains with a cross-platform `mise.lock`; Nix flake for strict reproducibility; `dot tool`, `dot system update` |
| Schema-validated config | `.chezmoidata.toml` checked against a JSON Schema in CI; `dot tool export` writes a v1-schema environment manifest; the registry index has its own schema |
| Supply chain | SHA-pinned actions, Harden Runner, SLSA L3 provenance, Cosign keyless signing, SPDX SBOM, OpenSSF Scorecard and Best Practices, gitleaks + detect-secrets + TruffleHog, dependency review, CodeQL, Checkov |

---

## Ecosystem comparison

`chezmoi` is the engine; `.dotfiles` is a distribution on top of a stock
chezmoi source tree, and the only one in this comparison with these
pieces:

| | This repo | chezmoi | holman/dotfiles | nikitabobko/dotfiles |
|:---|:---:|:---:|:---:|:---:|
| Multi-shell parity (zsh/fish/nu/pwsh) | ✓ | — | bash only | zsh only |
| Wallpaper-driven themes (K-Means) | ✓ | — | — | — |
| Cryptographic attestation | ✓ | — | — | — |
| Self-healing CLI | ✓ | — | — | — |
| Fleet management | ✓ | — | — | — |

The full matrix is the manual's
[Appendix F](docs/manual/05-appendices/F-comparison.md).

---

## Benchmarks

Two budgets are enforced in CI, and both state their method.

**`dot` cold start** — `tools/ci/dot-cli-startup-bench.sh` runs
`dot version` eleven times under a clean `env -i` shell and takes
the median. [`dot-cli-bench.yml`](.github/workflows/dot-cli-bench.yml)
fails the build above the budget on every push and PR touching
`bin/dot` or `scripts/dot/`; a median more than 15% over the previous
baseline is a warning.

| Runner | Budget (median of 11) | Observed |
|---|---:|---:|
| Linux (`ubuntu-latest`) | 150 ms | within budget on every green run |
| macOS | 200 ms | within budget on every green run |
| Local macOS, bash 5.x | — | **~47 ms** (recorded in the workflow header and `CHANGELOG.md`) |

**Interactive shell startup** — `dot doctor perf show` (backed by
`scripts/diagnostics/perf.sh`, `hyperfine`-style warm-up plus three
runs, mean) measures every installed shell against a per-shell
target, compares with a recorded baseline in
`~/.cache/dotfiles/perf-baseline.json`, and flags any shell more
than 10% slower. [`perf-baseline.yml`](.github/workflows/perf-baseline.yml)
records the reference weekly on Ubuntu and measures every push to a
`feat/**` branch that touches shell code.

| Shell | Target (mean) | Override |
|---|---:|---|
| zsh | 250 ms | `DOTFILES_PERF_TARGET_ZSH_MS` |
| bash | 60 ms | `DOTFILES_PERF_TARGET_BASH_MS` |
| fish | 200 ms | `DOTFILES_PERF_TARGET_FISH_MS` |
| nushell | 500 ms | `DOTFILES_PERF_TARGET_NU_MS` |
| PowerShell | 600 ms | `DOTFILES_PERF_TARGET_PWSH_MS` |

Measured deltas that shipped with their method in `CHANGELOG.md`:
fish startup **217 ms → 119 ms** by emitting the alias bridge as
`abbr` instead of `alias` (#963); ~140 ms saved per fish start by
shadowing Homebrew's eager `direnv` / `mise` `vendor_conf.d` hooks;
20–50 ms saved per tool by `_cached_eval`
([`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)).
The original threshold and the `hyperfine --warmup 3 --runs 10
"zsh -i -c exit"` recipe are in
[ADR-002](docs/adr/ADR-002-shell-performance.md).

Numbers on your own machine:

```bash
dot doctor perf show              # every installed shell vs its target
dot doctor perf show --baseline   # record this machine's known-good point
dot doctor perf measure           # per-component startup profile
dot doctor perf --ready           # time to heavy-layer readiness
```

Budgets, baseline lifecycle, and the regression-issue pipeline are
documented in
[`docs/operations/PERFORMANCE.md`](docs/operations/PERFORMANCE.md);
the harnesses are
[`tools/ci/dot-cli-startup-bench.sh`](tools/ci/dot-cli-startup-bench.sh)
and [`benches/`](benches/).

---

## Features

| | |
| :--- | :--- |
| **Shells and navigation** | Zsh loads in stages through small `rc.d` modules, not one startup script. Fish uses `_cached_eval` and deferred loading. Bash ships full parity with zsh for tooling and aliases. Nushell handles structured workflows (Tier 3). PowerShell keeps cross-platform and WSL sessions on the same baseline with a `pwsh` parity contract in CI. Starship, Zoxide, Atuin, and fzf for navigation and recall. Starship Transient Prompt collapses past prompts to a single glyph on fish; the zsh hook is in place for when upstream lands the matching function ([ADR-010](docs/adr/ADR-010-starship-transient-prompt.md)). |
| **Development and runtimes** | mise manages language versions in user space with a cross-platform `mise.lock` (Linux, macOS, Windows, exact URLs and SHA-256s). Nix Flakes for strict reproducibility when speed is not the priority. Pueue queues long-running tasks instead of extra tabs. Neovim ships as a full Lua editor, not a starter template. Lazygit for terminal git. Build caches (Go, pip, uv, Zig) live under a private `~/.cache/dot/builds`; Cargo keeps a per-project `./target`. `_cached_eval` caches expensive `tool init` output with mtime and realpath invalidation; `EVALCACHE_DISABLE=true` bypasses it. |
| **AI, agents, and MCP** | Agent profiles (`dot agent mode`): ask, plan, apply, audit. Pattern library (`dot ai pattern`): architect, hardener, refactor, bundled in `dot_config/ai/patterns/`. MCP policy enforcement (`dot mcp`). AI commit messages (`dot config save`). The `dot ai` cockpit installs and runs Codex, Copilot, Antigravity, Aider, OpenCode and friends from one Bubble Tea TUI; `dot ai gateway serve` gives any Anthropic- or OpenAI-protocol tool a local Claude endpoint on your Anthropic API key (subscription routing is an explicit opt-in; see Anthropic's terms in `docs/AI.md`) ([ADR-012](docs/adr/ADR-012-ai-fleet-local-proxy.md), [`docs/AI.md`](docs/AI.md)). Every agent session is logged with a policy hash and an outcome. |
| **Security, trust, governance** | age and SOPS keep secrets encrypted at rest and out of history. SSH ed25519 signing plus trust metadata back every commit. Gitleaks, detect-secrets, TruffleHog, policy checks, and compliance workflows. `dot attest` records machine state, policy, prompt, and model metadata in tracked JSON. Telemetry controls and local-first defaults (`dot security telemetry apply`, `dot security dns apply`, `dot security firewall apply`, `dot security usb apply`, `dot security lock apply`, `dot security disk show`). SPDX SBOM and Grype CVE scanning in CI. npm releases authenticate through OIDC trusted publishing with provenance, never a long-lived token. |
| **Themes** | 296 wallpaper-derived themes, dark and light paired; `dot theme`, `dot theme toggle`, `dot theme family`, `dot theme sync` with the OS appearance; `dot theme wallpaper set rotate` and `dot theme wallpaper set sync`. See [Wallpaper-driven themes](docs/manual/01-concepts/03-theme-engine.md#wallpaper-driven-themes). |
| **Fleet and remote** | `dot fleet` status, drift, events, namespace, RBAC enforce mode; `dot fleet apply` runs `dot sync` (or a custom `--cmd`) on every host in `fleet.toml`; `dot fleet push` deploys the environment to a fresh host over SSH; `dot config export` builds an offline archive. |
| **Diagnostics** | `dot doctor` (deep audit, `--ai` analysis), `dot doctor status` dashboard, `dot doctor score`, `dot security score show`, `dot fleet drift`, `dot doctor snapshot new`, `dot doctor metric list` (JSONL observability), `dot shell history list`, `dot tool list --packages`. |
| **Distribution** | Release archives with a `PREFIX` / `DESTDIR` Makefile, man page (`share/man/man1/dot.1`), generated completions, Homebrew tap, Scoop bucket, AUR, npm, Nix; `dot config uninstall` removes the managed environment. |

---

## Configuration

<details>
<summary><b>Machine data (<code>.chezmoidata.toml</code>)</b></summary>

```toml
# defaults/.chezmoidata.toml — repo-wide defaults, schema-checked in CI
dotfiles_version = "0.2.555"

[features]
alias_wrapper = false   # confirm destructive aliases
dms = true              # Dank Material Shell accents (niri borders, GTK) via dot-theme-sync
ai_theme_sync = true    # wallpaper-aware AI CLI appearance
zellij = false
linux_desktop = false   # mako, environment.d and systemd user units

[tools]
node_manager = "mise"   # mise | fnm | nvm
```

`dot secret` also reads an optional `[secrets.policy]` table
(`provider = "auto" | "macos-keychain" | "pass" | "plain-enc"`,
`auto_load`) from this file; a `[data.secrets.policy]` table in `~/.config/chezmoi/chezmoi.toml` (written by `scripts/ops/setup.sh`) overrides it for one host, and `DOTFILES_SECRETS_PROVIDER` overrides both.

The `Lint / Chezmoidata Schema` job fails a merge on a wrong type
(a non-boolean flag, an unknown `default_shell` or `node_manager`).
It does not catch a misspelt flag or profile name: unknown flags
and custom profiles are allowed
([`config/chezmoidata.schema.json`](config/chezmoidata.schema.json)).

</details>

<details>
<summary><b>Per-machine overrides (<code>~/.config/chezmoi/chezmoi.toml</code>)</b></summary>

```toml
[data]
profile = "laptop"        # laptop | minimal | server
machine = "work-macbook"
default_shell = "zsh"

[data.features]
linux_desktop = false
```

Hardware presets (`macbook-t2`, `surface-pro`, `geekom-a9`) live in
`defaults/.chezmoidata/hardware.toml` and are selected with
`machine = "<preset>"`. Run `dot sync` after editing.

</details>

<details>
<summary><b>Session flags</b></summary>

| Variable | Default | Effect |
|---|---|---|
| `DOTFILES_FAST=1` | 0 | Skip heavy layers (zinit, completions) |
| `DOTFILES_ULTRA_FAST=1` | 0 | Bare minimum shell (aliases + prompt) |
| `DOTFILES_AI=1` | 1 (exported by the shipped zsh, bash, fish, nu and pwsh profiles) | `1` loads the zsh AI helper scripts; `1` also lets apply build `dot-ai-tui` (`0` is off) |
| `DOTFILES_PROFILE` | the chezmoi `profile` | Read by the OS tuning scripts (`scripts/tuning/`); `.zshrc` re-exports it from the chezmoi profile on every start |
| `DOTFILES_NONINTERACTIVE=1` | unset | Skip prompts (CI) |
| `DOTFILES_SILENT=1` | unset | Suppress non-error output |
| `DOTFILES_SOURCE_DIR` | `~/.dotfiles` | Override the source directory |
| `DOTFILES_WALLPAPER_DIR` | `~/Pictures/Wallpapers` | Custom wallpaper directory |
| `DOTFILES_DEBUG=1` | unset | Print shell-init timing to stderr |

The complete list is
[`docs/manual/03-reference/03-environment.md`](docs/manual/03-reference/03-environment.md);
the strategy for choosing chezmoi data over Nix over runtime flags is
[`docs/CONFIG_STRATEGY.md`](docs/CONFIG_STRATEGY.md).

</details>

---

## Examples

Run all examples (each one is bounded by a 60 s timeout and executed
in CI by the `Examples Contract` job):

```bash
make examples
```

<details>
<summary><b>Selected examples</b></summary>

| Category | Example | Purpose |
| :--- | :--- | :--- |
| **CLI** | `example-dot-commands` | `dot` CLI command modules |
| | `example-command-reference` | Complete `dot` command reference, one usage line per public command |
| | `example-cli-utilities` | CLI utility scripts deployed to `~/.local/bin` |
| | `example-functions` | Shell function library categories |
| **Operations** | `example-install-uninstall` | Installation and uninstall scripts |
| | `example-ops` | Operations and maintenance scripts |
| | `example-diagnostics` | Diagnostics and health-check utilities |
| | `example-platform-contract` | `lib/dot/platform.sh`: platform id, host OS, the portability contract |
| | `example-fleet` | Fleet management (multi-machine dotfiles operations) |
| **Themes** | `example-theme` | Theme and wallpaper engine |
| **Security** | `example-secrets` | Encrypted secrets (age) management |
| | `example-security` | Security operations and hardening scripts |
| | `example-git-hooks` | The hook installer and the pre-push reliability gate |
| **AI** | `example-ai-patterns` | The `dot ai` fleet: command surface, steering styles, gateway |
| **Quality** | `example-test-suite` | Running the unit and integration suites |
| | `example-testing-framework` | Testing framework capabilities: assertions and mocks |
| | `example-coverage-gate` | The module coverage gate |
| | `example-qa` | Quality assurance and validation scripts |
| **Packaging** | `mise-plugin-dot/` | A mise plugin that installs `dot` |

The full set, including one `example-dot-*` script per `dot` area,
is in [`examples/`](examples/).

</details>

---

## When not to use .dotfiles

A few cases where another tool fits better, listed because the
short answer is "we don't do that" rather than because of a
disagreement on priorities.

- **You want a dependency-free shell config.** The full setup
  (`install.sh --provision`) brings chezmoi, mise, starship, zoxide,
  atuin, fzf, and a Go toolchain for the TUI satellites. Leaving out
  `--provision` (or passing `--minimal`) and `DOTFILES_ULTRA_FAST=1`
  cut that down, but the framework assumes it may install things. A
  single `.zshrc` is lighter.

- **You need full parity on nushell.** Nushell is Tier 3: simple
  aliases plus bash-delegated functions, under 5% of the zsh feature
  set, kept deliberately as a reference target
  ([ADR-011](docs/adr/ADR-011-nushell-tier3-keep.md)).

- **You need Windows without WSL to be first-class.** The native
  `dot.ps1` covers the daily workflow (apply, status, doctor, mise,
  agents, fleet status); themes, `dot doctor fix`, and most diagnostics still
  need bash. Windows CI verifies the PowerShell surface, not the
  whole CLI.

- **You are on Fedora or Arch and need CI-backed support.** Both
  are community-supported: the code is expected to work, but the
  matrix runs Ubuntu, macOS (Apple Silicon on every push, Intel in
  the weekly extended run), and Windows
  ([`docs/reference/SUPPORT_MATRIX.md`](docs/reference/SUPPORT_MATRIX.md)).

- **You do not want `apply` to run scripts.** `chezmoi apply` runs
  the `run_onchange_*` hooks under `defaults/` (the Go satellite
  builds, terminal profiles, fonts, completion caches) when their
  source changes. They are idempotent and previewable with
  `dot sync --check`, but they are scripts running as you. Package
  and toolchain provisioning under `install/provision/` runs only
  with `install.sh --provision`.

- **You need a second reviewer on every merge.** This is a
  single-maintainer project gated by CI, DCO, and signed commits,
  not by code review; the Scorecard `Code-Review` check says so.

If you hit a case that should be on this list, please open an issue;
that is how it gets fixed or moved into the supported set.

---

## Development

```bash
make                    # reliability audit: syntax, unit, module coverage, examples, docs + traceability coverage
make test-quick         # the same, quick mode
make test-unit          # unit only
make test-integration   # with integration suites
make examples           # run every example under a timeout
make install            # stage the dot CLI under $(DESTDIR)$(PREFIX) (default /usr/local)
make uninstall

./tests/framework/test_runner.sh --jobs auto   # unit suite, parallel
bash tests/snapshots/test_snapshots.sh         # golden CLI output
bash fuzz/install/fuzz_install.sh                # install.sh under adversarial input
bash tools/docs/generate-command-index.sh --check
bash scripts/verify-release-versions
```

Toolchain setup, the task map, and how to reproduce every CI gate
locally are in [`DEVELOPMENT.md`](DEVELOPMENT.md) and
[`docs/operations/TESTING.md`](docs/operations/TESTING.md). Commit signing,
the DCO trailer, branch names, and the regression-test convention
are in [`CONTRIBUTING.md`](CONTRIBUTING.md). A
[devcontainer](.devcontainer/devcontainer.json) boots to a working
`make` for Codespaces.

### Fuzzing

Native Go fuzz harnesses ship under
[`fuzz/`](fuzz/) for the
user-input surfaces that were ported out of the shell so they could
be fuzzed at all, among them `FuzzValidateName` (the name validator
behind `lib/dot/utils.sh`) and `FuzzInitURLResolver` (the URL
resolver behind `dot config init`); the three Go satellites carry
their own in-module harnesses. A shell harness,
[`fuzz/install/fuzz_install.sh`](fuzz/install/fuzz_install.sh), drives
`install.sh` itself with unknown flags, garbage positionals, symlink
loops in `$HOME`, an empty `PATH`, 4 KB arguments, and NUL bytes in
the environment, and asserts every case exits cleanly or fails fast
but never hangs. It has already found two real bugs (a missing `-h`
alias; unknown positionals triggering a 30 s network fetch).

- [`fuzz.yml`](.github/workflows/fuzz.yml) runs each Go harness for
  60 s on every push to `main` and on every PR touching the parsing
  surfaces. Go replays the committed seed corpus under
  `testdata/fuzz/` before exploring, so a fixed crash cannot
  silently return.
- [`cflite_pr.yml`](.github/workflows/cflite_pr.yml) builds the
  ClusterFuzzLite fuzzers (AddressSanitizer) on PRs touching the
  harnesses or [`.clusterfuzzlite/`](.clusterfuzzlite/build.sh), so the
  build OSS-Fuzz runs cannot break unseen; the fuzzing itself runs in
  `fuzz.yml`.
- [`install-fuzz.yml`](.github/workflows/install-fuzz.yml) runs the
  `install.sh` harness weekly on Ubuntu and macOS, and on every PR
  touching `install.sh`; a scheduled failure opens a tracking issue.
- **OSS-Fuzz:** the project definition is ready in
  [`fuzz/oss-fuzz/`](fuzz/oss-fuzz/project.yaml)
  (libFuzzer, ASan + UBSan, x86_64); the upstream submission to
  `google/oss-fuzz` has not been filed yet.

```bash
cd fuzz
go test -run TestNothing -fuzz='^FuzzValidateName$' -fuzztime=60s ./...
go test -run TestNothing -fuzz='^FuzzInitURLResolver$' -fuzztime=60s ./...
```

The harness layout and the OSS-Fuzz submission steps are in
[`docs/security/FUZZING.md`](docs/security/FUZZING.md); the shared
corpus lives beside the harnesses under
[`fuzz/testdata/`](fuzz/testdata/).

### Hardening gates in place of Miri

- **ShellCheck at severity `error` is a hard gate** on every push
  (`reusable-shell-lint.yml`, `fail_on_shellcheck: true`), with
  `shfmt` formatting checked alongside; the same hooks run in
  pre-commit. Fish and Nushell configs have their own lint jobs.
- **Coverage by `xtrace`, not kcov.** `tools/ci/run-coverage.sh`
  turns on `set -x` through `BASH_ENV` in every bash process the
  suite spawns and aggregates the lines that executed. The floor is
  **98%** (96% for behavioural tests alone); the measured history is in the
  workflow file. A separate 100% *module-mapping* floor
  (`tests/framework/module_coverage.sh`) fails the build when an
  executable module has no test file at all.
- **Reliability Gate** runs the audit on `ubuntu-latest`,
  `macos-latest`, and `macos-15` (both Apple Silicon), then the
  examples contract, the WSL contract, and the PowerShell contract
  ([`docs/operations/RELIABILITY.md`](docs/operations/RELIABILITY.md)).
- **Cross-platform portability scan** rejects GNU-only `sed`,
  `grep`, and `date` idioms and runs the critical scripts on each OS
  ([`cross-platform-test.yml`](.github/workflows/cross-platform-test.yml)).
- **Generators cannot drift:** the command index is regenerated
  from the plugin manifests (through the command table) and diffed;
  every version surface (among them `package.json`, `bin/dot`, the
  man page, `lib/dot/bento.sh`, this README's badge, `CLAUDE.md` and
  [`AGENTS.md`](AGENTS.md)) is checked against
  `.chezmoidata.toml`; `.chezmoidata.toml` itself is validated
  against its JSON Schema. `dot agent context check` does the same for the
  AI-harness stubs locally.
- **Golden snapshots** pin the user-facing text of `dot --help`,
  `dot version`, `dot doctor`, `dot doctor perf show`, and `dot doctor status` after
  scrubbing paths, timings, and colours.

### CI

| Workflow | Trigger | Purpose |
| :--- | :--- | :--- |
| `ci.yml` | push, PR, schedule | Shell / Lua / Fish / Nushell / copyright lint, chezmoidata schema, secrets scan, dependency audit, TruffleHog, SBOM + Grype, link check, tests on Linux, macOS, Windows, Docker |
| `ci-enforced.yml` | push, PR | The stricter enforced gate reusing the shared lint and test-suite workflows |
| `reliability-gate.yml` | push, PR | Reliability audit on three runners + examples, WSL, PowerShell contracts |
| `coverage.yml` | push, PR | xtrace line coverage with the 98% floor and delta gate |
| `cross-platform-test.yml` | push, PR | Portability scan and runtime checks per OS |
| `dot-cli-bench.yml` / `perf-baseline.yml` | push, PR / weekly + `feat/**` | Cold-start budget; shell-startup baseline and regression issues |
| `fuzz.yml` / `cflite_pr.yml` / `install-fuzz.yml` | push, PR / PR / weekly + PR | Go harnesses; ClusterFuzzLite; `install.sh` fuzz |
| `doc-drift.yml` | push, PR | Command index and version-consistency generators |
| `dco.yml` / `pr-signature.yml` / `verify-tag-signature.yml` | PR / PR / tag | DCO trailer, PR description signature, signed annotated tags |
| `scorecard.yml` / `codeql.yml` / `dependency-review.yml` / `security-enhanced.yml` / `deps-dev-validation.yml` | weekly / push, PR | OpenSSF Scorecard, CodeQL, dependency review (`fail-on-severity: high`), Checkov, deps.dev validation |
| `release-package-dot.yml` / `security-release.yml` | release | `dot-<v>.tar.gz` + `.zip` with SLSA provenance; SPDX SBOM, Cosign signature, unified `ALL_SHA256SUMS` manifest |
| `release-install-smoke.yml` / `release-distribute-*.yml` | release | Clean-install smoke on Ubuntu + macOS; Homebrew, Scoop, AUR fan-out |
| `npm-publish.yml` / `manual-publish.yml` / `pages.yml` | release, push | npm via OIDC trusted publishing; the manual in nine formats; the site |

The cadence and the composite actions are documented in
[`docs/operations/CI_CADENCE.md`](docs/operations/CI_CADENCE.md) and
[`docs/operations/CI_COMPOSITES.md`](docs/operations/CI_COMPOSITES.md).

---

## Security

**Reporting:** never open a public issue for a vulnerability — use
[GitHub Security Advisories](https://github.com/sebastienrousseau/dotfiles/security/advisories)
or <security@sebastienrousseau.com>; see
[`SECURITY.md`](SECURITY.md) for the response SLA (Critical: 24 h
initial response, 48 h target; High: 72 h / 7 days; Medium: 5 / 30
business days; Low: 10 / 90), the supported-version table, and the
GPG key for encrypted reports
([`docs/security/DISCLOSURE.md`](docs/security/DISCLOSURE.md),
[`docs/security/KEY_ROTATION.md`](docs/security/KEY_ROTATION.md)).

A dotfiles framework is code that runs as you, on every login, on
every machine you own. The posture below closes the vectors that
matter for that shape — remote script execution, secrets at rest,
agents with shell access, and the pipeline that ships it — at the
architectural level, not behind opt-in flags. The full analysis is
[`docs/security/THREAT_MODEL.md`](docs/security/THREAT_MODEL.md).

### Installer and remote-execution controls

- **No unverified download runs.** Where `chezmoi` is missing,
  `install.sh` installs it with Homebrew when `brew` is present;
  otherwise it fetches the release tarball through
  `tools/ci/install-chezmoi-verified.sh`, or, when that helper is not
  beside it, an embedded verifier that checks the tarball against a
  pinned SHA-256 (and the upstream checksum file when it can fetch
  it). Either refuses on mismatch and never falls back to a remote
  script.
- **Every third-party installer the framework can execute is
  allowlisted by SHA-256** in
  [`security/remote-installers.sha256`](security/remote-installers.sha256)
  (Claude, Kimi, Goose, Antigravity, xAI, and the rest). CI rejects
  any `curl | sh` that bypasses the verifier.
- **Size and structure limits.** `lib/dot/verified-download.sh` caps
  scripts at 512 KiB and archives at 100 MiB by default, caps
  checksum manifests at 2 MiB, and fails closed on empty files;
  registry archives are rejected when they contain path traversal
  or link entries. Fonts, distro signing keys, and binary archives
  go through the same path.
- **`dot config init` is HTTPS-only**, refuses to overwrite an existing
  source directory without `--force`, and prints the source URL it
  is about to run scripts from.
- **Self-healing never fetches mutable URLs.** Tool recovery uses
  exact mise / aqua pins with checksums.

### Secrets

- `dot secret` selects a provider by policy — macOS Keychain,
  `pass`, or an age-encrypted local store — and loads buckets into
  the environment on demand (`eval "$(dot secret export ai)"`), so
  keys are never in plaintext files or shell history.
- age and SOPS encrypt chezmoi-managed secret files at rest;
  `dot secret init` bootstraps the key, `dot secret key new` encrypts an
  SSH key locally, `dot secret cert` manages short-lived certificates.
- `dot secret check` audits hygiene and leakage surface on the
  workstation; gitleaks, detect-secrets, and TruffleHog run on every
  push and in pre-commit; the history-filtering procedure is written
  down in
  [`docs/security/HISTORY_FILTERING.md`](docs/security/HISTORY_FILTERING.md).

### Agents and MCP

- Every agent runs under a bounded profile (`ask` / `plan` /
  `apply` / `audit`) with checkpoints and a session audit log;
  `dot fleet policy set strict` turns the profile RBAC from advisory
  into enforced.
- MCP servers must appear in `mcp-policy.json` and pass
  `dot mcp check` (policy, supply chain, config) before use.
- `dot attest` records the workstation state with the policy hash so
  an audit can check what an agent was allowed to do when it ran.

### Supply chain

- **Every third-party GitHub Action is pinned to a commit SHA**, and
  the pins are linted (`Lint / Reusable Workflow Pins`). The one
  tag reference is the SLSA generator reusable workflow, which its
  maintainers require to be referenced by release tag
  ([`docs/security/CI_PINNING.md`](docs/security/CI_PINNING.md)).
- **Harden Runner in every workflow** except
  `branch-drift-guard.yml`, with the jobs proven local-only in
  egress-block mode and an explicit endpoint list
  ([`docs/security/CI_EGRESS_ALLOWLIST.md`](docs/security/CI_EGRESS_ALLOWLIST.md)).
- **Releases carry provenance:** SLSA L3 build attestation on the
  `dot` archive (`gh attestation verify`), an SPDX SBOM signed with
  Cosign keyless (Fulcio + Rekor), and one signed `ALL_SHA256SUMS`
  manifest covering every asset; the verification recipe is
  [`docs/security/VERIFY_RELEASE.md`](docs/security/VERIFY_RELEASE.md).
- **Signed everything:** SSH ed25519 commit signatures enforced on
  `main`, signed annotated tags verified by workflow, DCO and PR
  signature checks required, GPG key published over WKD and checked
  weekly (`verify-gpg-wkd.yml`).
- **npm via OIDC trusted publishing** with provenance attached, no
  long-lived token.
- **Scans on every push:** dependency review (`fail-on-severity:
  high`), CodeQL, Checkov, Grype against the SBOM, Dependabot with
  grouped updates; OpenSSF Scorecard weekly, with the snapshot in
  [`docs/security/SCORECARD.md`](docs/security/SCORECARD.md)
  refreshed by hand (`scripts/qa/scorecard-snapshot.sh`).
- **SPDX headers** on source files, checked by the copyright lint
  job.

### Notes

- Template injection is a real surface for a chezmoi tree: `.tmpl`
  files render with chezmoi data before deployment, so
  `.chezmoidata.toml` is schema-validated and the trust boundary is
  documented per surface in the threat model.
- `_cached_eval` output files under `~/.cache/shell/` are sourced on
  startup; the cache key includes the tool binary's mtime and
  realpath so a swapped binary invalidates its cache.

---

## Documentation

**[User Manual](https://doc.dotfiles.io/) · [API reference](docs/manual/command-index.md) · [Development](DEVELOPMENT.md) · [Ecosystem map](docs/ECOSYSTEM.md)**

The same four links open the Documentation section of every repository
in the family. The manual is also on the command line (`dot help --manual`,
`--manual pdf`, `--manual text | less`, `--manual --offline` from the
bundled snapshot); the API reference lists every `dot` subcommand,
generated from the plugin manifests (`man dot` after install);
Development reproduces every CI gate locally; the map says which
component owns what.

The manual is published in nine formats (single- and multi-page
HTML, PDF, EPUB, ASCII text, compressed variants, Markdown source)
and rebuilds on every change from [`docs/manual/`](docs/manual/).

| Document | Covers |
|---|---|
| [`docs/STRUCTURE.md`](docs/STRUCTURE.md) | Every top-level path, the chezmoi naming contract, where to make which change. |
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | Startup strategies, `_cached_eval`, lazy hydration, artifact and ultra-fast modes. |
| [`docs/adr/`](docs/adr/README.md) | Decision records, from CI/CD, shell performance, the CLI architecture and multi-shell parity to plugin trust, read-only MCP isolation, the command naming system and the family's version lockstep. |
| [`docs/reference/`](docs/reference/) | Aliases, feature flags, fonts, PowerShell parity, profiles, scripts, support matrix, themes, tools, `dot` utilities. |
| [`docs/security/`](docs/security/README.md) | Threat model, install verification, fuzzing, secrets, encryption, MCP policy, commit signing, CI pinning, egress allowlist, key rotation, release verification, Scorecard, compliance, incident response. |
| [`docs/operations/`](docs/operations/OPERATIONS.md) | Release pipeline, version sync, performance, reliability, coverage, drift, registry, attestation, CI cadence, migration between versions. |
| [`docs/guides/`](docs/guides/INSTALL.md) | Install, theming, Neovim IDE, troubleshooting, WSL2 + Nix. |
| [`docs/packaging.md`](docs/packaging.md) | For distro maintainers: licence grant, toolchain floors, dependency pin model, offline build/test, signature verification. |
| [`SECURITY.md`](SECURITY.md) · [`GOVERNANCE.md`](GOVERNANCE.md) · [`CONTRIBUTING.md`](CONTRIBUTING.md) · [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md) | Reporting, decision model, contribution workflow, community expectations. |
| [`CHANGELOG.md`](CHANGELOG.md) | Per-release notes. **The complete record** — every release appears here. |
| [`AGENTS.md`](AGENTS.md) / [`CLAUDE.md`](CLAUDE.md) | Invariants for AI-assisted contributors; `CLAUDE.md` is canonical, `AGENTS.md` is rendered from it. |

---

## Stability guarantees

- **Versioning.** [SemVer](https://semver.org) with
  `defaults/.chezmoidata.toml` as the source of truth, mirrored to
  the non-template version surfaces by `scripts/version-sync.sh` and
  checked in CI.
  During the `0.2.x` series every release is a patch bump; a change
  that breaks an existing machine (a renamed command, a moved
  managed path, a changed flag default) is called out in its
  `CHANGELOG.md` entry and, where relevant, in
  [`docs/operations/MIGRATION.md`](docs/operations/MIGRATION.md)
  with a migration or rollback script under `install/migrate/`
  ([`GOVERNANCE.md`](GOVERNANCE.md)).

- **Output stability.** For a tool that generates files, output *is*
  API. Machine-readable outputs carry a schema version —
  `dot tool export` conforms to
  [`docs/schema/dot-env-v1.json`](docs/schema/dot-env-v1.json), the
  registry index to
  [`docs/schema/dot-registry-v1.json`](docs/schema/dot-registry-v1.json) —
  and a change to their shape is a new schema version, not an edit
  to `v1`. Generated artefacts that other tools consume
  (`themes.toml`, shell completions, [`AGENTS.md`](AGENTS.md) and the harness
  stubs, the command index) are produced by generators whose output
  is diffed in CI; a behavioural change to what a generator emits is
  treated as breaking and recorded in the changelog even when no
  command-line flag moves. The human-facing text of `dot --help`,
  `version`, `doctor`, `perf`, and `health` is pinned by golden
  snapshots and changes only with a deliberate snapshot update in
  the same commit.

- **Command-line contract.** Command names, `--json` output and exit
  codes (0 ok, 1 warning or check failed, 2 critical, 64 usage error,
  75 temporary failure, 127 unknown or removed command, 130
  interrupted) are API: a change to any of them is breaking even when no
  code signature moves, and is named in the `CHANGELOG.md` entry of
  the release that makes it. A renamed command keeps its old name for
  one family release, printing the new spelling once per shell
  session, then exits 127 with a hint
  ([ADR-020](docs/adr/ADR-020-command-naming-system.md)). In the
  `0.x` series any release may carry such a change; none carries one
  silently.

- **Minimum toolchain.** Raised only with the reason recorded in the
  `CHANGELOG.md` entry, never silently — policy, version axis, and
  history in
  [`docs/MINIMUM-TOOLCHAIN.md`](docs/MINIMUM-TOOLCHAIN.md).

- **Deprecations** are announced before removal with the removal
  release named up front:
  [`docs/reference/ALIASES_DEPRECATIONS.md`](docs/reference/ALIASES_DEPRECATIONS.md)
  records each deprecated alias, its replacement, and its `Remove In`
  version, and `dot shell alias show <alias>` reports the same from the
  CLI. The deprecation window is the span between the release that
  adds the row and the release named in `Remove In`.

---

## License

Dual-licensed under [Apache 2.0](https://www.apache.org/licenses/LICENSE-2.0) or [MIT](https://opensource.org/licenses/MIT), at your option. See [`LICENSE-APACHE`](LICENSE-APACHE) and [`LICENSE-MIT`](LICENSE-MIT).

See [CHANGELOG.md](CHANGELOG.md) for release history.

---

**THE ARCHITECT** ᛫ [Sebastien Rousseau](https://sebastienrousseau.com)
**THE ENGINE** ᛞ [EUXIS](https://github.com/sebastienrousseau/euxis) ᛫ Enterprise Unified Execution Intelligence System

<p align="right"><a href="#contents">Back to Top</a></p>
