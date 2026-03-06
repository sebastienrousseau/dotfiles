# Documentation

Cross-platform shell environment for macOS, Linux, and WSL. Managed by Chezmoi.

---

## Table of Contents

### Getting Started
- [Installation Guide](INSTALL.md) — set up your environment
- [Walkthrough](WALKTHROUGH.md) — tour of key features after install
- [Features Overview](FEATURES.md) — feature flags and configuration

### Core
- [Architecture](ARCHITECTURE.md) — system design and startup strategies
- [Operations Guide](OPERATIONS.md) — daily usage and maintenance
- [Interoperability](INTEROP.md) — cross-platform command mapping
- [Troubleshooting](TROUBLESHOOTING.md) — common issues and fixes

### Configuration
- [Aliases Reference](ALIASES.md) — shell aliases and shortcuts
- [Alias Deprecations](ALIASES_DEPRECATIONS.md) — removed aliases
- [Keybindings](KEYS.md) — keyboard shortcuts
- [Tools Reference](TOOLS.md) — integrated tools and utilities
- [Utilities](UTILS.md) — helper scripts and the `dot` CLI

### Customization
- [Fonts Guide](FONTS.md) — Nerd Fonts setup
- [Screenshots](SCREENSHOTS.md) — visual gallery
- [Neovim IDE Guide](NEOVIM_IDE_GUIDE.md) — editor configuration

### Security
- [Security Overview](SECURITY.md) — security model and practices
- [Security Checklist](SECURITY_CHECKLIST.md) — hardening guide
- [Secrets Management](SECRETS.md) — encrypted credentials

### Development
- [Testing Guide](TESTING.md) — test framework and coverage
- [Compliance](COMPLIANCE.md) — standards and regulatory mapping
- [Architecture Decisions](adr/) — ADRs for key decisions

### Platform-Specific
- [WSL2 + Nix Guide](WSL2_NIX_TROUBLESHOOTING.md) — Windows Subsystem for Linux

### Reference
- [Roadmap](ROADMAP.md) — future plans and priorities
- [Version Sync](VERSION_SYNC.md) — how version numbers propagate

---

## Contributing

1. Fork the repository
2. Create a feature branch
3. Test with `dot doctor`
4. Submit a pull request

### Code Style

- Shell scripts: follow ShellCheck recommendations, format with `shfmt -i 2 -ci`
- Templates: use `.chezmoitemplates/` for reusable logic
- Documentation: use UPPERCASE.md naming

### Testing

```bash
./scripts/tests/framework/test_runner.sh                          # Unit tests
RUN_INTEGRATION=1 ./scripts/tests/framework/test_runner.sh        # Integration
```
