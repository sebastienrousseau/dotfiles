---
render_with_liquid: false
---

# ADR-011: Keep Nushell as Tier-3 Reference with Minimum-Viable Caching

## Status

Accepted

## Date

2026-05-13

## Context

ADR-007 (Multi-Shell Parity Strategy) classified the three supported
shells:

| Tier | Shells | Definition |
|---|---|---|
| Tier 1 (Full) | zsh, bash | Native aliases, functions, lazy loading, `_cached_eval` |
| Tier 2 (Bridged) | fish | Aliases + functions via bridge, `_cached_eval` |
| Tier 3 (Compatible) | nushell | Simple aliases only, functions via bash delegation |

The 2026 audit (slice 3 of #880's deep-dive) flagged Nushell as a
maintenance candidate:

- < 5% feature parity with zsh.
- No async / deferred-load support.
- No equivalent of `_cached_eval` — meaning every Nushell start spawns
  `starship init nu`, `mise activate nu`, `zoxide init nushell`,
  `atuin init nu` as fresh subprocesses, costing 100–200 ms aggregated.
- 5 config files (`config.nu.tmpl`, `env.nu.tmpl`, `aliases.nu`,
  `completions.nu.tmpl`, `functions.nu.tmpl`) totalling ~270 lines —
  enough to be meaningful, not enough to be self-sustaining.

Three paths were proposed:

1. **Keep as-is** — accept the gap, defer maintenance.
2. **Reduce to a stub** — leave the config but stop investing.
3. **Remove entirely** — delete all references.

## Decision

**Keep Nushell as Tier-3 with explicit limitations + a minimum-viable
`_cached_eval` equivalent.**

Specifically:

- Ship `dot_config/nushell/cached_eval.nu` — a Nushell module that
  ports the binary-mtime-based init caching pattern from zsh/fish.
  It handles the four tools that matter most for shell start:
  starship, mise, zoxide, atuin. See the Nushell-specific tradeoffs
  in the "Consequences" section below.
- Wire `env.nu.tmpl` to use the new module so subsequent shells skip
  the subprocess spawns when binaries haven't moved.
- Continue maintaining the existing `aliases.nu` (hand-curated simple
  aliases — `l`, `ll`, `la`, etc.) but accept that the bash-bridge
  approach for full alias parity isn't worth the complexity.
- Update `README.md`'s shell list to call Nushell out as "best-effort
  / Tier-3" so users have correct expectations.
- Reject the "remove entirely" option for now (see Rationale below).

## Rationale

**Why not remove**: Nushell is shipped with the canonical `mise`
toolchain in this repo (it's installable via `mise install nushell`)
and is gaining adoption in the Rust + data-engineering communities
that overlap with this distribution's audience. Removing it would
break promises to a small-but-vocal segment of users. The maintenance
cost of the current 270-line surface is low.

**Why not reduce to a stub**: A stub config is worse than the current
moderate config — users who type `nu` and get a featureless shell
without any of the integrations the README promised would feel
betrayed. Either we keep the shell working well enough to use, or we
delete it.

**Why the minimum-viable cache layer**: The biggest waste on every
Nushell start was the four uncached subprocess spawns
(`starship init nu` etc.). Adding mtime-based caching for those costs
~50 lines of Nushell code and saves 100–200 ms per shell. That's the
cheapest meaningful improvement; deeper investments (async hydration,
plugin system, bash bridge for aliases) await an actual user request.

## Consequences

### Positive

- Nushell starts substantially faster than before (TBD — needs
  measurement on a host with all four tools installed). The
  subprocess elimination saves ~50–80 ms per cached tool, per cold
  shell after the cache is populated.
- The mtime-invalidation pattern matches what zsh / fish do, so a
  contributor familiar with one of the other shells can read the
  Nushell code without learning a new mental model.
- Explicit Tier-3 documentation avoids the "wait, this is supposed to
  be at parity" surprise.

### Negative

- Nushell's parse-time evaluator means we can't wrap source calls in
  the cache function — the caller has to `source <path>` directly.
  Slightly more boilerplate than the zsh/fish APIs.
- No malware-pattern screening in the cached output. The zsh / fish
  implementations grep for `curl ... | sh`, `nc -e`, etc. before
  sourcing; the Nushell version trusts its inputs. For the four tools
  we ship (`starship`, `mise`, `zoxide`, `atuin`) this is acceptable
  — they're official binaries pinned via `mise.toml`. Future tools
  added to the cache must be similarly trusted.
- No per-tool timing telemetry. The `EVALCACHE_TIMING` infrastructure
  zsh has (#863) isn't ported. If Nushell perf becomes a sustained
  user concern, this is the next layer to add.

### Risks

- Nushell's syntax evolves quickly between 0.x releases. The
  `cached_eval.nu` module uses `path exists`, `ls | get -i modified`,
  and `run-external` which have been stable since 0.86 (Q3 2024).
  If a future Nushell release breaks the API, the module fails fast
  (saving an empty cache file) rather than corrupting state.
- Cache invalidation by mtime is fragile when the user installs a
  tool via a non-mtime-respecting method (e.g. unpacking a tarball
  with `--no-touch-mtimes`). The fallback is the user running
  `dot prewarm` or deleting `~/.cache/nushell/*.nu`. Documented in
  `docs/operations/PERFORMANCE.md`.

## Alternatives Considered

| Alternative | Why rejected |
|---|---|
| **Bash bridge for full alias parity** | Adds a `bash --norc --noprofile -c '...'` subprocess on every Nushell start (~30 ms). Defeats the perf gain from the cache layer. |
| **Port `_cached_eval` 1:1 (malware screen + JSONL telemetry)** | The full zsh implementation is 100+ lines. The Nushell version covers the 80% case at 50 lines; the remaining 20% (advanced features) aren't load-bearing for Tier-3 status. |
| **Delete Nushell entirely** | See "Why not remove" above. |
| **Reduce to a stub** | See "Why not reduce to a stub" above. |

## References

- [`dot_config/nushell/cached_eval.nu`](../../defaults/dot_config/nushell/cached_eval.nu) — the new module.
- [`dot_config/nushell/env.nu.tmpl`](../../defaults/dot_config/nushell/env.nu.tmpl) — adopter.
- ADR-007 (Multi-Shell Parity Strategy) — establishes the tier definitions.
- ADR-002 (Shell Performance Optimization Strategy) — establishes `_cached_eval` semantics this module ports.
- Issue [#880](https://github.com/sebastienrousseau/dotfiles/issues/880).
