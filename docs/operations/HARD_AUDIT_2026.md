---
render_with_liquid: false
title: "Hard Audit 2026"
description: "Operational reliability, performance parity, documentation accuracy + 2026 industry positioning."
---

# Hard Audit 2026 + Path to De Facto

A consolidated audit of `sebastienrousseau/dotfiles` v0.2.502 across three internal dimensions (operational reliability + performance, documentation accuracy, cross-platform + security posture) and three external dimensions (competitor matrix, 2026 industry trends, adoption playbook). Produced 2026-05-15 by six parallel research tracks.

The goal stated by the maintainer: become the de facto workstation provisioning tool for every OS. This document is the punch list to get there.

## Part 1 — Internal audit findings

### 1.1 Critical (fix immediately)

| # | File:line | Finding | Recommended fix |
|---|---|---|---|
| C1 | `.github/SECURITY.md:55` and `docs/security/KEY_ROTATION.md:24` | GPG disclosure key is `PLACEHOLDER`. Researchers cannot encrypt vulnerability reports today. | Generate `security@sebastienrousseau.com` GPG key, publish via WKD, paste fingerprint in both files. |
| C2 | `docs/manual/00-introduction.md:7`, `docs/manual/_toc.yml:5`, `docs/index.md:9-10,41`, `docs/manual/03-reference/02-config-files.md:36,222` | Version drift — five doc surfaces still say `v0.2.501` but `.chezmoidata.toml` declares `0.2.502`. | Mechanical bump to `0.2.502`. |
| C3 | `docs/manual/03-reference/01-dot-cli.md:154-213,364-366` and `docs/manual/command-index.md:14,23,26,45,58,61` | Six commands documented but not implemented: `dot verify`, `dot benchmark`, `dot prewarm`, `dot clean-cache`, `dot remove`, `dot update`. | Remove the doc sections (these were never shipped) or open issues to implement; do not leave doc-only commands. |

### 1.2 High (fix this release)

| # | File:line | Finding | Recommended fix |
|---|---|---|---|
| H1 | `dot_local/bin/executable_dot:589` | `source "$_user_cmd" "$@"` — a user-provided custom command calling `exit` kills the whole CLI. | Replace with `bash "$_user_cmd" "$@"` or `( source "$_user_cmd" "$@" )` subshell. |
| H2 | `scripts/dot/commands/agent.sh:28,51,83-92` | `_agent_default_profile()` calls `jq` before `_agent_assert_dependencies()` runs in `cmd_mode()`. On a host without jq, error message is cryptic. | Move dependency assertion to top of every entry-point. |
| H3 | `scripts/dot/commands/fleet.sh:294-297` | GNU vs BSD `sed -i` branch isn't atomic; concurrent `dot fleet namespace set` calls can corrupt `.chezmoidata.toml`. | Use `mktemp` + `mv` (atomic) and wrap with `flock`. |
| H4 | `dot_config/zsh/dot_zshrc.tmpl:220-221` | `_cached_eval` writes cache with `mv "$cache.tmp.$$" "$cache"` — PID collision possible between two shells. Cold-start affected. | Use `mktemp` instead of `$$`. |
| H5 | `scripts/dot/commands/meta.sh:64-67` | `rm -rf "$cache_dir/zsh"/*-init.zsh` — if the glob doesn't match, expands to the literal pattern and the `-rf` removes the wrong path. | Guard with `[[ -d ... ]]` or use `find ... -type f -delete`. |
| H6 | `install.sh:177-198` | Chezmoi installer downloaded over `https://get.chezmoi.io` with size/shebang validation but no cryptographic signature check. | Pin chezmoi release by SHA + verify cosign signature. |
| H7 | `install/lib/package_managers.sh:56` | Homebrew installer runs from `brew.sh` with a warning but no SHA256 verification. | Fetch installer, verify SHA256 against the official GitHub release, then execute. |
| H8 | `install/lib/installers.sh:40-60` | Binary downloads SHA256-verify, but the checksum URL is not pinned. DNS attacker can redirect both binary and checksum together. | Pin checksum URLs to GitHub Releases API with commit SHA. |
| H9 | `scripts/dot/lib/platform.sh:42-65` | `dot_path_to_unix/native()` silently returns the Windows path if `wslpath` is missing — caller cannot tell success from failure. | Return non-zero when `wslpath` is required but absent; document the contract. |

### 1.3 Medium (fix next 2 releases)

