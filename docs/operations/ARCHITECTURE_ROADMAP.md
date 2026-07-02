---
title: "Architecture & Roadmap — cross-shell consistency, performance, decoupling"
date: 2026-07-01
status: living document
---

# Architecture & Roadmap

This document captures a deep-dive across four fronts — cross-shell
consistency, real startup performance, the 2026 competitive/research
landscape, and a plan to decouple optional subsystems (`dot ai`, MCP, LSP)
into companion repos around a stable core. It is the source of truth for
the multi-phase program tracked below.

> Honesty policy: every performance number here is **measured** with
> `hyperfine` (warmed up), reproducible with the harness in
> `tests/performance/bench.sh` (interactive sessions, all installed shells)
> and `dot benchmark`. Estimates are labelled as such. The
> built-in `dot doctor` perf readout historically **understated** real
> startup because it timed a narrower slice — Phase 0 reconciles that.

## 1. Measured performance baseline (2026-07-01, Apple Silicon)

Method: `hyperfine -N --warmup 5` on the deployed config; `exit`-on-launch.

| Shell   | Startup (mean) | rc cost over ~7ms spawn | vs <30ms target |
|---------|----------------|-------------------------|-----------------|
| nushell | 24.8 ms        | —                       | meets           |
| bash    | 51.1 ms        | +43.6 ms                | 1.7× over       |
| zsh     | 66.3 ms        | +59.6 ms                | 2.2× over       |
| fish    | 128.8 ms       | bash-bridge tax         | 4.3× over       |

Baselines (pure process spawn, no rc): `zsh -fc exit` 6.7 ms,
`bash --norc` 7.5 ms.

Cost attribution (uncached tool-init subprocess cost, what `_cached_eval`
caches away): `mise activate` 17.7 ms, `atuin init` 7.1 ms,
`starship init` 4.0 ms, `zoxide init` 2.4 ms. `_cached_eval` **is**
working (cache files fresh; `zcompdump` is `zcompile`d), which is why zsh
is 66 ms and not ~97 ms.

**<30ms verdict (honest):** not reachable for the *full eager stack*
(mise + starship + atuin + zoxide + fzf + zinit + ~97 alias files + ~53
functions + compinit) on zsh/bash without tradeoffs. It **is** reachable
as a tunable "fast profile" + first-prompt deferral. nushell already
meets it; fish (bash-bridge) is the worst and the biggest opportunity.

## 2. Cross-shell consistency

- bash/zsh are native + single-source; **fish and nushell are bash
  *bridges*** — they filter aliases and wrap functions via `bash -c`
  subshells, adding a runtime bash dependency and silent parity loss.
- Parity gap: bash/zsh ~53 functions; fish 27 native; nushell 0 native;
  ~26 functions have no native impl; behaviour drifts (e.g. `goto` loses
  directory grouping in fish/nu).
- Duplication: eza-detection logic in bash + 7 fish files + nu wrappers;
  `_cached_eval` reimplemented four times.
- Direction: a **manifest-driven single source of truth** (one
  alias/function spec → per-shell generators). This also removes the
  class of parse-time collision that produced the zsh alias-shim bug.

## 3. Decoupling architecture

```
                     dotfiles (CORE)
   dot CLI · lib/dot/ui.sh · utils.sh · chezmoi base · plugin API
        |               |                 |             |
   dotfiles-ai     dotfiles-mcp      dotfiles-lsp    (future)
   dot ai,          registry,         dot/alias/
   cockpit,         policy,           chezmoi-template
   gateway          mcp-doctor        completions
```

Readiness (from the coupling audit):

| Subsystem | Coupling | Effort | Notes |
|-----------|----------|--------|-------|
| MCP | low (declarative JSON + one `cmd_mcp`) | low | isolated by design |
| LSP | none (one nvim plugin file) | trivial | already a lazy.nvim plugin |
| `dot ai` | high (ui.sh, utils.sh, dispatcher, chezmoi hooks) | high | needs the two contracts below |

