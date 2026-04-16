<!-- Copyright (c) 2015-2026 Dotfiles. All rights reserved. -->

# Repository Layout

A map of every top-level folder and file in this repo, grouped by purpose.
Use this when you're not sure where something belongs or why a particular
directory exists.

For naming conventions (file prefixes, run-script numbering tiers), see
[`../NAMING_CONVENTIONS.md`](../NAMING_CONVENTIONS.md). For the broader
architectural rationale (philosophy, startup model, flake strategy), see
[`ARCHITECTURE.md`](ARCHITECTURE.md). For the configuration-management
strategy at a higher level, see [`../../CONFIG_STRATEGY.md`](../../CONFIG_STRATEGY.md).

---

## 1. Chezmoi source tree — the actual dotfiles

Chezmoi reads this directory and deploys to `$HOME`. Filename **prefixes**
carry semantics:

| Prefix           | Effect                                      | Example                                            |
|------------------|---------------------------------------------|----------------------------------------------------|
| `dot_`           | Deployed with a leading `.`                 | `dot_gitconfig.tmpl` → `~/.gitconfig`              |
| `private_`       | Sets `0600` perms on deploy                 | `private_dot_ssh/` → `~/.ssh/`                     |
| `executable_`    | Sets `+x` on deploy                         | `executable_dot` → `~/.local/bin/dot`              |
| `run_onchange_`  | Runs once when its content hash changes     | `run_onchange_20-ghostty-config.sh.tmpl`           |
| `.tmpl`          | Rendered as a Go template at apply time     | `dot_npmrc.tmpl`                                    |

> **Gotcha:** `executable_dot_foo` deploys as `.foo` (not `dot_foo`). Chezmoi
> consumes the `dot_` prefix even when stacked with `executable_`.

### Chezmoi data and templates

| Path                        | Role                                                                                         |
|-----------------------------|----------------------------------------------------------------------------------------------|
| `.chezmoi.toml.tmpl`        | Init-time prompts (name, email, signing key).                                                |
| `.chezmoidata.toml`         | **Source of truth** for version, profile, default theme, shell, feature flags.              |
| `.chezmoidata/`             | Split data files: `themes.toml`, `keybinds.toml`, `hardware.toml`.                           |
| `.chezmoiignore.tmpl`       | Feature-flag-gated "don't deploy these to `$HOME`" list.                                     |
| `.chezmoitemplates/`        | Reusable template partials (`aliases/`, `functions/`, `paths/`, `desktop/`). Not deployed.   |

### Shell rc files (root level)

| Path | Target | Purpose |
|---|---|---|
| `dot_bashrc`, `dot_profile` | `~/.bashrc`, `~/.profile` | Bash startup |
| `dot_zshenv`, `dot_zprofile`, `dot_zshrc` | `~/.zshenv` etc. | Zsh startup chain (see [`ARCHITECTURE.md`](ARCHITECTURE.md) for order) |
| `dot_vimrc`, `dot_inputrc`, `dot_psqlrc`, `dot_sqliterc`, `dot_Xresources` | `~/.*` | Classic per-tool dotfiles |
| `dot_gitconfig.tmpl`, `dot_npmrc.tmpl` | `~/.gitconfig`, `~/.npmrc` | Templated — identity/tokens injected at apply |
| `dot_cargo/config.toml.tmpl` | `~/.cargo/config.toml` | Rust build dirs redirected to `/tmp` |
| `dot_fdignore`, `dot_noderc`, `dot_rustfmt.toml` | `~/.*` | Per-tool config |
| `private_dot_netrc.tmpl`, `private_dot_ssh/` | `~/.netrc`, `~/.ssh/` | 0600 files |

### Large chezmoi directories

