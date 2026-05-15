---
render_with_liquid: false
title: "Roadmap 2026 — Implementation Plan"
description: "Executable plan derived from the round-1 + round-2 hard audit. Outstanding work, 4-week foundation, 4-week validation, 4-week distribution, and 4-6 month standards phases."
---

# Roadmap 2026 — Implementation Plan

This document is the executable plan derived from two rounds of audit + competitor analysis + 2026 trends + adoption-strategy research (see [`HARD_AUDIT_2026.md`](./HARD_AUDIT_2026.md)). Each item names files, sketches the implementation, defines acceptance criteria, and estimates effort.

The structure mirrors a 6-month execution window:

| Phase | Window | Theme |
|---|---|---|
| **A. Outstanding immediate** | now | Tasks blocked on user input (1 item) |
| **B. Build 2026 window** | days 0–4 (by 2026-05-19) | Ship before Microsoft Build keynotes (Codex Windows tailwind) |
| **C. Phase 1: Foundation** | weeks 1–4 | The three "go-deep" features + AGENTS.md coverage + cold-start lazy-load |
| **D. Phase 2: Validation** | weeks 5–8 | Evidence the new code works for non-maintainers |
| **E. Phase 3: Distribution** | weeks 9–12 | Show HN launch + partnerships + first case study |
| **F. Phase 4: Standards & defensive** | months 4–6 | EU CRA 2026-09-11 + AgentEnv defensive + compounding moats |

Effort is given as **person-days** (P-d) assuming a solo maintainer + AI assist (Claude Code or equivalent). All P-d estimates assume the test suite stays green and CI remains the gating signal.

---

## A. Outstanding immediate

### A1 — Generate the GPG disclosure key (C1 from audit) — **0.5 P-d (user only)**

**Goal.** Replace the `PLACEHOLDER` fingerprints in `.github/SECURITY.md:55` and `docs/security/KEY_ROTATION.md:24` so security researchers can encrypt vulnerability reports.

**Why this matters.** EU CRA 2026-09-11 mandates a 24-hour vulnerability reporting channel. A `PLACEHOLDER` GPG key blocks compliance. The audit cannot close this autonomously — only the maintainer holds the private key.

**Steps.**