Two foundational contracts must exist before AI can move cleanly:

1. **Extract `lib/dot/ui.sh` into a versioned shared lib** — AI *and* MCP
   depend on it; without this, decoupling means duplication.
2. **A `dot` plugin/extension API** — manifest-registered subcommands so
   companion repos add `dot ai` / `dot mcp` without forking the
   dispatcher.

## 4. 2026 landscape — gaps worth adopting (highest value first)

- **`dotfiles-mcp` with a secrets-redaction + allowlist policy layer** — a
  genuine gap no existing dotfiles-MCP fills; reuses the gitleaks / Atuin
  `history_filter` posture. Expose introspection via MCP **Resources**,
  actions via **Tools**.
- **`dotfiles-lsp`** = `dot` subcommand completions + alias awareness +
  **chezmoi-template-data-aware** completions → a novel *combination*
  (weekend-scale MVP using just-lsp / tcl-lsp patterns).
- Password-manager templating (1Password/Bitwarden), SOPS for shared
  secrets, **Bats** tests (reviewer lingua franca), devcontainer/Codespaces
  fast install path.

Context: chezmoi has won the dotfiles category; mise is baseline; Starship
has overtaken Powerlevel10k (maintenance-only); MCP spec 2025-11-25 is
under the Linux Foundation and safe to build on.

## 5. Staged roadmap

Each phase ships as its own reviewed PR with before/after benchmarks.

| Phase | Work | Risk | Target payoff |
|-------|------|------|---------------|
| **0** | Honest benchmark harness in-repo; make `dot doctor` report real numbers | low | truth in metrics |
| **1** | Perf quick-wins audit (deferral, compinit, zcompile, mise ordering) | low | verify + record baseline |
| **2** | Extract `lib/dot/ui.sh` → versioned shared lib | med | unblocks decoupling |
| **3** | `dot` plugin API + carve out `dotfiles-mcp` (lowest-risk repo) | med | proves the model |
| **4** | Cross-shell manifest (single source → per-shell generators); de-bash-bridge fish | high | consistency + fish speed |
| **5** | `dotfiles-ai` as a plugin repo | high | the decoupling goal |
| **6** | `dotfiles-lsp` MVP | low | differentiation |
| **7** | Docs + `examples/` + published honest benchmarks | med | completeness |

### Status

- **Phase 0 — done** (`feat/v0.2.509`): `tests/performance/bench.sh` now times
  every shell *interactively* (fish was measured non-interactively, faking
  ~12ms vs the real ~118ms) and includes nushell; `dot doctor` reports the
  real medians.
- **Phase 1 — done (audit)** (`feat/v0.2.509`): the documented quick-wins are
  **already implemented** in the deployed config, verified:
  - `compinit` deferred to first prompt, `-C` + daily-audit cache
    (`~/.config/zsh/rc.d/30-options.zsh`).
  - Eagerly-sourced hub files are `zcompile`d (`.zwc` present).
  - Plugins turbo-deferred (`zinit ice wait lucid`), fzf backgrounded, and
    mise/atuin/starship/zoxide inits deferred to post-prompt hydration and
    cached via `_cached_eval`.
  - `mise activate` ordering is a non-issue here: zsh uses `add-zsh-hook`
    (appends, no overwrite) and bash manages `PROMPT_COMMAND` explicitly.
  - Net: `zsh -ic exit` (which runs before the prompt, so it excludes the
    deferred inits) is ~66ms of *eager* rc — dominated by sourcing the large
    aggregated alias/function hubs. No safe further quick-win remains.
  - **Consequence:** sub-30ms is not reachable by tuning; it needs Phase 4
    (manifest → cut the eager alias/function volume) or a lean profile.
    fish (~118ms) is the biggest single opportunity (bash-bridge), also
    Phase 4.
- Phases 2–7 — planned; sequencing subject to review.