| Path          | Target            | Notes                                                                                        |
|---------------|-------------------|----------------------------------------------------------------------------------------------|
| `dot_config/` | `~/.config/`      | **Largest** — fish, zsh, nvim, ghostty, tmux, niri, mise, and ~90 other app configs.         |
| `dot_local/bin/` | `~/.local/bin/` | Every `dot-*` subcommand and helper script (the `dot` CLI lives here).                        |
| `dot_local/share/` | `~/.local/share/` | Fonts and shared data.                                                                     |
| `dot_etc/opt/chrome/policies/` | `~/etc/opt/chrome/policies/` | Managed Chrome enterprise policies.                                              |

### `run_onchange_*` hooks at the root

Scripts triggered when their content changes. Numbering follows the
convention in [`../NAMING_CONVENTIONS.md`](../NAMING_CONVENTIONS.md):

- `run_onchange_20-ghostty-config.sh.tmpl` — re-renders Ghostty config
- `run_onchange_21-topgrade-config.sh.tmpl` — refreshes topgrade config
- `run_onchange_after_fonts.sh` — post-deploy font cache refresh

---

## 2. AI-assistant files — **three** files, three distinct roles

This is the most common source of confusion in the repo. All three files
exist on purpose and don't overlap:

| File                          | Deployed to           | Audience                                                         | Scope                         |
|-------------------------------|-----------------------|------------------------------------------------------------------|-------------------------------|
| `dot_claude/CLAUDE.md`        | `~/.claude/CLAUDE.md` | Claude Code, in **any** cwd on this machine                      | Personal, cross-project       |
| `CLAUDE.md` (repo root)       | Not deployed          | Claude Code, when cwd is **this** repo                           | Repo-scoped guidance          |
| `OPENCODE.md` (repo root)     | Not deployed          | OpenCode CLI, when cwd is **this** repo                          | Repo-scoped guidance (mirror) |
| `.claude/settings.local.json` | Not deployed, **not tracked** | Claude Code                                                     | Per-machine permission allowlist |

Each of the three tracked files carries a header comment explaining its
role to prevent drift. Keep that header in place when editing.

---

## 3. Agent-protocol surface

Standards-compliant discovery endpoints that let external agents and tools
find this workstation's agent capabilities:

| Path                                | Purpose                                                                     |
|-------------------------------------|-----------------------------------------------------------------------------|
| `.well-known/agent-card.json`       | A2A v0.3 agent card — skills, capabilities, URL                             |
| `.well-known/agent.json`            | Legacy pointer card, kept for back-compat                                   |
| `.well-known/mcp/server-card.json`  | MCP server discovery manifest                                               |

---

## 4. CI/CD and repo metadata

| Path                                                             | Purpose                                                        |
|------------------------------------------------------------------|----------------------------------------------------------------|
| `.github/workflows/`                                             | 20+ workflows: `ci.yml`, `ci-enforced.yml`, reusable lints, release pipelines |
| `.github/workflows/reusable-*.yml`                               | Shared workflow fragments (`shell-lint`, `lua-lint`, `nix-lint`, `copyright-lint`, `test-suite`, `secrets-scan`, `security-baseline`) |
| `.github/ISSUE_TEMPLATE/`, `PULL_REQUEST_TEMPLATE.md`, `CODEOWNERS`, `SECURITY.md`, `CONTRIBUTING.md`, `CODE-OF-CONDUCT.md`, `FUNDING.yml` | Standard GitHub metadata                                       |
| `.github/security-policies/`                                     | Org-level security policy files                                |
| `.github/branch-protection-config.json`, `BRANCH_PROTECTION.md`  | Codified branch-protection settings                            |
| `.github/dependabot.yml`                                         | Dependency bump schedule                                       |
| `.devcontainer/`                                                 | GitHub Codespaces + VS Code dev container                      |
| `Dockerfile.test`, `tests/Dockerfile.sandbox`                    | Ubuntu sandboxes for integration / e2e tests                   |

---

## 5. Build, bootstrap, and dev tooling

