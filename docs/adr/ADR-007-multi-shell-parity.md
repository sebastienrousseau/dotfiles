# ADR-007: Multi-Shell Parity Strategy

## Status

Accepted

## Date

2026-03-08

## Context

The dotfiles distribution supports three shells: Zsh (default since macOS Catalina), Fish (modern interactive shell), and Nushell (structured data shell). The codebase has 98 alias files and 52+ functions written in POSIX/Bash. Without a parity strategy, each shell gets a fragmented subset of functionality.

**Problem:** Fish had zero access to the alias/function library until v0.2.496 added bridge templates. Nushell had only 6 hardcoded aliases and no function access.

**Constraints:**
- Nushell's `source` is parse-time evaluated (no dynamic sourcing)
- Fish syntax differs significantly from POSIX (no `$()`, different `if`, no `[[`)
- Maintaining N copies of every alias/function is unsustainable

## Decision

Adopt a **hub-and-spoke bridge architecture**:

1. **Hub:** Canonical definitions live in `.chezmoitemplates/aliases/` (Bash/POSIX) and `.chezmoitemplates/functions/` (Bash)
2. **Bash/Zsh spoke:** Direct inclusion via `90-ux-aliases.sh.tmpl` and `50-logic-functions.sh.tmpl`
3. **Fish spoke:** Runtime bash bridge with caching (`aliases.fish.tmpl`, `functions.fish.tmpl`)
4. **Nushell spoke:** Hybrid approach:
   - Aliases: Runtime bash extraction cached to `~/.cache/nushell/bash-aliases.nu` (in `env.nu.tmpl`), sourced by `aliases.nu.tmpl`
   - Functions: Chezmoi template-generated `def` wrappers delegating to bash (in `functions.nu.tmpl`)

**Parity tiers:**
- **Tier 1 (Full):** Zsh, Bash — all aliases, functions, lazy loading, cached eval
- **Tier 2 (Bridged):** Fish — all simple aliases, all functions via wrappers, `_cached_eval` caching
- **Tier 3 (Compatible):** Nushell — simple aliases (no complex bash syntax), all functions via bash delegation

## Consequences

### Positive
- Single source of truth for aliases and functions
- Adding a new alias/function automatically propagates to all shells
- Nushell users get access to 40+ functions that were previously unavailable
- Fish users get mtime-aware caching via `_cached_eval`

### Negative
- Complex bash aliases (pipes, conditionals) are skipped for Nushell
- Function calls in Fish/Nushell incur bash subprocess overhead (~5ms per call)
- Cache invalidation requires shell restart or manual cache clear

### Risks
- Nushell's rapid development may break bridge syntax in future versions
- Very large alias sets may slow Nushell startup during cache generation
