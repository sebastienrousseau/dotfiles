# Zsh Completion Cache Lifecycle

This page documents how zsh completion compilation works in this repo
and how to force a rebuild. Managed under
[#864](https://github.com/sebastienrousseau/dotfiles/issues/864).

## The Pieces

Three caches cooperate to keep `compinit` fast without compromising
correctness:

1. **The compinit dump** —
   `$XDG_CACHE_HOME/zsh/zcompdump-$ZSH_VERSION`. Built by
   `compinit -d <path>` from the fpath corpus. Encodes which file
   provides each completion function. Per-zsh-version so an OS upgrade
   doesn't silently serve a stale binary index.

2. **The compinit dump bytecode** — `<dump>.zwc`. Built by
   `zcompile` in the background after the dump is rebuilt. Zsh prefers
   the `.zwc` form on subsequent shells, skipping re-parse.

3. **fpath bytecode siblings** — `_<tool>.zwc` next to each
   `_<tool>` source file under `~/.local/share/zsh/completions/`.
   Built once per chezmoi apply by
   `run_onchange_after_zcompile-completions.sh.tmpl` (so this happens
   *outside* the critical shell-start path). Zsh prefers the `.zwc`
   when autoloading the corresponding completion function.

## Flow on Shell Start

```
zsh starts
  → sources rc.d (no compinit yet)
  → registers a `preexec` (or `precmd`) hook
  → returns to prompt
user presses Tab (or `precmd` fires)
  → `compinit -d $XDG_CACHE_HOME/zsh/zcompdump-$ZSH_VERSION`
    or `compinit -C -d <dump>` if the dump is < 24 hours old
  → background `zcompile` of the dump
  → first tab-completion uses the precompiled `.zwc` for each tool
```

## Flow on Chezmoi Apply

```
chezmoi apply
  → if completion sources changed, run_onchange fires
    run_onchange_after_zcompile-completions.sh.tmpl
  → walks ~/.local/share/zsh/completions/
  → for each _<tool> file whose .zwc is missing or stale:
      zsh -c "zcompile <file>"
  → reports compiled=N skipped=M
```

## Configuration Surface

| Variable | Default | Purpose |
|---|---|---|
| `DOTFILES_ENABLE_COMPINIT` | 1 on `laptop`/`desktop` profiles, 0 elsewhere | Whether to load the completion subsystem at all. Non-laptop profiles skip the runtime cost but still benefit from precompiled `.zwc` files if present. |
| `DOTFILES_DEFER_COMPINIT` | 1 | When 1, compinit runs on first `preexec`. When 0, runs on `precmd`. |
| `DOTFILES_FAST` | 0 | When 1, the entire completion path is skipped. |
| `DOTFILES_ULTRA_FAST` | 0 | Same as `DOTFILES_FAST` but more aggressive. |
| `DOTFILES_SKIP_ZCOMPILE` | 0 | When 1, the run_onchange hook does not precompile fpath files. Used in CI / minimal images where bytecode isn't needed. |
| `XDG_CACHE_HOME` | `$HOME/.cache` | Standard XDG override; the dump path is `$XDG_CACHE_HOME/zsh/zcompdump-$ZSH_VERSION`. |

## Force Rebuild

When completions go stale (e.g., after a tool upgrade):

```bash
# Invalidate the compinit dump — next shell rebuilds it.
rm -f "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump-${ZSH_VERSION}"
rm -f "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump-${ZSH_VERSION}.zwc"

# Force regeneration of fpath bytecode siblings:
find ~/.local/share/zsh/completions -name '*.zwc' -delete
chezmoi apply ~  # re-runs the run_onchange hook
```

Or, equivalently, `dot heal` (which calls both in sequence).

## Measured Cost

The current dotfiles ship with `compinit` deferred to first-prompt,
which means shell *startup* time is already nearly minimal — zsh
doesn't parse the fpath corpus until tab-completion is invoked. The
precompiled `.zwc` files cut down the *first tab-completion* latency
per tool, not shell-start latency. On a 2026 M-series macOS host the
P50 for `time zsh -i -c exit` measured at 39 ms before this change
and 39 ms after — the change pays off when the user starts typing,
not before.

This makes the lifecycle policy still worth shipping:

- Cleaner cache layout (XDG-cache, version-keyed).
- Bytecode siblings auto-picked on non-laptop profiles (which skip
  compinit entirely) so completion is still fast even without the
  full subsystem.
- A documented force-rebuild path.

## Skip Rules

The run_onchange hook skips itself when:

- `DOTFILES_SKIP_ZCOMPILE=1` (CI / minimal images).
- `zsh` is not on PATH (servers without an interactive shell).
- `~/.local/share/zsh/completions/` doesn't exist.

System fpath directories (Homebrew, `/usr/local/share/zsh`) are
intentionally NOT precompiled — the package manager already manages
their lifecycle.

## References

- [`dot_config/zsh/rc.d/30-options.zsh.tmpl`](../../dot_config/zsh/rc.d/30-options.zsh.tmpl) — the deferred-compinit logic.
- [`run_onchange_after_zcompile-completions.sh.tmpl`](../../run_onchange_after_zcompile-completions.sh.tmpl) — the apply-time precompile hook.
- [`zsh` completion docs](https://zsh.sourceforge.io/Doc/Release/Completion-System.html).
- ADR-002 (Shell Performance Optimization).
- Issue [#864](https://github.com/sebastienrousseau/dotfiles/issues/864).
