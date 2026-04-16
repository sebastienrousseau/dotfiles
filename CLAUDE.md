<!--
  Role:     Repo-scoped instructions for Claude Code when operating inside
            this repository. Auto-loaded by Claude Code whenever the cwd is
            somewhere under ~/.dotfiles/.
  Audience: Claude Code, this repo only.

  Distinct from:
    - dot_claude/CLAUDE.md — your PERSONAL cross-project preferences,
                             deployed to ~/.claude/CLAUDE.md by chezmoi.
    - OPENCODE.md          — same intent as this file, but consumed by the
                             OpenCode CLI instead of Claude Code.

  When updating: keep this focused on *this repository's* conventions
  (version, layout, naming, test framework, CI). Personal style lives
  in dot_claude/CLAUDE.md, not here.
-->

# CLAUDE.md — AI Assistant Guidelines

## Project Overview

Chezmoi-managed dotfiles for macOS, Linux, WSL, and PowerShell 7.5+. Version `0.2.500`.

## Key Commands

```bash
chezmoi apply --dry-run     # Preview changes
chezmoi diff                # Show pending diffs
dot health                  # Run health dashboard
dot doctor                  # Run system diagnostics
./tests/framework/test_runner.sh  # Run unit tests
```

## Repository Layout

```
.chezmoidata.toml           # Feature flags, profiles, version (source of truth)
.chezmoitemplates/          # Reusable template partials (aliases, functions, paths)
dot_config/                 # XDG configs (~/.config/*) — largest directory
dot_local/bin/              # User scripts deployed to ~/.local/bin
scripts/                    # Repo-only scripts (ops, maintenance, CI)
tests/                      # Test suite (framework, unit, integration, performance)
docs/                       # 30+ markdown docs (architecture/, guides/, reference/, security/, operations/)
install.sh                  # Bootstrap installer (--help for usage)
version-sync.sh             # Syncs dotfiles_version across non-template files
```

## Chezmoi Naming Conventions

| Prefix/Suffix    | Effect                                         |
|------------------|-------------------------------------------------|
| `dot_`           | Deployed with leading `.` (dot_gitconfig -> .gitconfig) |
| `executable_`    | Sets +x permission                              |
| `private_`       | Sets 0600 permissions                           |
| `.tmpl`          | Processed as Go template with chezmoi data      |
| `run_onchange_`  | Script runs when target changes                 |

**Warning:** `executable_dot_foo` deploys as `.foo` (not `dot_foo`). The `dot_` prefix is consumed by chezmoi.

## Conventions

- **Shell style:** 2-space indent, `set -euo pipefail`, shellcheck-clean. Format with `shfmt -i 2 -ci`.
- **Lua style:** Format with `stylua`. Lint with `luacheck`. Globals: `vim` is allowed.
- **Templates:** Use `{{ .variable }}` syntax. Data comes from `.chezmoidata.toml`.
- **Version:** Single source of truth is `dotfiles_version` in `.chezmoidata.toml`. Template files use `{{ .dotfiles_version }}`. Non-template files are updated by `version-sync.sh` at release time.
- **Feature flags:** Gated with `{{ if .features.thing }}` in templates. Profiles defined in `.chezmoidata.toml`.
- **Zsh startup:** `.zshenv` -> `.zprofile` -> `.zshrc` -> `ZDOTDIR/.zshrc` -> `rc.d/*.zsh` (ordered by numeric prefix).
- **Caching:** `_cached_eval` pattern caches tool init output with binary mtime invalidation.
- **Neovim:** lazy.nvim plugin manager. Plugins in `lua/plugins/`. Use `vim.uv` (not deprecated `vim.loop`).
- **Git commits:** Signed with SSH ED25519. Conventional commit messages enforced by pre-commit hook.

## CI

- **Primary CI:** `ci.yml` — shellcheck (`--severity=error -e SC1091 -e SC2030 -e SC2031`), shfmt, chezmoi apply dry-run on Linux + macOS.
- **Enforced CI:** `ci-enforced.yml` — stricter aspirational checks (lint, security, copyright headers, unit/integration tests).
- Pre-commit hooks: shellcheck, shfmt, luacheck, stylua, gitleaks, conventional-commits.

## Testing

- Framework: `tests/framework/` (test_runner.sh, assertions.sh, mocks.sh)
- Unit tests: `tests/unit/` (organized by domain: aliases/, functions/, shell/, etc.)
- Integration tests: `tests/integration/`
- Run: `./tests/framework/test_runner.sh`
- Tests execute bash source files directly — do **not** use Go template syntax in non-`.tmpl` files.

## Do Not

- Add `core.hooksPath` to gitconfig (would apply repo-specific hooks to all git repos).
- Rename `executable_*` scripts to `.tmpl` unless the test framework is also updated (tests run `bash` on source files).
- Remove shellcheck disable directives without verifying CI still passes.
- Commit secrets, API keys, or tokens. Atuin `history_filter` and gitleaks are in place.