| Path                                    | Purpose                                                                        |
|-----------------------------------------|--------------------------------------------------------------------------------|
| `install.sh`                            | Top-level one-liner installer                                                  |
| `install/provision/`, `install/lib/`    | Platform-specific install helpers invoked by `install.sh`                      |
| `Makefile`, `Justfile.tmpl`, `treefmt.toml` | Convenience runners                                                            |
| `mise.toml`, `mise-versions.lock.json`  | Mise toolchain versions (locked)                                               |
| `flake.nix`, `flake.lock` (root)        | Root Nix flake for `direnv` + repo dev shell                                   |
| `nix/flake.nix`, `nix/home.nix`         | Separate flake for Home Manager activation (used by `dot upgrade` and `ci-enforced.yml → lint-nix`) |
| `lib/wasm-tools/`                       | Vendored WebAssembly tooling (build output gitignored)                          |
| `.envrc`                                | `direnv` hook into the root flake                                              |

---

## 6. Scripts (`scripts/`) — repo-local, never deployed

Nothing under `scripts/` ends up in `$HOME`. It's all tooling for running
the repo itself.

| Subdir                                    | Purpose                                                         |
|-------------------------------------------|-----------------------------------------------------------------|
| `scripts/ci/`                             | CI helpers (`check-copyright-headers.sh`, `install-chezmoi-verified.sh`, `validate-ci-config.sh`) |
| `scripts/dot/commands/`                   | Subcommand implementations for the `dot` CLI                    |
| `scripts/docs/`                           | Manual build pipeline (`build-manual.sh`, `check-manual.sh`)    |
| `scripts/theme/`                          | K-Means CIELAB theme engine + HEIC merge/convert                |
| `scripts/ops/`, `scripts/maintenance/`, `scripts/release/` | Operator tooling                                        |
| `scripts/diagnostics/`, `scripts/qa/`, `scripts/security/`, `scripts/secrets/` | Domain-scoped scripts                          |
| `scripts/fonts/`, `scripts/demo/`, `scripts/git-hooks/`, `scripts/tools/`, `scripts/tuning/`, `scripts/lib/` | Supporting scripts                                          |
| `scripts/uninstall.sh`, `scripts/version-sync.sh` | Top-level ops entrypoints                                 |

---

## 7. Documentation (`docs/`)

| Path                                  | Purpose                                                                    |
|---------------------------------------|----------------------------------------------------------------------------|
| `docs/manual/`                        | 26-page GNU-Stow-style reference manual (the v0.2.500 feature)             |
| `docs/architecture/`                  | This file + core architecture docs (ARCHITECTURE, INTEROP, fleet, walkthrough) |
| `docs/operations/`                    | Runbooks, traceability matrix, migration notes                             |
| `docs/reference/`                     | Command/config reference material                                           |
| `docs/guides/`                        | Long-form how-tos                                                          |
| `docs/security/`                      | Threat model, disclosure policy, audit records                             |
| `docs/adr/`                           | Architecture Decision Records                                              |
| `docs/themes/`                        | Theme catalogue / screenshots                                              |
| `docs/interop/`                       | Agent/MCP interop notes                                                    |
| `docs/archive/`                       | Superseded docs kept for history                                           |
| `docs/NAMING_CONVENTIONS.md`          | Naming bible (file prefixes, run-script numbering tiers)                    |
| `docs/index.md`, `docs/README.md`, `docs/AI.md`, `docs/COPYRIGHT` | Entry points                                                |

---

## 8. Tests (`tests/`)

