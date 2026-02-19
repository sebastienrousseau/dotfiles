# ADR-002: Shell Performance Optimization Strategy

**Status**: Accepted
**Date**: 2026-02-09
**Authors**: @sebastienrousseau

## Context

Shell startup time directly impacts developer productivity. Every new terminal,
tmux pane, or shell command execution incurs this cost. With rich shell
configurations (completions, prompts, plugins), startup can easily exceed 1-2
seconds.

Goals:
- Target startup time: <500ms for interactive shells
- Maintain full functionality (completions, syntax highlighting, git info)
- Support both zsh and bash
- Work across macOS and Linux

## Decision

Implement a **multi-layer performance optimization strategy**:

### Layer 1: Compilation and Caching

```bash
# Compile zsh files to .zwc format
_cached_eval() {
  local cache="$HOME/.cache/zsh/$1.zwc"
  if [[ ! -f "$cache" || "$2" -nt "$cache" ]]; then
    eval "$($2)" > "$cache.tmp"
    zcompile "$cache.tmp" "$cache"
  fi
  source "$cache"
}
```

- Compile frequently-sourced files to bytecode
- Cache command output (brew shellenv, mise activate)
- Invalidate cache when source files change

### Layer 2: Lazy Loading

Defer loading of heavy components until first use:

```bash
# Lazy load completions
function kubectl() {
  unfunction kubectl
  source <(kubectl completion zsh)
  kubectl "$@"
}
```

- Completions loaded on first command use
- NVM/RVM loaded only when node/ruby commands invoked
- Heavy plugins deferred via zinit's `wait` modifier

### Layer 3: Zinit Turbo Mode

```zsh
zinit ice wait lucid
zinit light zsh-users/zsh-autosuggestions
```

- Plugins load asynchronously after prompt
- Critical plugins (syntax highlighting) load synchronously
- Most plugins have 0ms impact on startup

### Layer 4: Conditional Loading

```bash
# Only load if command exists
[[ -x /opt/homebrew/bin/brew ]] && eval "$(/opt/homebrew/bin/brew shellenv)"

# Skip in non-interactive shells
[[ $- != *i* ]] && return
```

- Platform-specific code guarded by OS detection
- Heavy features opt-in via environment variables
- Non-interactive shells get minimal config

### Monitoring

Benchmark script to track startup time:
```bash
hyperfine --warmup 3 --runs 10 "zsh -i -c exit"
```

CI enforces 500ms threshold with warnings.

## Consequences

### Positive
- Consistent <500ms startup across platforms
- Full functionality preserved
- Easy to add new tools without performance regression
- Clear patterns for contributors to follow

### Negative
- First invocation of lazy-loaded commands is slower
- Cache invalidation bugs can cause stale behavior
- Complexity in understanding load order

### Neutral
- Profiling required when adding new plugins
- Trade-off between convenience and performance explicit

## Measurements

| Configuration | Startup Time |
|---------------|--------------|
| Vanilla zsh | ~50ms |
| With oh-my-zsh | ~800ms |
| This approach | ~200-400ms |

## References

- [Zsh Startup Optimization](https://htr3n.github.io/2018/07/faster-zsh/)
- [Zinit Turbo Mode](https://zdharma-continuum.github.io/zinit/wiki/INTRODUCTION/)