| # | File:line | Finding | Recommended fix |
|---|---|---|---|
| M1 | `scripts/dot/commands/core.sh:81` | `chezmoi status \|\| true` loses error context — can't distinguish "tree is clean" from "chezmoi crashed". | Capture into a variable and inspect the exit code. |
| M2 | `dot_local/bin/executable_dot:542` | `route="$(_dot_command_route "$COMMAND" \|\| true)"` is defensible (falls through to the user-command path that emits a proper error), but reads as a bug. | Add comment explaining intent or refactor to explicit `if`. |
| M3 | `scripts/dot/lib/ui.sh:335,340` | `mktemp` output race in `ui_run_cmd()` between subshell write and parent read; under load the `cat` can hit an empty file. | Switch to `read rc < "$rc_file"` or `[[ -s "$rc_file" ]]` guard. |
| M4 | `scripts/dot/commands/agent.sh:221-224,338-341,385-388` | `set +e / "$@" / set -e` blocks log failure but propagate the original exit code; callers can't tell intentional vs accidental. | Document the contract or restructure to `if !`. |
| M5 | `scripts/security/lock-configs.sh:27-33` | `sudo chattr +i` silently fails when sudo is unavailable in automation. | Fail explicitly when sudo is required. |
| M6 | `dot_config/zsh/dot_zshrc.tmpl:147-159` | `_cached_eval` mtime check doesn't follow symlinks — a `mise` upgrade that only flips a symlink target won't bust the cache. | Resolve via `readlink -f` and track the chain. |
| M7 | `scripts/ci/install-chezmoi-verified.sh:25-32` | Only x86_64 + arm64 are supported. ppc64le, s390x, riscv64 fail silently. | Document supported architectures and emit a clear error otherwise. |

### 1.4 Low (track in backlog)

`dot_config/zsh/dot_zshrc.tmpl:308-334` (hardcoded `/opt/homebrew` paths), `scripts/dot/commands/aliases.sh:112` (`umask 077 && mktemp` — BSD `mktemp` ignores umask), `install.sh:111` (WSL detection via `/proc/version` only), CHANGELOG header still anchored to v0.2.501.

### 1.5 What's already excellent (keep)

- **Release supply chain.** `security-release.yml` runs Cosign keyless signing + SBOM generation + SLSA provenance, all SHA-pinned. No findings.
- **GitHub Actions hygiene.** Every `uses:` is SHA-pinned, reusable workflows blocked by `lint-reusable-pins.sh`. Strong.
- **Secrets handling.** `scripts/lib/secrets_provider.sh` correctly isolates macOS keychain / `pass` / `age` providers with no plaintext leakage.
- **Test suite.** 4035 unit tests, 47.57% measured line coverage with documented structural ceiling.

## Part 2 — Competitive position (May 2026)

### 2.1 Where this repo is already ahead

