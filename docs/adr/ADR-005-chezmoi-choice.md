# ADR-005: Chezmoi as Dotfiles Manager

**Status**: Accepted
**Date**: 2026-02-09
**Authors**: @sebastienrousseau

## Context

Managing dotfiles across multiple machines requires:
- Version control for configuration files
- Template support for machine-specific values
- Cross-platform compatibility (macOS, Linux, WSL)
- Encrypted secrets management
- Easy installation and updates

Several approaches were considered for dotfiles management.

## Decision

Use **chezmoi** as the primary dotfiles management tool.

### Alternatives Considered

| Tool | Pros | Cons |
|------|------|------|
| **GNU Stow** | Simple, no dependencies | No templating, symlink-only |
| **yadm** | Git-based, encryption | Limited templating |
| **Bare Git** | Simple, no tools | No templating, manual management |
| **Ansible** | Powerful, idempotent | Heavy, complex for dotfiles |
| **Nix Home Manager** | Declarative, reproducible | Steep learning curve, Nix dependency |

### Why Chezmoi

1. **Template Support**: Go text/template for machine-specific configuration
2. **Encryption**: Built-in age/gpg encryption for secrets
3. **Cross-Platform**: Native support for macOS, Linux, Windows
4. **Single Binary**: No runtime dependencies
5. **Git Integration**: Works with any Git host
6. **Dry-Run**: Preview changes before applying
7. **Active Development**: Well-maintained with responsive maintainer

## Implementation

```bash
# Installation
sh -c "$(curl -fsLS get.chezmoi.io)"

# Initialize from repository
chezmoi init https://github.com/user/dotfiles.git

# Apply configuration
chezmoi apply
```

### Template Example

```go
{{- if eq .chezmoi.os "darwin" }}
# macOS-specific configuration
{{- else if eq .chezmoi.os "linux" }}
# Linux-specific configuration
{{- end }}
```

## Consequences

### Positive
- Consistent configuration across all machines
- Secure secrets management with age encryption
- Easy to add new machines to the fleet
- Template-driven configuration reduces duplication
- Built-in diff and dry-run for safe updates

### Negative
- Learning curve for Go templates
- Additional abstraction layer over raw Git
- Requires chezmoi binary installation
- Some features (scripts) require careful ordering

### Neutral
- Configuration stored in `~/.local/share/chezmoi` by default
- Custom wrapper CLI (`dot`) provides simpler interface
- Regular `git` commands still work in source directory

## References

- [Chezmoi Documentation](https://www.chezmoi.io/)
- [Chezmoi Quick Start](https://www.chezmoi.io/quick-start/)
- [Comparison with Other Tools](https://www.chezmoi.io/comparison-table/)
