# ADR-006: Zsh as Default Shell

**Status**: Accepted
**Date**: 2026-02-09
**Authors**: @sebastienrousseau

## Context

Choosing a default shell impacts:
- Developer productivity and workflow
- Plugin ecosystem and extensibility
- Cross-platform compatibility
- Startup performance
- Learning curve for new users

## Decision

Use **Zsh** as the default interactive shell with **Zinit** as the plugin manager.

### Alternatives Considered

| Shell | Pros | Cons |
|-------|------|------|
| **Bash** | Universal, stable, POSIX | Limited interactive features |
| **Zsh** | Rich features, great plugins | Slower than bash (mitigated) |
| **Fish** | Modern, user-friendly | Not POSIX, less portable |
| **Nushell** | Structured data, modern | Breaking changes, immature |

### Why Zsh

1. **Default on macOS**: Pre-installed since Catalina
2. **Plugin Ecosystem**: Massive library of plugins and themes
3. **Compatibility**: POSIX-compatible, easy migration from bash
4. **Completion System**: Superior tab completion
5. **Customization**: Highly configurable prompt and behavior
6. **Community**: Large community, well-documented

### Why Zinit

| Plugin Manager | Load Time | Features |
|----------------|-----------|----------|
| Oh-My-Zsh | ~800ms | Monolithic, many plugins |
| Prezto | ~400ms | Faster, modular |
| **Zinit** | ~200ms | Turbo mode, fine control |
| Antibody | ~300ms | Simple, fast |

Zinit provides:
- **Turbo Mode**: Deferred loading after prompt
- **Ice Modifiers**: Fine-grained control over plugin loading
- **Binary Installation**: Install completions and binaries
- **Profiling**: Built-in load time profiling

## Implementation

### Shell Layer System

```
dot_config/zsh/rc.d/
├── 00-10: Core (env, history, options)
├── 20-49: Middleware (zinit, completions)
├── 50-89: Toolchain (languages, tools)
└── 90-99: UX (prompt, aliases, keybindings)
```

### Zinit Configuration

```zsh
# Turbo mode: load after prompt displays
zinit ice wait lucid
zinit light zsh-users/zsh-autosuggestions

# Synchronous: needed immediately
zinit light zdharma-continuum/fast-syntax-highlighting
```

### Performance Targets

| Metric | Target | Achieved |
|--------|--------|----------|
| Cold Start | <500ms | ~300ms |
| Warm Start | <200ms | ~150ms |
| Plugin Load | Async | Yes |

## Consequences

### Positive
- Fast, responsive shell experience
- Rich plugin ecosystem (autosuggestions, syntax highlighting)
- Powerful completion system
- Compatible with existing bash scripts
- Modern prompt with Starship

### Negative
- Requires zsh installation on some Linux distros
- Plugin manager adds complexity
- Some bash-isms need adjustment
- Turbo mode can cause brief visual delay

### Neutral
- Users can still use bash for scripts
- Configuration more complex than vanilla shell
- Performance monitoring needed

## Performance Optimizations

1. **Caching**: Compile zsh files to `.zwc` bytecode
2. **Lazy Loading**: Defer heavy tools (nvm, rvm) until first use
3. **Turbo Mode**: Load plugins after prompt displays
4. **Conditional Loading**: Skip unused features

## References

- [Zsh Documentation](https://zsh.sourceforge.io/Doc/)
- [Zinit Wiki](https://zdharma-continuum.github.io/zinit/wiki/)
- [Starship Prompt](https://starship.rs/)
