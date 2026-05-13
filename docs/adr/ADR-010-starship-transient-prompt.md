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

Enable Starship's `enable_transient_prompt = true` for both zsh and
fish:

- **Zsh**: configure via `dot_config/starship/starship.toml.tmpl`
  (the canonical Starship config), and ensure `dot_config/zsh/dot_zshrc.tmpl`
  initializes Starship through `_cached_eval` (which already happens).
  No additional zsh code; Starship internally registers the
  `TRAPDEBUG`/`preexec` hooks.

- **Fish**: same Starship config (shared TOML), with fish-side
  integration via `dot_config/fish/conf.d/`.

- **Transient prompt content**: `❯` plus optional exit-code dot
  (red dot if `$status != 0`). Keep it 1–3 characters so scrollback
  density actually improves.

The toggle is exposed in `.chezmoidata.toml` as
`features.starship_transient = true`. Users on bandwidth-constrained
terminals (slow SSH, serial console) can flip it off without editing
the canonical config.

## Consequences

### Positive

- Scrollback is 4–5× denser. A 100-command session that previously
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
