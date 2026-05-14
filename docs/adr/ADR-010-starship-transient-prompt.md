---
render_with_liquid: false
---

# ADR-010: Enable Starship Transient Prompt in Zsh and Fish

## Status

Accepted

## Date

2026-05-12

## Context

Starship is the prompt renderer for both zsh and fish in this
distribution (pinned via `mise.toml`: `starship = "1.24.2"`).
A typical Starship prompt for this project renders 4–6 lines including
the directory, git branch + dirty markers, language toolchain version,
duration of the previous command, and a final `❯` line.

By default Starship emits this multi-line prompt on **every** previous
command as well as the current one. After 50 commands in a session, the
terminal scrollback contains 200–300 lines of historical prompts — most
of which only convey context that was relevant at the time the command
ran. Search through scrollback (Ctrl-r history, copy-paste, screenshots,
asciinema replay) is noisy.

Starship 1.24+ supports a **transient prompt** feature: when a command
finishes, the prompt that produced it is rewritten to a compact form
(e.g., `❯`) and the full prompt is re-emitted only at the live editing
line. The current command always shows the full prompt; history shows
only the compact form.

**Problem:** Reduce scrollback noise without sacrificing the live prompt's
rich context, and apply it consistently across the two interactive
shells we support as first-class.

**Constraints:**

- Must work in zsh and fish (the two Tier-1 shells per ADR-007).
- Must not interfere with `_cached_eval`'s startup-cost optimization
  (the transient hook fires per-prompt, not per-shell-start).
- Must not break copy-paste of previous commands: the compact line
  must still be `❯` (or similar) so `<Ctrl-shift-c>` over scrollback
  yields runnable shell content if the user includes the prompt.

## Decision

Call Starship's `enable_transience` shell function after the cached
`starship init` runs in each shell. We share one `starship.toml.tmpl`
across both shells; the transient prompt content is the existing
`[character]` block (no separate `[transient_*]` section needed).

- **Fish**: `dot_config/fish/conf.d/init.fish.tmpl` calls
  `enable_transience` once the function is defined. `starship init
  fish` defines it via `--print-full-init`. Result: `$fish_transient_prompt`
  flips to `1` and the Enter handler is bound to
  `__starship_transient_execute`. The compact prompt collapses past
  scrollback as soon as the next command runs.

- **Zsh**: `dot_config/zsh/dot_zshrc.tmpl` carries the same
  `enable_transience` call, guarded by
  `(( ${+functions[enable_transience]} ))`. **Upstream Starship does
  not ship a zsh-side `enable_transience` function yet** (tracked by
  [starship/starship#3522](https://github.com/starship/starship/issues/3522)).
  The guard returns 0, the block no-ops, and zsh keeps its full multi-
  line prompt in scrollback for now. The code is a forward-compatibility
  hook: when upstream ships the zsh function, the feature activates
  automatically on the next `mise upgrade starship` with no zshrc edit.

  Alternatives we rejected for zsh:

  - **Roll our own `zle` widget that rewrites `$PROMPT` on Enter.**
    Possible (the standard recipe overrides `accept-line` with a
    transient widget). Rejected because:
    (a) any hand-rolled implementation will conflict with upstream
        once they ship the official function, forcing a removal,
    (b) Starship's prompt is multi-line and ANSI-coloured; correctly
        rewriting it from a custom widget requires duplicating
        Starship's escape-code generation, which drifts with every
        Starship release,
    (c) it'd run inside `_cached_eval`'s eager-init path, complicating
        the cache-invalidation semantics we documented in ADR-002.
  - **Third-party zsh plugin (e.g. zsh-autocomplete's transient mode).**
    Rejected because the upstream Starship fix is in active discussion
    and a plugin adds a permanent dependency we'd then have to remove.
  - **Disable zsh transient until upstream lands.** The current state.
    Zsh users see the same scrollback density they had before this PR;
    the visible improvement is fish-only. Honest trade-off.

- **Transient prompt content**: `❯` plus optional exit-code dot
  (red dot if `$status != 0`). Keep it 1–3 characters so scrollback
  density actually improves.

The toggle is exposed in `.chezmoidata.toml` as
`features.starship_transient = true`. Users on bandwidth-constrained
terminals (slow SSH, serial console) can flip it off without editing
the canonical config.

## Consequences

### Positive (fish only, until upstream lands zsh support)

- Scrollback is 4–5× denser **in fish**. A 100-command session that previously
  filled the screen 20× over now fills it ~4×.
- Asciinema recordings (relevant for the showcase commits in #874)
  read much more naturally — fewer screens of historical prompts
  between actions.
- The live prompt still surfaces all the rich context Starship was
  configured for; only history is compacted.

### Negative

- Slightly more complex Starship config; the maintainer must remember
  that `[character]` and `[transient_*]` are distinct modules.
- Users who rely on visual scanning of historical prompts (e.g., "what
  branch was I on when I ran that?") lose that signal. Mitigation: the
  feature flag.

### Risks

- Starship's transient API is stable since 1.16 (2023) but the exact
  config surface evolves. If Starship breaks the schema in a future
  major, the pinned version in `mise.toml` insulates us; we vet new
  releases through `dot upgrade --dry-run` before bumping.

## Alternatives Considered

| Alternative | Why rejected |
|---|---|
| Single-line Starship prompt | Sacrifices live-prompt richness for the same scrollback-density goal. The transient feature gives both. |
| Custom zsh `precmd` rewriter | Would have to be reimplemented in fish. Starship already solved it. |
| Disable Starship entirely on history | Loses the whole reason we use Starship. |

## References

- Starship transient prompt docs:
  <https://starship.rs/advanced-config/#transientprompt-and-transientrightprompt-in-zsh>
- ADR-002 (Shell Performance Optimization) — establishes the
  `_cached_eval` constraint this ADR respects.
- ADR-007 (Multi-Shell Parity) — establishes zsh + fish as Tier-1.
- Issue #873 — captures this ADR alongside `llms.txt`.