| Capability | Closest competitor | Where the moat sits |
|---|---|---|
| Signed + attested supply chain on a *dotfiles* framework | mise (signs its binaries, but not user environments) | `security-release.yml` + `sbom-diff.yml` + `scorecard.yml` + `pr-signature.yml` is unique combination. |
| Drift detection on a schedule | home-manager (prevents drift via Nix; doesn't *detect*) | `.github/workflows/drift-detection.yml` + `dot doctor`. |
| First-class `dot` CLI dispatcher | none — competitors expose the engine (chezmoi/yadm/nix) | Typed subcommand surface gives the project a brand. |
| Wallpaper-driven theming | none | `executable_dot-theme-sync` — consumer-grade polish. |
| Profiles + feature flags | yadm alternates, chezmoi data | The *profile abstraction* (workstation/server/minimal) is explicit. |
| Fuzz-tested installer | none | `install-fuzz.yml`. |
| Conventional commits + SSH-signed enforced by hook | rare even in enterprise | Auditable provenance of the dotfiles themselves. |
| Native AI affordances in CLI | atxtechbro/dotfiles | `dot-ai`, `git-ai-commit`, `git-ai-diff`, repo-scoped `CLAUDE.md`. |

### 2.2 Where competitors are pulling ahead

Ranked by adoption-blocking impact:

1. **Multi-harness AI config (AGENTS.md standard).** OpenAI started AGENTS.md, Linux Foundation Agentic AI Foundation now stewards it; Codex, Copilot, Cursor, Windsurf, Amp, and Devin all read it natively. Claude Code keeps CLAUDE.md but interop is open. atxtechbro/dotfiles and ai-dotfiles-manager already template both. **Action:** refactor `dot_claude/` into a `dot_agents/` source that emits `AGENTS.md`, `CLAUDE.md`, `.cursor/rules`, `.codex/config` from one DSL.
2. **MCP servers as first-class deployable artifact.** 50+ official + ~5,000 community MCP servers. Per-host, per-profile, per-project MCP allow/deny lists are now an expected dotfiles surface. **Action:** template `~/.config/claude/managed-mcp.json` per profile; ship `dot mcp registry` for discovery (already partially there).
3. **Sub-100ms shell cold start as the bar.** Fish 4.0 (Rust) starts under 100ms; well-tuned zsh+zinit+p10k lands under 70ms. **Action:** add `zsh-bench` to CI; gate PRs on a regression budget; lazy-load mise/nvm/conda/pyenv by default.
4. **Post-quantum age recipients.** age v1.3.0+ has hybrid ML-KEM-768 PQ recipients; SOPS rides on age. NSA CNSA 2.0 mandates PQ for new NSS by 2027-01-01. **Action:** default new repos to hybrid PQ recipients; document key-rotation flow.
5. **Sandboxed per-task agent worktrees.** McQuaid-style ephemeral envs are the dominant 2026 power-user pattern. **Action:** ship `dot agent run <task>` that spawns a worktree + tmux pane.
6. **Hermetic reproducibility opt-in.** home-manager/nix-darwin/devbox have it; chezmoi templates don't. **Action:** add an optional `flake.nix` profile that wraps the chezmoi state for users who want bit-for-bit hermeticity.
7. **Devcontainer-aware fast path.** Codespaces/dev-containers users get a project context that overlaps with dotfiles; the boundary needs to be cooperative. **Action:** detect dev-container context and run a sub-60s user-only install path.
8. **Native Windows PowerShell parity.** PowerShell 7.4 LTS ends 2026-11-10; 7.5 is the new minimum. Repo claims PS7.5+ support but no Windows runner in `ci.yml`. **Action:** add `windows-latest` to the test matrix.
9. **OpenTelemetry hooks on shell + agents.** atxtechbro/dotfiles emits OTel. **Action:** ship optional OTel wrapper around `dot` commands; emit drift events.
10. **gitsign + Rekor transparency logs.** Move from long-lived GPG to short-lived OIDC identities. **Action:** offer gitsign as an optional commit-signing path; document Rekor verification.

### 2.3 The 2026 elevator pitch

> **"The first dotfiles framework with a SLSA-grade supply chain and a built-in AI agent runtime."** Where chezmoi is a templating engine, Nix is a build system, and dotbot is an installer, this project is a *signed, attested, AI-aware workstation distribution* — a `dot` CLI that gives you reproducible profiles across macOS/Linux/WSL/PowerShell, drift detection and self-healing on a schedule, SBOM-diffed releases under Scorecard scrutiny, and a Claude/MCP-ready agent harness on day one.

## Part 3 — Adoption roadmap

### 3.1 Months 0–6: Foundation

Foundational features (ship these specifically):

1. **Signed bootstrap.** `curl … | sh` is currently table stakes. Differentiate by displaying the Cosign verification step in install output. Already 80% there with `install/lib/installers.sh` — close the gap in H6, H7, H8.
2. **`dot init <github-user>` analogue.** Bootstrap any user's dotfiles repo through this framework's harness. Turns the tool into a runtime, not just one person's config.
3. **`dot health` as the killer demo.** Make it Charm-quality (lipgloss/bubbletea-tier visuals). Visual hooks drive HN upvotes more than feature lists.
4. **AGENTS.md generator (close gap #1 from 2.2).** Single-source multi-harness agent config.
5. **Sub-100ms `dot` CLI cold start.** Currently `dot help` takes longer than is competitive. Add a startup benchmark to CI and treat it as a gate.

Distribution targets (pick 3, not 5): Homebrew tap first, AUR second, Scoop third (skip winget initially).

Community moves:
- **Show HN:** lead with the wallpaper-driven themes (v0.2.502). Screenshot-driven hook nobody else has.
- **Blog post series (3 posts):** "Why I stopped using chezmoi directly", "Bootstrapping 15 machines from one git repo in <90 seconds", "Secrets in dotfiles: a 2026 threat model".
- **CFPs:** FOSDEM 2027 (dev tools devroom), All Things Open 2026, SCaLE LA. Skip KubeCon.
- **Sponsor 2–3 newsletters at $500–1500/issue:** Console.dev, TLDR DevOps, Changelog News.

### 3.2 Months 6–12: Differentiation

**Hero feature / USP:** `dot fleet apply` against N machines over SSH from one control machine, with state reconciliation and drift detection. Chezmoi is single-machine. Ansible is fleet-but-heavyweight. Position as "Ansible for personal devices and home lab" — 3 laptops, a Pi, a VPS, a work desktop, all reconciled from one source. Concrete, technical, nobody owns the niche.

Reference customers worth pursuing:
- Indie hackers running 3–5 machines (Pieter Levels-style operators).
- One small consultancy (10–30 engineers) — the "we onboard new hires in 20 minutes" testimonial.
- One OSS maintainer with a YouTube channel — a video walkthrough is worth 10,000 stars.

Integration partnerships:
- **mise plugin or native integration** — Jeff Dickey is responsive.
- **1Password Developer Tools team** — they have a partner program.
- **GitHub Codespaces / Dev Containers** — devcontainer.json template that bootstraps via this framework.

### 3.3 Months 12–18: Lock-in

Network-effect features:

1. **Module registry (`dot registry`)** — like `brew tap` for dotfile modules. Users publish reusable bundles ("rust-dev-setup", "k8s-operator-laptop"). Once 50 modules exist, switching cost becomes real. Host as a GitHub-Pages-indexed JSON registry.
2. **Fleet API (hosted, freemium).** Webhook on `git push` triggers `dot apply` across registered machines. $0 self-hosted; $9/mo hosted; $49/mo teams.
3. **Telemetry-opt-in stats dashboard.** Public leaderboard of most-used modules drives social proof.

Standard-setting:
- Author a "Portable Dotfiles Manifest" RFC — TOML schema consumed by chezmoi/yadm/this. Even if competitors ignore it, you set the conversation.
- FOSDEM main-track talk: "Reconciling 30 machines from one repo."
- Quarterly state-of-dotfiles survey, like `State of JS`. Becomes the cited reference.

### 3.4 Anti-pattern watch

1. **Don't chase Windows parity before Linux is bulletproof.** Homebrew waited a decade for Linuxbrew. Ship Windows as "best effort" until month 12.
2. **Don't build hosted SaaS in months 0–6.** Devbox Cloud worked because Jetify had $30M. Self-hosted first, hosted control plane after 1,000+ active installs.
3. **Don't add a plugin system before the core is stable.** chezmoi waited 4 years before adding script hooks. Premature extensibility freezes bad APIs.
4. **Don't ignore documentation polish.** Tom Payne's chezmoi docs are competitor moat #1. Budget 25% of every release cycle to docs.
5. **Don't buy GitHub stars.** It poisons HN credibility and reference customers churn. Aim for 5k organic stars by month 18, not 50k bought ones.

## Part 4 — Disruption watch (18-month obsolescence risk)

1. **Agent-native config languages.** If an LLM agent can introspect intent ("set me up for Rust + Neovim + signed commits + PQ secrets") and emit the apply-plan directly, hand-written Go templates become an intermediate representation the user never touches. Mitigation: expose a stable declarative descriptor (TOML/JSON schema) and let agents target it, not the template syntax.
2. **Devcontainer + dotfiles convergence into one "AgentEnv" spec.** The Linux Foundation hosts both MCP and Agentic AI Foundation work; the most likely next step fuses dev-container project config with user dotfiles into one signed, attested, agent-readable manifest. Frameworks that don't map cleanly onto that spec will look legacy by 2027.
3. **Ephemeral, per-task sandboxed worktrees as the unit of "environment."** McQuaid-style sandboxed agent worktrees (one container/VM per branch, destroyed after merge) shift the "machine" from durable to disposable. A dotfiles framework optimized for one long-lived workstation will lose to one that hydrates a fresh sandbox in <10s with verified provenance.

## Part 5 — Recommended execution order

**This week (mechanical, low risk):**

1. Bump version drift (C2) across the five documented files.
2. Remove the six non-existent command sections (C3) from `docs/manual/03-reference/01-dot-cli.md` and `docs/manual/command-index.md`.
3. Fix H1 (`source` → `bash` in user-command path).
4. Add a comment or refactor for M2 (`|| true` on route resolution).

**This month (research + targeted):**

5. Generate GPG disclosure key, publish via WKD, fill placeholders (C1).
6. Make chezmoi installer verification cryptographic (H6).
7. SHA256-verify the Homebrew installer (H7).
8. Pin checksum URLs to GitHub Releases API (H8).
9. Fix the `sed -i` atomic write in fleet.sh (H3).

**This quarter (positioning):**

10. AGENTS.md generator with `dot_agents/` single source emitting `CLAUDE.md` / `AGENTS.md` / Cursor / Codex configs (closes the #1 competitive gap).
11. Add `zsh-bench` regression gate; lazy-load all language version managers (closes the #3 competitive gap).
12. Add `windows-latest` runner to the test matrix.
13. Pursue the mise + 1Password + Codespaces integrations (months 6–12 of the roadmap).

**This year (lock-in):**

14. Ship `dot fleet apply` SSH-mode as the hero feature (months 6–12).
15. Stand up `dot registry` (months 12–18).
16. Submit the Portable Dotfiles Manifest RFC.

---

Generated 2026-05-15 by a six-agent parallel review (audit-reliability, audit-docs, audit-platform-security, competitor-matrix, 2026-trends, adoption-playbook). Source agents archived in `/private/tmp/claude-501/-Users-seb--dotfiles/508d0d2f-ff7f-4f1b-a07d-d3e0cbb718f0/tasks/` for traceability.
