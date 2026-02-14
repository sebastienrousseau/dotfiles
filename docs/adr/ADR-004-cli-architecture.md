# ADR-004: Chezmoi + Custom CLI Wrapper Architecture

**Status**: Accepted
**Date**: 2026-02-09
**Authors**: @sebastienrousseau

## Context

Managing dotfiles requires:
- Tracking file changes and applying them consistently
- Handling platform-specific configurations
- Supporting encrypted secrets
- Providing a good developer experience

Options considered:
1. **Bare git repository**: Simple but poor UX, no templating
2. **GNU Stow**: Symlink-based, limited features
3. **Chezmoi only**: Powerful but complex CLI
4. **Custom from scratch**: High maintenance burden
5. **Chezmoi + wrapper**: Best of both worlds

## Decision

Use **Chezmoi as the core engine** with a **custom `dot` CLI wrapper** that:

### Architecture

```
┌─────────────────────────────────────────────┐
│                 dot CLI                      │
│  (User-friendly interface, custom commands)  │
├─────────────────────────────────────────────┤
│              Command Modules                 │
│  core │ diagnostics │ tools │ appearance    │
│  secrets │ security │ meta                   │
├─────────────────────────────────────────────┤
│              Shared Library                  │
│  utils.sh (resolve_source_dir, run_script)  │
├─────────────────────────────────────────────┤
│                 Chezmoi                      │
│  (Template engine, state management, apply)  │
└─────────────────────────────────────────────┘
```

### Core Principles

**1. Chezmoi handles complexity:**
- Template rendering with Go text/template
- Encrypted secrets with age
- State tracking (what's applied vs source)
- Cross-platform path handling

**2. dot CLI handles UX:**
- Memorable command names (`dot sync` vs `chezmoi apply`)
- Domain-specific commands (`dot doctor`, `dot theme`)
- Integration with external tools (Nix, Docker, Neovim)
- Consistent help and error messages

**3. Modular command structure:**
```
scripts/dot/
├── lib/
│   └── utils.sh          # Shared functions
└── commands/
    ├── core.sh           # apply, sync, update, add, diff
    ├── diagnostics.sh    # doctor, heal, health, benchmark
    ├── tools.sh          # tools, new, packages
    ├── appearance.sh     # theme, wallpaper, fonts
    ├── secrets.sh        # secrets-init, secrets
    ├── security.sh       # firewall, backup, encrypt-check
    └── meta.sh           # upgrade, docs, learn
```

**4. Delegation pattern:**
```bash
# Main dispatcher in dot CLI
dispatch() {
  local module="$1" cmd="$2"
  shift 2
  exec bash "$src_dir/scripts/dot/commands/$module.sh" "$cmd" "$@"
}
```

### Chezmoi Integration Points

| Feature | Chezmoi | dot CLI |
|---------|---------|---------|
| Apply changes | `chezmoi apply` | `dot sync` |
| View diff | `chezmoi diff` | `dot diff` |
| Edit secrets | `chezmoi edit --encrypted` | `dot secrets` |
| Source directory | `chezmoi source-path` | `dot cd` |
| Health check | `chezmoi doctor` | `dot doctor` (extended) |

### Extension Points

Custom commands can:
1. Wrap chezmoi commands with better defaults
2. Add entirely new functionality (benchmarks, themes)
3. Integrate with system tools (nix, docker, brew)
4. Provide interactive experiences (tour, learn)

## Consequences

### Positive
- Leverage Chezmoi's battle-tested engine
- User-friendly interface for common tasks
- Easy to add domain-specific commands
- Modular structure enables testing and maintenance
- Single entry point (`dot`) for all operations

### Negative
- Two layers to understand (chezmoi + dot)
- Version coupling between chezmoi and scripts
- Some chezmoi features not exposed via dot

### Neutral
- Advanced users can still use chezmoi directly
- Documentation needed for both layers
- Upgrade path when chezmoi adds new features

## Implementation Notes

### Adding a New Command

1. Identify the appropriate module (or create new one)
2. Add function `cmd_<name>()` to module
3. Add case to module's dispatch
4. Add case to main dot CLI dispatcher
5. Update help text
6. Add tests if complex

### Module Template

```bash
#!/usr/bin/env bash
# Dotfiles CLI - <Category> Commands

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/utils.sh"

cmd_example() {
  # Implementation
}

case "${1:-}" in
  example) shift; cmd_example "$@" ;;
  *) echo "Unknown command: ${1:-}" >&2; exit 1 ;;
esac
```

## References

- [Chezmoi Documentation](https://www.chezmoi.io/)
- [Command Pattern](https://refactoring.guru/design-patterns/command)
- [Unix Philosophy](https://en.wikipedia.org/wiki/Unix_philosophy)