| Path                                      | Purpose                                                                                    |
|-------------------------------------------|--------------------------------------------------------------------------------------------|
| `tests/framework/`                        | `test_runner.sh`, `assertions.sh`, `mocks.sh` — the custom shell-test framework            |
| `tests/unit/`                             | Unit tests organised by domain: `aliases/`, `ci/`, `docs/`, `dot-cli/`, `fish/`, `functions/`, `install/`, `nvim/`, `ops/`, `secrets/`, `security/`, `shell/`, `theme/`, `tools/`, `diagnostics/`, `misc/`, `nushell/` |
| `tests/integration/`                      | End-to-end install and apply flows                                                         |
| `tests/regression/`                       | Guardrail tests for previously-broken behaviours                                           |
| `tests/performance/`                      | `benchmark_runner.sh` and friends                                                          |
| `tests/benchmark.sh`, `tests/test-aliases.sh`, `tests/test-docker.sh` | Top-level entrypoints                                              |
| `tests/Dockerfile.sandbox`                | Fresh-Ubuntu sandbox image for integration tests                                           |

Tests execute shell source files directly — **do not** use Go template
syntax in non-`.tmpl` files, or the test framework will choke on the curly
braces.

---

## 9. Other top-level

| Path                                      | Purpose                                                                      |
|-------------------------------------------|------------------------------------------------------------------------------|
| `config/`                                 | Repo-local tool configs: `cliff.toml` (changelog), `gitleaks.toml`, `pre-commit-config.yaml`, `stylua.toml`, `trivyignore` |
| `templates/chezmoi-data/`, `templates/projects/` | Starter scaffolding for new machines / new projects                     |
| `examples/`                               | 14 standalone demo scripts used by the manual and tutorials                  |
| `CHANGELOG.md`, `LICENSE`, `README.md`    | Standard                                                                     |
| `CONFIG_STRATEGY.md`                      | High-level "how configuration management works here" overview                |
| `.gitattributes`, `.gitignore`, `.gitleaksignore`, `.editorconfig`, `.secrets.baseline`, `.sops.yaml`, `.luacheckrc` | Repo-level tool configs                                                    |
| `.pre-commit-config.yaml` → `config/pre-commit-config.yaml` | Symlink so `pre-commit` finds the canonical config                       |

---

## 10. Local-only artefacts (gitignored — if you see them, don't commit them)

The following paths can appear during local work but are excluded from
version control. If one of them ever shows up in `git status`, check the
`.gitignore` entry rather than adding the file:

| Path                     | Source                                                                       |
|--------------------------|------------------------------------------------------------------------------|
| `_build/`                | Output of `scripts/docs/build-manual.sh`                                     |
| `.pnpm-store/`           | pnpm's content-addressable store (should never appear here)                  |
| `.claude/`               | Claude Code per-machine state (`settings.local.json` permission allowlists)  |
| `node_modules/`          | Node dependency trees from repo-local scripts                                |
| `.version-sync-backup/`  | Timestamped backups from `version-sync.sh`                                   |
| `lib/wasm-tools/target/` | Rust build artefacts for the vendored wasm tooling                           |
| `dot_etc/machines/`      | Host-specific installer overrides                                            |

---

## How to decide where a new file belongs

A quick decision tree for common cases:

- **New app config that lives under `~/.config/<app>/`** → `dot_config/<app>/` (see `docs/NAMING_CONVENTIONS.md` → "Adding New Modules").
- **New user-facing CLI script** → `dot_local/bin/executable_<name>`.
- **New `dot` subcommand** → implementation in `scripts/dot/commands/<name>.sh`, routing in `dot_local/bin/executable_dot`.
- **New repo-only automation** (CI helper, maintenance task, release step) → `scripts/<domain>/<name>.sh`.
- **New test** → `tests/unit/<domain>/test_<feature>.sh` (follow `test_{domain}_{feature}.sh` naming).
- **New doc** → pick the narrowest of `docs/architecture/`, `docs/reference/`, `docs/guides/`, `docs/operations/`, `docs/security/`.
- **New alias file** → `.chezmoitemplates/aliases/<category>/<tool>.aliases.sh` (see conventions doc).
- **New run-once hook** → `run_onchange_<NN>-<verb>-<noun>.sh.tmpl` at the root, using the numbering tier appropriate to its category.

If none of the above fits, stop and ask in an issue or PR before
introducing a new top-level directory. The current layout is deliberate
and one-off additions cost everyone later.
