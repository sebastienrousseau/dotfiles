---
title: "Fish Startup in 2026: Cutting Interactive Shell Latency by Half with abbr on Multi-Shell Dotfiles"
description: Diagnosing and remediating a 232 ms fish cold-start on the .dotfiles multi-shell bridge — one printf format change, one chezmoi hook, half the latency.
date: 2026-07-05
---

# Fish Startup in 2026: Cutting Interactive Shell Latency by Half with `abbr` on Multi-Shell Dotfiles

*Interactive shells have become the primary interface for AI-augmented development; the difference between a 120 ms and a 230 ms first prompt compounds into measurable engineering-hour loss across a global fleet.*

*Sebastien Rousseau · Published 5 Jul 2026 · 10 min read*

## Why Interactive Shell Latency Matters in 2026 #

The AI-augmented developer opens a terminal dozens of times a day. In fleets running Claude Code, Codex CLI, GitHub Copilot CLI, or agentic frameworks that spawn subshells for every tool call, shell startup latency stops being a personal-comfort metric and becomes a **platform-engineering signal**.

The [.dotfiles reference framework](https://github.com/sebastienrousseau/dotfiles) treats sub-second shell startup as an SLO alongside SLSA-signed releases and MCP boundary enforcement. When a shell exceeds its budget, the framework's `dot health` command reports it as a failing check, not a warning — because a slow prompt on a workstation running 18 concurrent AI agents is a supply-chain-throughput problem, not an aesthetic one.

This article walks through the diagnosis and fix that took Fish cold-start latency from **231 ms → 119 ms** — a 48% reduction — on a workstation carrying ~900 bridged bash aliases into Fish for cross-shell parity. The remediation is a one-line change to a code-generation printf statement, plus a chezmoi hook that moves the cost out of the interactive path.

## The Multi-Shell Bridge 2026 Architecture Lens #

Cross-shell parity — the same aliases, functions, environment, and completions across bash, Zsh, Fish, and Nushell — is a distinct architectural property of a mature dotfiles framework. Each layer of that bridge carries its own performance tax:

| Layer | Design Decision | Why It Matters | Risk if Mishandled |
|---|---|---|---|
| **Source of truth** | Bash-hosted alias library (~900 entries) sourced by `zsh` and `bash` natively | Single canonical location prevents drift; matches how most upstream tooling assumes aliases live | Duplication across shells silently diverges; users on Fish or Nushell get a subtly different alias set |
| **Fish bridge** | `bash --norc --noprofile` subshell dumps `alias -p`, output translated and cached to `~/.cache/fish/bash-aliases.fish` | Fish has no `bash`-sourcing primitive; the bridge is unavoidable | Bridge runs at every shell start unless cached; cache invalidation timing determines the felt cost |
| **Cache format** | `abbr --add NAME -- VALUE` (this article's change) instead of `alias NAME=VALUE` | Fish's `alias` builtin allocates a function per entry (~183 µs each × 900 entries = ~165 ms); `abbr` is a command-line-time expansion at ~40 µs | Choosing `alias` for the cache format silently caps Fish cold-start at ~230 ms even on a warm cache |
| **Cache invalidation** | Compare source mtime + first-line format marker | Alias sources change on every `chezmoi apply`, invalidating the cache and forcing regen on the next shell — the exact moment the user opens a terminal to try their changes | Cache regen on the interactive path punishes the shell that opens right after configuration changes |
| **Pre-warm hook** | `run_onchange_after_` chezmoi hook rebuilds the cache during apply | Moves the ~200 ms regen cost off the user's first prompt into the apply step | Absence of a pre-warm hook makes the first post-apply shell feel broken |

## Key Interactive Shell Performance Signals #

| Signal | Operational Benchmark | Reference | Technical Platform Implementation |
|---|---|---|---|
| **Fish cold-start** | ≤ 200 ms first-prompt latency | Interactive-response threshold (Nielsen 1993, still the industry norm) | `hyperfine --warmup 2 'fish -i -c exit'` in CI; regression fails a PR if the median crosses threshold |
| **Fish warm-start** | ≤ 130 ms after cache is populated | Delta between cold/warm reveals cache-invalidation cost | Same command with `--warmup 3`; the mean tracks the fully-cached shell path |
| **First-post-apply latency** | Warm-shell parity — no cliff after `chezmoi apply` | Signals that regeneration lives outside the shell hot path | `chezmoi apply && hyperfine 'fish -i -c exit'` — cold and warm should be within noise |
| **Cache-format compatibility** | Auto-heal path when upgrading between cache formats | Ensures long-lived workstations don't inherit stale caches on framework upgrade | Staleness check compares first line of cache to expected format marker |
| **Bridge throughput** | ~40 µs per abbreviated entry, ~183 µs per aliased entry | Fish internals — measured, not documented | Choice of `abbr` over `alias` in the cache-emission format string |

## Diagnosis: Where the Milliseconds Went #

`fish --profile-startup=/tmp/f.prof -i -c 'exit'` emits a per-command trace with self-time and cumulative time. Sorted by cumulative time descending, one line dominated the warm-start budget:

```
Time (µs)  Sum (µs)  Command
   1687    132211    ----> source "$_alias_cache"
```

**132 ms of a 231 ms budget** — 57% — spent sourcing a single cache file. Everything else (starship prompt initialisation, mise activation, atuin history bindings, direnv hooks) added up cleanly to the remaining ~85 ms.

The cache file itself was well-formed and cache-invalidation was working correctly. The problem lived at the primitive level: what does `alias name='value'` cost when Fish parses and installs it? Ran in isolation:

```
$ hyperfine --warmup 2 "fish -c 'source ~/.cache/fish/bash-aliases.fish'"
  Time (mean ± σ): 170.8 ms ± 11.3 ms
```

**170 ms just to source 878 alias lines.** Fish's `alias` isn't a shell-level string substitution — it's a function factory. The invocation `alias ll='eza -la --icons'` roughly desugars to:

```fish
function ll --wraps='eza -la --icons' --description 'alias ll=eza -la --icons'
    eza -la --icons $argv
end
```

Every call parses the definition, allocates a function object, installs it in the function table, records the description, and wires the `--wraps` for tab completion. Approximately 183 µs per entry. At 878 entries, the maths is uncompromising: 878 × 183 µs = 161 ms.

The cost is O(1) per call, but the call count is the problem, and there is no batching path in Fish's `alias` implementation.

## Remediation: `abbr --add` as a Cross-Shell-Bridge Primitive #

Fish exposes two ways to give a short name to a longer command:

- **`alias`** — function factory. Available in interactive shells, scripts, pipes, subshells, and inside other functions. Costs a function allocation on every source.
- **`abbr --add`** — abbreviation. Expanded at the interactive command line the moment the user types the abbreviation and hits space or enter. Not available in scripts (they need functions). No function allocation on installation.

For bash-alias bridges, the tradeoff is invisible: users don't call `ll` from inside a Fish script — they'd write a proper Fish function for that use case. Abbreviations for this workload are a strict upgrade: identical interactive UX, no function-table pressure, and — as a side benefit — they show the user what actually runs when they type the abbreviation, which improves shell literacy.

The code change is a single printf format string in the cache-generator:

```diff
-  printf "alias %s=%s\n" "$name" "$val"
+  printf "abbr --add %s -- %s\n" "$name" "$val"
```

Measured in isolation:

```
Benchmark 1: fish -c 'source alias-cache.fish'
  Time (mean ± σ):     170.8 ms ± 11.3 ms

Benchmark 2: fish -c 'source abbr-cache.fish'
  Time (mean ± σ):      34.0 ms ±  0.9 ms

Summary
  abbr-cache.fish ran 5.02 ± 0.36 times faster than alias-cache.fish
```

**5× faster. 137 ms saved on every warm shell start.** End-to-end Fish latency dropped from 231 ms → 119 ms.

## The Second-Order Bug: Cache Invalidation Timing #

Solving the warm case revealed a distinct failure mode: the *first* Fish shell opened after `chezmoi apply` still measured ~306 ms. The apply step writes new versions of the underlying bash alias source files (updated mtimes). The staleness check inside the Fish bridge sees `source.mtime > cache.mtime`, throws the cache away, and rebuilds it — spawning a subshell, sourcing 40 KB of bash, iterating 878 lines. **~200 ms.**

The shell that pays this cost is whichever one the user opens first, which is almost always the shell they opened *because* they wanted to see the effect of the apply.

The remediation is architectural, not algorithmic. The regeneration is moved off the interactive path and onto the apply itself via a chezmoi `run_onchange_after_` script:

```bash
#!/usr/bin/env bash
# Source-hash retrigger keys — script re-runs when any of these change:
#   90-ux-aliases.sh.tmpl:      {{ include "…/90-ux-aliases.sh.tmpl" | sha256sum }}
#   91-ux-aliases-lazy.sh.tmpl: {{ include "…/91-ux-aliases-lazy.sh.tmpl" | sha256sum }}
#   aliases.fish.tmpl:          {{ include "…/aliases.fish.tmpl" | sha256sum }}

command -v fish >/dev/null 2>&1 || exit 0

rm -f "${HOME}/.cache/fish/bash-aliases.fish"
fish -i -c 'exit' >/dev/null 2>&1 || true
```

The hook invalidates the cache, spawns a throwaway interactive Fish so the bridge's existing regen path fires, then exits. The user's next actual shell finds a valid, up-to-date cache. The 200 ms cost lands where the user expects "compilation work" to happen — during the apply — not on the terminal they open ten seconds later.

Cold-start Fish after apply: **306 ms → 120 ms.**

## Return on Resilience #

At a workstation opening 40 shells per day, saving 112 ms per shell reclaims 4.5 seconds daily; 22 minutes annually. At a small engineering org of 50 developers with the same profile, that's 18 engineering-hours reclaimed per year — measurable but modest.

The stronger case is qualitative. Interactive-latency perception is nonlinear: at ~200 ms the user consciously notices lag; at ~120 ms the shell feels immediate. Once the felt lag is gone, the developer stops flinching before opening a terminal — which changes the frequency and length of exploratory shell work, which changes the shape of what they do at the CLI.

| Metric | Before | After | Delta |
|---|---|---|---|
| Fish warm-start (median) | 231 ms | 119 ms | −112 ms (−48%) |
| Fish cold-start after apply | 306 ms | 120 ms | −186 ms (−61%) |
| Cache source cost | 170 ms | 34 ms | −136 ms (−80%) |
| CI regression threshold | ✗ 231 > 200 | ✓ 119 ≤ 200 | Now under budget |
| Full test suite | 4703 tests, 0 fail | 4703 tests, 0 fail | Zero regressions |

## Take-Aways #

1. **Profile every interactive shell in CI.** Fish, Zsh, Nushell, Bash — each has its own primitives with different costs. Treat first-prompt latency as a signal with a threshold, not a comfort metric.

2. **Prefer `abbr` for interactive-only bridged aliases in Fish.** The distinction between `abbr` (line-time expansion) and `alias` (function factory) is documented; the 5× cost distinction is not. If your users don't call the alias from inside a Fish script — and for bridged bash aliases they don't — `abbr` is a strict upgrade.

3. **Move cache regeneration off the interactive path.** Any cache invalidated by a configuration-management action (chezmoi, ansible, dotbot) should be regenerated by that same action, not by whichever shell opens next.

4. **Version the cache format itself, not just the source.** The staleness check should include a format marker so upgrading users don't inherit stale caches by mtime luck.

The reference implementation lives on `main` at [sebastienrousseau/dotfiles](https://github.com/sebastienrousseau/dotfiles); the change landed as [PR #963](https://github.com/sebastienrousseau/dotfiles/pull/963) and [PR #964](https://github.com/sebastienrousseau/dotfiles/pull/964), shipped in [v0.2.510](https://github.com/sebastienrousseau/dotfiles/releases/tag/v0.2.510).