1. `gpg --full-generate-key --expert` → RSA 4096 or Ed25519, valid 3 years, identity `security@sebastienrousseau.com`.
2. `gpg --export --armor security@sebastienrousseau.com > security-key.asc` and publish via [WKD](https://datatracker.ietf.org/doc/draft-koch-openpgp-webkey-service/) at `https://sebastienrousseau.com/.well-known/openpgpkey/hu/<hash>`.
3. Replace both `PLACEHOLDER` strings with the 40-hex fingerprint from `gpg --fingerprint`.
4. Commit the public key to `docs/security/security-pubkey.asc` for offline verification.
5. Update [`docs/security/COMMIT_SIGNING.md`](../security/COMMIT_SIGNING.md) with the new fingerprint.

**Acceptance.** `gpg --auto-key-locate clear,wkd,nodefault --locate-keys security@sebastienrousseau.com` returns the published key; `gh issue` template links to the working WKD URL.

**Files touched.** `.github/SECURITY.md`, `docs/security/KEY_ROTATION.md`, `docs/security/security-pubkey.asc` (new), `docs/security/COMMIT_SIGNING.md`.

---

## B. Build 2026 window (days 0–4, ship before 2026-05-19)

The combination of Codex Windows GA (2026-03-04, 500k waitlist → 2M WAU in 4 weeks), PowerShell 7.6 LTS GA (2026-03-12), and the Microsoft Build 2026 keynote week (May 19–21) opens a one-week marketing window. Three small items maximise its value.

### B1 — Add `windows-latest` to the CI matrix — **1 P-d**

**Goal.** Make the PowerShell 7.5+ support claim verifiable. Currently `ci.yml` runs ubuntu-latest + macos-latest only; Windows is aspirational.

**Sketch.**

1. New job `windows` in `.github/workflows/ci.yml`:
   - runs-on: `windows-latest`
   - install pwsh 7.6 via `actions/setup-pwsh`
   - run `pwsh -File scripts/ci/windows-smoke-test.ps1`
2. New `scripts/ci/windows-smoke-test.ps1` that:
   - asserts `dot.ps1` (or the bash dispatcher under WSL) starts cleanly
   - exercises `dot version`, `dot help`, `dot agents check`
   - verifies chezmoi can be invoked from PowerShell
3. Update `chezmoi` invocations in scripts that handle PowerShell to call `pwsh.exe` not `powershell.exe` (chezmoi issue #4888).
4. README update: "macOS, Linux, WSL2, Windows-native (PowerShell 7.5+)" promoted to first line.

**Acceptance.** Three new green checks on every PR: `CI / Windows / pwsh-smoke-test`, `Test / Windows / pwsh`, `Lint / Windows / PSScriptAnalyzer`.

**Files.** `.github/workflows/ci.yml` (job add), `scripts/ci/windows-smoke-test.ps1` (new), `README.md` (header), `scripts/dot/lib/platform.sh` (pwsh.exe over powershell.exe).

### B2 — Publish a Claude Code skill — **0.5 P-d**

**Goal.** Anthropic's skill marketplace is the path of least friction into the Claude Code user base. atxtechbro is already there; we are not.

**Sketch.**

1. New `dot_claude/skills/dotfiles-bootstrap/` directory:
   - `SKILL.md` (Claude Code skill descriptor)
   - `INSTALL.md` (one-line `dot init <user>` recipe)
2. Submit to [`anthropics/claude-code-marketplace`](https://github.com/anthropics/claude-code-marketplace) (the public skills directory) once it accepts community PRs; otherwise publish under our repo and link from the README.
3. The skill reads `$DOT_AGENT_PROFILE` to pick the right install command (`ask` mode for previews, `apply` mode for execution).

**Acceptance.** A new Claude Code session picks up the skill via `/skills` autocomplete; running it executes `dot init` with the user's preferred profile.

**Files.** `dot_claude/skills/dotfiles-bootstrap/SKILL.md` (new), `dot_claude/skills/dotfiles-bootstrap/INSTALL.md` (new), `README.md` (skill listing).

### B3 — Submit a mise plugin — **0.5 P-d**

**Goal.** mise's plugin ecosystem (`mise-en-place/registry`) is the closest analog to a "tap." A plugin listing both surfaces the framework to mise's audience and gets co-marketing from Jeff Dickey (devtools.fm episode #129 is the goal).

**Sketch.**

1. New repo `mise-plugin-dot` (separate from this one for plugin-naming convention):
   - `bin/list-all` → echoes "latest" plus the last 5 tags
   - `bin/install` → curls the verified installer, drops `dot` into the version-tree
   - `bin/exec-env` → exports `DOTFILES_*` env per profile
2. PR against [`mise-en-place/registry`](https://github.com/mise-en-place/registry) adding the plugin entry.
3. Co-marketing post on `mise.jdx.dev/blog` ("Bootstrap any dotfiles repo with `mise install dot@user/repo`"). Reach out to Jeff Dickey on GitHub Discussions.

**Acceptance.** `mise install dot@sebastienrousseau/dotfiles` bootstraps a clean machine successfully.

**Files.** External repo `mise-plugin-dot/`; PR against `mise-en-place/registry`; new section in this repo's `README.md` linking the plugin.

---

## C. Phase 1: Foundation (weeks 1–4)

The three "go-deep" features from audit §6.5 plus AGENTS.md coverage extension plus the cold-start lazy-load pass. **~22 P-d total** if executed sequentially; parallelism with AI assist can compress to ~12 P-d.

### C1 — `dot fleet apply --attest` (in-toto SLSA-L3 + Rekor tile log) — **5 P-d**

**Goal.** Per-host signed attestations that turn a fleet apply into a verifiable audit trail. No competitor with fleet ambitions (Ansible, dotsync, atxtechbro) has fleet-level transparency; this is the moat.

**Architecture.**

```
control machine                    target host
   │                                  │
   │ dot fleet apply --attest         │
   ├──► gather predicate metadata     │
   │    (source commit, chezmoi       │
   │     state hash, diff hash)       │
   ├──► sign via gitsign/Fulcio       │
   │    short-lived cert              │
   ├──► SSH apply                     │──► chezmoi apply
   │                                  │
   ├◄── stream resulting state hash   │
   │                                  │
   ├──► assemble in-toto Statement    │
   │    predicateType=                │
   │    https://slsa.dev/provenance/v1│
   ├──► upload to Rekor v2 tile log   │
   │    (default: rekor.sigstore.dev) │
   └──► store inclusion proof at      │
        ~/.local/state/dot/attest/    │
        <host>-<timestamp>.json       │
```

**Files to create.**

- `scripts/dot/commands/fleet/attest.sh` — attestation engine; called from `cmd_fleet_apply` when `--attest` is set.
- `scripts/dot/lib/intoto.sh` — small helper around `gitsign`/`cosign attest-blob` that emits a v1 SLSA predicate.
- `scripts/dot/lib/rekor.sh` — Rekor v2 client (curl + jq). Self-hosted log URL configurable via `DOT_REKOR_URL`.
- `docs/operations/FLEET_ATTESTATIONS.md` — predicate schema, verification recipe, how to detect a compromised control node.
- `.github/workflows/fleet-attest-conformance.yml` — runs the attestation flow on every PR against a 2-host LXC fixture, verifies the Rekor entry.

**Files to modify.**

- `scripts/dot/commands/fleet.sh:cmd_fleet_apply` — add `--attest` flag; gate the new attestation step on it.
- `docs/manual/03-reference/01-dot-cli.md` — extend the `dot fleet apply` section.

**Test plan.**

1. Unit: `tests/unit/fleet/test_attest_predicate.sh` — assert the in-toto Statement matches the SLSA v1 schema for known inputs.
2. Integration: a CI workflow that spins up two LXC containers, runs `dot fleet apply --attest`, fetches the Rekor entry, verifies the inclusion proof.
3. Negative: mutate the chezmoi state hash post-apply, re-fetch the Rekor entry, assert detection.

**Acceptance.** `dot fleet apply --attest` produces a Rekor entry per host; `dot fleet attest verify <host>` fetches the entry, validates the signature, and asserts the local state hash matches.

**Effort.** 5 P-d.

### C2 — `dot agent run <task>` (sandboxed worktree + MCP policy) — **8 P-d**

**Goal.** Round-1 gap #2, round-2 gap #1. atxtechbro/dotfiles ships parallel agent worktrees without sandboxing; McQuaid's "SandVault" ships sandboxing without MCP allow/deny. Combining both closes the highest-ranked competitive gap.

**Architecture.**

```
$ dot agent run "fix the flaky integration test"
  │
  ├──► git worktree add ~/.cache/dot/agents/fix-flaky-integration-test
  ├──► derive .claude/settings.local.json from current
  │    DOT_AGENT_PROFILE (allowed/denied MCP servers)
  ├──► launch agent inside:
  │      macOS  → sandbox-exec -f <profile> with --unshare-net
  │      Linux  → bwrap --unshare-net --ro-bind / / --bind worktree …
  ├──► userland HTTP CONNECT proxy on 127.0.0.1:<random>
  │    enforces the same Cedar policy for egress
  ├──► tmux new-window -d -t dot-agents:fix-flaky-…
  │    attaches a pane for human attach
  └──► register the worktree in
       ~/.local/state/dot/agents/active.jsonl
```

**Files to create.**

- `scripts/dot/commands/agent_run.sh` — orchestrator
- `scripts/dot/lib/sandbox/seatbelt.sb.tmpl` — macOS Seatbelt profile (writes scoped to worktree, no network except proxy)
- `scripts/dot/lib/sandbox/bwrap-wrapper.sh` — bubblewrap invocation for Linux
- `scripts/dot/lib/egress-proxy.go` — small Go binary (~150 lines) speaking HTTP CONNECT and enforcing Cedar; or `scripts/dot/lib/egress-proxy.py` if Python is acceptable
- `scripts/dot/lib/mcp-policy.sh` — render `.claude/settings.local.json` from `agent-profiles.json` allowed/denied lists
- `docs/operations/AGENT_SANDBOXING.md` — threat model, escape vectors, comparison vs Container Use / SandVault / agent-sandbox.nix

**Files to modify.**

- `dot_local/bin/executable_dot` — route `agent run` to the new entry-point
- `scripts/dot/commands/agent.sh:cmd_mode` — record sandboxed runs in the session log
- `dot_config/dotfiles/agent-profiles.json` (template) — add `allowedMcpServers` / `deniedMcpServers` per profile

**Sub-commands.**

- `dot agent run <task>` — spawn
- `dot agent attach <task>` — tmux attach the existing pane
- `dot agent list` — list active sandboxed agents
- `dot agent done <task>` — tear down (worktree gc + sandbox + secrets shred)

**Test plan.**

1. Smoke: spawn `dot agent run smoke` with `--cmd "echo hi"`; assert the worktree exists, the tmux pane exists, network egress is blocked except for the proxy.
2. Policy: configure `deniedMcpServers=["filesystem"]`; assert the spawned Claude session refuses filesystem tool calls.
3. Egress: assert `curl https://example.com` from inside the sandbox is rejected by the proxy unless `example.com` is in the allow-list.
4. Teardown: `dot agent done smoke` removes the worktree, kills the tmux window, shreds any secret files in the worktree.

**Acceptance.** `dot agent run "<task>"` produces a sandboxed worktree in <2s; the agent can read/write only inside the worktree; outbound HTTP is allowed only to allow-listed hosts.

**Effort.** 8 P-d (largest single item in Phase 1).

### C3 — `dot env emit` (unified signed manifest) — **5 P-d**

**Goal.** One `dot.env.toml` source-of-truth that generates AGENTS.md + per-harness files + `devcontainer-feature.json` + `mise.toml` + `Brewfile` + optional `flake.nix` + the in-toto subject list. Positions the repo as the reference implementation of a Portable Dotfiles Manifest — the eventual RFC §3.3 wanted to write.

**Source schema (`dot.env.toml`).**

```toml
[meta]
schema = "https://sebastienrousseau.github.io/dotfiles/schema/dot-env-v1.json"
version = "1.0.0"

[profile.workstation]
description = "Full development workstation"
features    = ["mise", "age-pq", "1password", "ghostty"]

[mcp.workstation]
allowed = ["filesystem", "git", "github", "fetch"]
denied  = ["shell-exec"]

[tools]
mise    = ["node@22", "rust@1.94", "go@1.25", "python@3.13"]
brew    = ["fish", "git", "neovim", "tmux", "starship", "1password-cli"]

[agents]
harnesses = ["claude", "agents-md", "cursor", "codex", "windsurf", "zed", "roo", "cline", "aider", "continue", "jules", "gemini"]
```

**Emitters.**

| Emitter | Output | Existing helper |
|---|---|---|
| `AGENTS.md` | one-file cross-harness | reuses `cmd_agents render` |
| Per-harness | `.claude/CLAUDE.md`, `.cursor/rules/`, `.windsurf/rules.md`, `.zed/agent-config.toml`, etc. | extends `cmd_agents` (see C4 below) |
| `devcontainer-feature.json` + `install.sh` | publishable Feature | new in `dot_local/share/dot/templates/devcontainer/` |
| `mise.toml` | tool versions | new |
| `Brewfile` | brew/cask/mas list (and polyglot lines per `[tools]`) | new |
| `flake.nix` | optional hermetic wrapper | new (opt-in via `--with-flake`) |
| in-toto subject list | feeds C1 attestations | reuses `lib/intoto.sh` |

**Files to create.**

- `scripts/dot/commands/env.sh` — dispatcher for `dot env emit | diff | validate`
- `scripts/dot/lib/emit/agents.sh`, `.../devcontainer.sh`, `.../mise.sh`, `.../brewfile.sh`, `.../nix.sh`
- `docs/schema/dot-env-v1.json` — JSON Schema (also valid for TOML via `taplo`)
- `docs/operations/MANIFEST.md` — schema reference and migration guide

**Files to modify.**

- `dot_local/bin/executable_dot` — route `env emit | diff | validate`
- `scripts/dot/commands/agents.sh` — consume the same source-of-truth (or accept `--from <toml>`)

**Test plan.**

1. Roundtrip: `dot env emit` from a sample manifest produces 12 artefacts; each is valid against its schema (`jq`, `taplo`, `nix flake show`, `chezmoi data`).
2. Diff: modify one tool version in the manifest, `dot env emit` shows a clean diff vs the previous output.
3. CI: a `.github/workflows/env-emit-conformance.yml` runs the roundtrip on every PR against `examples/dot.env.toml`.

**Acceptance.** A single `dot.env.toml` produces a working multi-OS dev environment via `chezmoi apply` + `mise install` + `brew bundle` + `dot agents render` without manual coordination.

**Effort.** 5 P-d.

### C4 — Extend AGENTS.md harness coverage — **2 P-d**

**Goal.** Audit §6.4 ranked harness coverage as the new round-2 gap #3. TonyCasey covers 9 harnesses; we cover 4. Catching up is mechanical.

**Sketch.** Extend `scripts/dot/commands/agents.sh::cmd_agents` render path:

| Harness | Output file | Format |
|---|---|---|
| Windsurf | `.windsurf/rules.md` | Markdown (same body as AGENTS.md) |
| Zed | `.zed/agent-config.toml` | TOML pointer |
| Roo | `.roo/rules.md` | Markdown |
| Cline | `.clinerules` | Markdown |
| Aider | `.aider.conf.yml` | YAML pointer |
| Continue | `.continuerc.json` | JSON pointer |
| Jules | `.jules/system.md` | Markdown |
| Gemini | `.gemini/GEMINI.md` | Markdown |

Each adds 8–15 lines to `cmd_agents`. The body content reuses `_agents_body` (already in place) plus a small per-harness header template.

**Files to modify.** `scripts/dot/commands/agents.sh` (+ ~150 lines).
**Files to create.** 8 small `.gitignore` exemptions if any harness directory needs special handling.

**Test plan.** New `tests/unit/auto/test_auto_cmd_agents_harnesses.sh` that runs `dot agents render`, asserts every expected file exists with `chmod 0644`, asserts the body matches CLAUDE.md.

**Acceptance.** `dot agents render` writes 12 files; `dot agents check` validates all 12 against CLAUDE.md.

**Effort.** 2 P-d.

### C5 — Cold-start lazy-load pass — **2 P-d**

**Goal.** Round-1 gap #3 was nominally closed at median 47ms locally, but `dot help` cold-start on CI runners is ~250ms (budget). Lazy-loading the language version managers takes another 50–100ms off.

**Sketch.**

1. Replace `eval "$(mise activate zsh)"` with a stub function that defers activation to first invocation of `mise`, `node`, `python`, etc.
2. Same for `nvm`, `pyenv`, `conda`, `direnv` if present.
3. Add a `_lazy_init` library helper to `dot_config/zsh/dot_zshrc.tmpl` so each lazy target gets the same treatment.
4. Verify `tests/integration/shell-startup-budget.sh` measures < 100ms on macOS bash, < 150ms on CI Ubuntu.

**Files to modify.** `dot_config/zsh/dot_zshrc.tmpl`, `dot_config/zsh/conf.d/*.zsh`, `.github/workflows/dot-cli-bench.yml` (budget tighten).

**Test plan.** `scripts/ci/dot-cli-startup-bench.sh --budget-ms 100` becomes the new CI gate. Plus an integration test that asserts `nvm`, `mise`, etc. still work after lazy-load (run `node --version` once and confirm activation fires).

**Acceptance.** Median cold-start `dot version` < 100ms on macOS local + < 150ms on ubuntu-latest CI runner.

**Effort.** 2 P-d.

---

## D. Phase 2: Validation (weeks 5–8)

The §3 wave shipped in an hour with AI assist; what we don't yet have is **evidence the new code works for someone other than the maintainer**. Phase 2 produces that evidence.

### D1 — Week 1: clean-VM bootstrap dry-run — **1 P-d**

**Goal.** Confirm `dot fleet apply` actually works against unfamiliar hardware.

**Steps.**

1. Spin up clean macOS Sequoia VM (via UTM/OrbStack) + clean Ubuntu 24.04 LXC + clean WSL2 Debian.
2. Run `dot init sebastienrousseau` against each; capture `dot doctor --json`.
3. Identify the first 5 failures; open issues against this repo with the failing output attached.

**Deliverable.** `docs/operations/COMPAT_MATRIX.md` — green/yellow/red table for the three target environments, with linked issue numbers.

### D2 — Week 2: paid stranger-bootstrap — **2 P-d**

**Goal.** Five `curl … | sh` runs on hardware the maintainer doesn't own.

**Steps.**

1. Post a Polar.sh bounty: $50 for each of the first 5 verified bootstraps producing a working `dot doctor` JSON.
2. Recipients submit their JSON + a screenshot of a working `dot agents check`.
3. Maintainer tracks results in `docs/operations/COMPAT_MATRIX.md`.

**Deliverable.** 5 verified bootstrap reports + any newly-discovered issues filed.

### D3 — Week 3: case-study capture — **1 P-d**

**Goal.** One recorded 20-minute screen capture from the most articulate Week 2 adopter ($200 budget).

**Deliverable.** A YouTube unlisted link + a transcript posted to `docs/community/case-study-001.md`.

### D4 — Week 4: blog post series + Reddit — **2 P-d**

**Goal.** Three blog posts on consecutive Tuesdays, posted to `/r/commandline` and `/r/unixporn`.

**Posts.**

1. *"I bootstrapped a stranger's laptop in 90 seconds."* — Lead with the Week 2 bounty findings.
2. *"How `dot fleet apply` reconciled my 4 machines."* — Lead with the asciinema cast.
3. *"AGENTS.md is the only AI config file that matters."* — Lead with the multi-harness generator screenshot.

**Deliverable.** Three posts indexed by Google + Reddit cross-posts.

---

## E. Phase 3: Distribution (weeks 9–12)

### E1 — Week 5: Influencer cold-DMs — **1 P-d**

**Goal.** ~5% conversion on 20 cold-DMs = one yes from a 5k–50k-follower account.

**Targets.** Simon Willison, Wes Bos, Kent C. Dodds, Mitchell Hashimoto, McKay Wrigley, ThePrimeagen, Theo, Boris Cherny (Claude Code lead), Jeff Dickey (mise), Tom Payne (chezmoi), DHH, Sindre Sorhus, fasterthanlime, Filippo Valsorda, Drew DeVault, Tim Bray, Julia Evans, Karpathy, Geoffrey Litt, James Long.

**Template message.** One sentence + one screenshot + one GIF link. Refer to specific recent work of the recipient to avoid feeling spammy.

### E2 — Week 6: README PRs to chezmoi + mise — **1 P-d**

**Goal.** Durable backlinks from the two ecosystems we depend on.

**Steps.**

1. PR against [twpayne/chezmoi](https://github.com/twpayne/chezmoi) README adding a "Tools built on chezmoi" section listing this repo.
2. PR against [mise-en-place/mise](https://github.com/mise-en-place/mise) README's "Used by" section.
3. Submit a `dot init <user>` cookbook page to chezmoi's docs site.

### E3 — Week 7: Conference CFPs — **2 P-d**

**Goal.** One accepted talk by month 12 = ~1k targeted stars + permanent YouTube asset.

**Submissions.**

1. **FOSDEM 2027** dev-tools devroom (deadline typically late Nov 2026; submit by July 2026): *"Reconciling N machines from one repo with a signed supply chain."*
2. **All Things Open 2026** (deadline ~July): *"AGENTS.md and the cross-harness AI config problem."*
3. **SCaLE 22x** (deadline ~Sept): *"From `curl | sh` to SLSA-grade: a five-year journey for one dotfiles repo."*

### E4 — Week 8: Public livestream — **1 P-d**

**Goal.** Live-bootstrap a viewer's machine; convert spectators to adopters.

**Steps.** Promote 7 days out on X/HN/Reddit; YouTube Live + Twitch simulcast; viewer submits their GitHub user via chat, maintainer runs `dot init <user>` live; capture for replay.

### E5 — Week 9: SaaS dry-run webhook — **2 P-d**

**Goal.** Trust-builder. Anyone hitting `curl https://dotfiles.io/dryrun/<user>` gets a plan back without an account.

**Sketch.** A tiny Cloudflare Worker (free tier) that runs `dot fleet apply --dry-run` server-side against the user's repo and returns the plan as JSON.

### E6 — Week 10: Co-authored case study — **1 P-d**

**Goal.** A named case study + employer logo for the Show HN landing page.

### E7 — Week 11: Show HN launch — **2 P-d**

**Title.** `Show HN: dot fleet apply — Ansible for personal devices, in 4kB of bash`

**Body.**

> I run 4 machines (2 laptops, a NAS, a VPS) and got tired of `chezmoi apply`-ing each one. So I built `dot fleet apply`: one TOML file lists the hosts, `dot fleet apply` SSHs to each in parallel, runs `chezmoi apply`, reports drift. It's chezmoi underneath, no agent install, ~4kB of bash. Signed releases, SBOMs, SLSA provenance — your dotfiles get the same supply chain a Kubernetes operator does. Repo + 90-second asciinema below.

**Assets.**

- asciinema cast of `dot fleet apply` across 4 hosts in <30s
- Screenshot of `dot doctor` Charm-style dashboard
- Link to the Week-10 case study

**Timing.** Tuesday between 7:00–9:00 AM PT (per Sturdy Statistics' Show HN analysis).

### E8 — Week 12: Sponsored newsletter timed to HN — **0.5 P-d**

**Goal.** Ride the residual HN traffic.

**Slot.** Console.dev or TLDR DevOps, $500–$1500/issue, the Tuesday after HN.

---

## F. Phase 4: Standards & defensive (months 4–6)

### F1 — `dot vuln-report` (EU CRA 2026-09-11 compliance) — **3 P-d**

**Goal.** The EU CRA mandates 24-hour vulnerability reporting and 72-hour active-exploitation reporting via the EU single-reporting platform. Without this, the framework cannot be distributed in the EU after 2026-09-11.

**Sketch.**

1. New `scripts/dot/commands/vuln_report.sh`:
   - reads a `vuln.toml` template
   - emits CRA-compliant JSON (`schema = https://ec.europa.eu/cra/single-reporting-platform/v1`)
   - submits via `curl` to the EU platform endpoint (when public) or stages locally for manual submission
2. `docs/security/CRA_DISCLOSURE.md` documenting the 24h / 72h SLA + the local staging recipe.
3. Update `SECURITY.md` to reference the CRA channel.

**Acceptance.** A test vulnerability runs end-to-end through `dot vuln-report --dry-run` producing a valid CRA JSON; integration test mocks the EU endpoint.

### F2 — `dotfiles.manifest.toml` schema (AgentEnv defensive) — **4 P-d**

**Goal.** Disruption-risk mitigation. If AAIF eventually standardises a workstation manifest (Anthropic Computer Use + MCP + Dev Containers convergence), we want to be a reference implementation.

**Sketch.** Lift the `dot.env.toml` schema (from C3) into a candidate spec:

1. Move `docs/schema/dot-env-v1.json` to a top-level repo: `sebastienrousseau/dotfiles-manifest-spec`.
2. Open an AAIF candidate-spec discussion at [agentic-ai-foundation/community](https://github.com/agentic-ai-foundation/community).
3. Make `dot apply` consume the manifest as canonical input; Go templates become an implementation detail.

**Acceptance.** A `dot.manifest.toml` validated by the schema can drive `chezmoi apply` end-to-end without inline template logic in user-visible files.

### F3 — Per-machine signed drift ledger — **4 P-d**

**Goal.** The compounding moat. Every `dot apply` writes a Sigstore-signed Rekor-style entry to `~/.local/share/dot/ledger`. Becomes the only honest answer to "what's actually running on this fleet?"

**Sketch.**

1. New `scripts/dot/lib/ledger.sh` — append-only signed log.
2. Each entry: `{ "ts": <iso8601>, "manifest_hash": <sha256>, "diff_hash": <sha256>, "host_fingerprint": <ssh-sk pub>, "signature": <fulcio-cert + sig> }`.
3. `dot ledger show` lists entries; `dot ledger verify` validates signatures; `dot ledger explain <ts>` reconstructs the state diff at that point.

**Acceptance.** After N `dot apply` runs, `dot ledger show` lists N entries; `dot ledger verify` reports rc 0; a hand-edited ledger entry causes verify to fail.

### F4 — MCP allow/deny first-class config in `dot agents` — **2 P-d**

**Goal.** Round-2 gap #2. Enterprise MCP gateways (TrueFoundry, MintMCP, Maxim) all use Cedar/OPA default-deny; Claude Code surfaces `allowedMcpServers` / `deniedMcpServers`. We currently have no per-profile MCP policy.

**Sketch.**

1. Extend `dot_config/dotfiles/agent-profiles.json` schema to include `allowedMcpServers` / `deniedMcpServers` per profile (already partly in place — formalise).
2. `dot agents render` outputs the policy block into each harness's settings file.
3. `dot agent run <task>` (C2) consumes the same policy in its egress proxy.

**Acceptance.** Switching `DOT_AGENT_PROFILE=audit` flips the MCP policy to a strict allow-list across every harness; `dot agents check` validates the policy bundles match.

### F5 — Hermetic Nix flake opt-in — **3 P-d**

**Goal.** Round-2 gap #4. home-manager + nix-darwin own the hermetic-reproducibility narrative. An opt-in `flake.nix` lets users who want bit-for-bit hermeticity stay in this framework instead of switching.

**Sketch.**

1. New `flake.nix` at the repo root (optional — gated behind a feature flag in `.chezmoidata.toml`).
2. Inputs: `nixpkgs`, `home-manager`, `flake-utils`.
3. Outputs: `homeConfigurations.<profile>` for each `.chezmoidata.toml` profile, mapping the chezmoi state to Nix `home.file` entries.
4. Optional CI workflow `.github/workflows/nix-flake-check.yml` runs `nix flake check` on every PR.

**Acceptance.** `nix run .#homeConfigurations.workstation.activate` produces a working workstation indistinguishable from `chezmoi apply` output.

### F6 — `dot sandbox` rootless container fallback — **3 P-d**

**Goal.** Round-2 gap #6. Adjacent to C2's worktree sandboxing; this is the "I want a disposable Ubuntu shell with my dotfiles" use case.

**Sketch.**

1. New `scripts/dot/commands/sandbox.sh` — picks `podman` > `distrobox` > `docker` > Apple Container.
2. Default image: `ubuntu:24.04` with `chezmoi`/`mise`/`bash` pre-installed.
3. Mounts the chezmoi source dir read-only; runs `chezmoi apply` into a fresh `$HOME`.
4. `dot sandbox enter` drops into a shell; `dot sandbox destroy` reaps.

**Acceptance.** `dot sandbox enter` produces a working shell with the user's dotfiles in <10s on a warm cache.

### F7 — OpenTelemetry instrumentation — **3 P-d**

**Goal.** Round-2 gap #8. atxtechbro emits OTel; we don't. Without traces, fleet apply audit is partial.

**Sketch.**

1. Add `scripts/dot/lib/otel.sh` — minimal OTLP/HTTP emitter (curl + jq).
2. Instrument key entry-points: `cmd_apply`, `cmd_fleet_apply`, `cmd_agent_run`, `cmd_doctor`.
3. Spans: command name + duration + exit code + profile + host.
4. Configurable via `DOT_OTEL_ENDPOINT` env (default unset = no-op).
5. CI workflow exports traces to a local Jaeger to verify schema.

**Acceptance.** Setting `DOT_OTEL_ENDPOINT=http://localhost:4318` produces spans visible in Jaeger for every command.

### F8 — Encrypted secrets default for `dot init` — **1 P-d**

**Goal.** Round-2 gap #9. age 1.3+ ships hybrid PQ recipients; SOPS rides on age. NSA CNSA 2.0 mandates PQ for new NSS by 2027-01-01.

**Sketch.** `dot init` runs `age-keygen -pq` on first setup, populates `.chezmoi.toml.tmpl` with the encryption block, and emits a one-page README about key rotation.

**Acceptance.** A fresh `dot init` produces an encrypted secrets directory ready for `chezmoi add --encrypt`.

### F9 — Devcontainer Features publication — **1 P-d**

**Goal.** Round-2 gap #10. `containers.dev` Features are the de facto distribution channel for Codespaces-aware dotfiles.

**Sketch.**

1. New repo `dotfiles-devcontainer-feature/` with `devcontainer-feature.json` + `install.sh` that bootstraps via `dot init` inside a container.
2. Submit to [containers.dev community features registry](https://containers.dev/features).
3. Add a `.devcontainer/devcontainer.json` example to the main repo showing how to consume it.

**Acceptance.** A Codespace launched with `"features": { "ghcr.io/sebastienrousseau/dotfiles:1": {} }` boots with the maintainer's dotfiles applied.

### F10 — Claude Code Marketplace listing — **0.5 P-d**

**Goal.** Listed in [claudemarketplaces.com](https://claudemarketplaces.com) the way atxtechbro is. Cheap distribution win.

**Sketch.** Add the project metadata to the marketplace registry; submit a PR.

---

## Cross-cutting concerns

### Testing strategy

- Each new command gets a `test_auto_cmd_<name>.sh` in `tests/unit/auto/` exercising `--help`, no-arg, an invalid flag, and (where safe) the happy path under `cov_setup_sandbox`.
- C1/C2/C3 each get an integration test under `tests/integration/` running against LXC fixtures in CI.
- `dot-cli-bench.yml` budget tightens to 100ms by end of Phase 1.
- `tests/framework/test_runner.sh` should stay green throughout.

### CI matrix expansion

| Job | Today | After Phase 1 | After Phase 4 |
|---|---|---|---|
| ubuntu-latest | ✅ | ✅ | ✅ |
| macos-latest | ✅ | ✅ | ✅ |
| macos-14 (arm) | ✅ | ✅ | ✅ |
| windows-latest (pwsh 7.6) | ❌ | ✅ (B1) | ✅ |
| ubuntu-latest + Nix flake | ❌ | ❌ | ✅ (F5) |
| LXC fleet fixture | ❌ | ✅ (C1) | ✅ |
| OTel emit + Jaeger | ❌ | ❌ | ✅ (F7) |

### Version cadence

| Window | Version | Rationale |
|---|---|---|
| End of Phase A + B | `0.2.503` | small patch covering B1/B2/B3 |
| End of Phase 1 | `0.3.0` | minor bump — three "go-deep" features ship |
| End of Phase 2 | `0.3.1` | bug-fix release covering Week 1-4 issues |
| End of Phase 3 | `0.4.0` | minor bump — public launch |
| End of Phase 4 | `1.0.0` | major bump — `dot.manifest.toml` v1 declared stable, EU CRA compliant, drift ledger live |

### Documentation budget

Per [HARD_AUDIT_2026.md §3.4](./HARD_AUDIT_2026.md), 25% of each release cycle is documentation. Specifically:

- Every new command in Phase 1 gets a section in `docs/manual/03-reference/01-dot-cli.md` + a `command-index.md` entry + a CHANGELOG line.
- Phase 4 adds three large docs: `MANIFEST.md`, `LEDGER.md`, `AGENT_SANDBOXING.md`.
- The `HARD_AUDIT_2026.md` Part 5/6 dispositions are kept current with each commit (✅ shipped / ⏳ deferred / ❌ rejected with reason).

### Risk register

| Risk | Probability | Impact | Mitigation |
|---|---|---|---|
| C2 sandbox escape on macOS via Seatbelt limitation | Medium | High | Pin the Seatbelt profile to a known-good public template (e.g., Hardened-Runtime style); document escape vectors |
| C1 Rekor v2 instance reaches rate limit | Low | Medium | Self-hostable tile log fallback; document in `FLEET_ATTESTATIONS.md` |
| EU CRA endpoint not yet public by 2026-09-11 | Medium | High | Local-staging path (F1) works offline; submit manually via `cra-reporting@ec.europa.eu` if needed |
| Build 2026 timing window missed | Already past for some keynotes | Medium | The Codex Windows + PowerShell 7.6 tailwinds persist through Q4 2026 |
| AAIF moves slowly | High | Low | Schema (F2) is useful internally even without AAIF adoption |
| Solo maintainer burnout | Medium | High | Anti-pattern watch from HARD_AUDIT_2026 §3.4 — don't ship SaaS in months 0–6, don't build plugins before core is stable |

### Effort summary

| Phase | Items | Total P-d |
|---|---|---|
| A — Outstanding | A1 | 0.5 |
| B — Build window | B1, B2, B3 | 2 |
| C — Foundation | C1–C5 | 22 |
| D — Validation | D1–D4 | 6 |
| E — Distribution | E1–E8 | 10.5 |
| F — Standards & defensive | F1–F10 | 24.5 |
| **Total** |  | **65.5 P-d** (~13 weeks of focused solo work, ~7 weeks with AI assist) |

### Critical path

```
A1 (GPG)               ──┐
B1 (Windows CI)        ──┤
B2 (Anthropic skill)   ──┤
B3 (mise plugin)       ──┘  ─── all parallel, target end of Day 4

                            ┌─ C1 (fleet attest) ──┐
C-phase (parallel-able) ────┤  C2 (agent run)     ├── tests → C-release
                            │  C3 (env emit)      │
                            │  C4 (AGENTS+8)      │
                            └─ C5 (lazy load) ────┘

D-phase ────── strictly sequential (each week depends on prior outputs)

E-phase ────── strictly sequential (HN launch in week 11 anchors)

F-phase ────── most items parallelisable, F1 (CRA) is gating on 2026-09-11
```

The critical-path items are **A1 (GPG)** (blocks F1 SBOM signing), **C2 (`dot agent run`)** (largest effort), **F1 (`dot vuln-report`)** (date-bound), and **E7 (Show HN)** (anchors Phase 3).

---

## How to use this document

- Pick items by phase, not by ID. Phase ordering is intentional.
- For each picked item, open a GitHub issue with the body copy-pasted from the relevant section here, link back to this file.
- Update the disposition table in [`HARD_AUDIT_2026.md`](./HARD_AUDIT_2026.md) Part 5 / Part 6 when the work lands.
- Treat the effort estimates as 50%-confidence ranges, not commitments. Re-estimate after every two items shipped.

Generated 2026-05-15 from `HARD_AUDIT_2026.md` rounds 1 + 2. Source agents archived at `/private/tmp/claude-501/-Users-seb--dotfiles/508d0d2f-ff7f-4f1b-a07d-d3e0cbb718f0/tasks/` for traceability.
