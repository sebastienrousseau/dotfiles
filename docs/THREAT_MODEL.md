# Threat Model

Security analysis of the dotfiles distribution. Covers trust boundaries, threat actors, attack surfaces, and mitigations.

## Trust Boundary

The primary trust boundary is the **local machine**. Dotfiles are deployed to and executed on the user's own system. All configuration files, scripts, and templates run with the user's privileges.

```
┌─────────────────────────────────────────────────┐
│ Local Machine (trusted zone)                    │
│  ┌─────────────────┐  ┌──────────────────────┐  │
│  │ ~/.dotfiles/     │  │ ~/.config/ (deployed)│  │
│  │ (source repo)    │──│ Shell configs, nvim  │  │
│  └─────────────────┘  └──────────────────────┘  │
│                                                  │
│  ┌─────────────────┐  ┌──────────────────────┐  │
│  │ ~/.local/bin/    │  │ ~/.cache/shell/      │  │
│  │ (user scripts)   │  │ (cached eval output) │  │
│  └─────────────────┘  └──────────────────────┘  │
└─────────────────────────────────────────────────┘
         │
    ─────┼──────── Trust boundary ────────
         │
┌─────────────────────────────────────────────────┐
│ External (untrusted zone)                        │
│  GitHub (repo hosting), Homebrew, Nix,           │
│  Zinit plugins, Neovim plugins, npm, pip         │
└─────────────────────────────────────────────────┘
```

## Threat Actors

| Actor | Motivation | Capability |
|-------|-----------|------------|
| Supply chain attacker | Inject malicious code via dependency | Compromise upstream packages (Homebrew, npm, Zinit plugins) |
| Secrets harvester | Steal API keys, SSH keys, tokens | Scrape git history, shell history, env vars |
| Privilege escalation | Gain root access | Exploit `sudo` aliases, writable scripts in PATH |
| Network attacker | Intercept credentials | MITM on install scripts, curl-pipe-bash |

## Attack Surfaces

### 1. Shell Startup Scripts

**Risk:** Malicious code in sourced files executes with user privileges on every shell start.

**Mitigations:**
- All shell scripts pass `shellcheck --severity=error`
- `set -euo pipefail` enforced in all operational scripts
- `eval` usage hardened with process substitution (`. /dev/stdin`)
- Input validation on dynamic function generation
- `DOTFILES_ULTRA_FAST=1` bypasses all non-core sourcing

### 2. Secrets Exposure

**Risk:** API keys, tokens, and SSH keys leaked via git history, shell history, or environment.

**Mitigations:**
- [Gitleaks](https://github.com/gitleaks/gitleaks) pre-commit hook blocks secrets in commits
- Atuin `history_filter` excludes sensitive patterns
- Age encryption for local secret storage
- `dot secrets set` uses secure prompts (no shell history)
- `.gitignore` excludes `key.txt`, `.env`, credential files

### 3. Supply Chain Dependencies

**Risk:** Compromised upstream packages injected into the toolchain.

**Mitigations:**
- Nix Flakes provide reproducible, pinned dependencies
- Zinit plugin versions pinned (`ver"0.8.0"`)
- Neovim plugin versions locked via `lazy-lock.json`
- `install.sh` uses HTTPS for all downloads
- Homebrew formula integrity via bottle checksums

### 4. Path Manipulation

**Risk:** Attacker places malicious binary in a PATH directory that shadows legitimate tools.

**Mitigations:**
- PATH construction is deterministic (template-generated)
- `~/.local/bin` is user-controlled and checked for writability
- No world-writable directories in PATH
- `prependpath` function validates directory existence

### 5. Template Injection

**Risk:** Chezmoi template variables could inject shell code if not properly quoted.

**Mitigations:**
- Template variables come from `.chezmoidata.toml` (user-controlled)
- No external/network data used in templates
- Template validation via `chezmoi apply --dry-run` in CI

### 6. Cached Eval Files

**Risk:** Stale or tampered cache files in `~/.cache/shell/` sourced at startup.

**Mitigations:**
- `_cached_eval` validates cache against binary mtime
- Cache files are user-owned (0644)
- Cache directory is under `$XDG_CACHE_HOME` (user-controlled)
- Cache can be cleared with `rm -rf ~/.cache/shell/`

## Residual Risks

| Risk | Likelihood | Impact | Status |
|------|-----------|--------|--------|
| Zinit plugin compromise | Low | High | Mitigated by version pinning |
| Shell history leak | Medium | Medium | Mitigated by Atuin filter |
| Stale Nix closure | Low | Low | Accepted (manual `nix flake update`) |
| macOS Keychain access | Low | Medium | Accepted (OS-level protection) |

## Recommendations

1. Run `gitleaks detect` before every push (pre-commit hook enforced)
2. Rotate secrets on a 90-day schedule
3. Audit `lazy-lock.json` diffs when updating Neovim plugins
4. Pin Homebrew versions for security-critical tools
5. Use `DOTFILES_ULTRA_FAST=1` in CI to minimize attack surface
