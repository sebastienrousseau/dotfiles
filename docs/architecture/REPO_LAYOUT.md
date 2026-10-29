---
render_with_liquid: false
---

<!-- SPDX-License-Identifier: Apache-2.0 OR MIT -->
<!-- Copyright (c) 2015-2026 Sebastien Rousseau -->

# Repository Layout

A map of the top-level folders and files in this repo, grouped by purpose.
Use this when you're not sure where something belongs or why a particular
directory exists.

For naming conventions (file prefixes, run-script numbering tiers), see
[`../NAMING_CONVENTIONS.md`](../NAMING_CONVENTIONS.md). For the broader
architectural rationale (philosophy, startup model, flake strategy), see
[`ARCHITECTURE.md`](../ARCHITECTURE.md). For the configuration-management
strategy at a higher level, see [`../CONFIG_STRATEGY.md`](../CONFIG_STRATEGY.md).

---

## 1. Chezmoi source tree (`defaults/`): the actual dotfiles

`.chezmoiroot` contains `defaults`, so chezmoi reads `defaults/` and deploys
it to `$HOME`. Nothing outside `defaults/` is deployed. Every path in this
section is relative to `defaults/`. Filename **prefixes** carry semantics:

| Prefix           | Effect                                      | Example                                            |
|------------------|---------------------------------------------|----------------------------------------------------|
| `dot_`           | Deployed with a leading `.`                 | `dot_gitconfig.tmpl` → `~/.gitconfig`              |
| `private_`       | Sets `0600` perms on deploy                 | `private_dot_ssh/` → `~/.ssh/`                     |
| `executable_`    | Sets `+x` on deploy                         | `dot_local/bin/executable_dot.tmpl` → `~/.local/bin/dot` |
| `run_onchange_`  | Runs once when its content hash changes     | `run_onchange_20-ghostty-config.sh.tmpl`           |
| `.tmpl`          | Rendered as a Go template at apply time     | `dot_gitconfig.tmpl`                                 |

> **Gotcha:** `executable_dot_foo` deploys as `.foo` (not `dot_foo`). Chezmoi
> consumes the `dot_` prefix even when stacked with `executable_`.

### Chezmoi data and templates

| Path                        | Role                                                                                         |
|-----------------------------|----------------------------------------------------------------------------------------------|
| `.chezmoi.toml.tmpl`        | Init-time prompts (name, email, signing key).                                                |
| `.chezmoidata.toml`         | **Source of truth** for version, profile, default theme, shell, feature flags.              |
| `.chezmoidata/`             | Split data files: `apple.toml`, `hardware.toml`, `keybinds.toml`, `secrets-patterns.toml`.   |
| `.theme-manifest/themes.toml` | Theme palette manifest read by the theme templates.                                        |
| `.chezmoiignore`, `.chezmoiignore.tmpl` | Feature-flag-gated "don't deploy these to `$HOME`" list.                         |
| `.chezmoitemplates/`        | Reusable template partials (`aliases/`, `functions/`, `desktop/`, `go-build-command`, `theme-name`). Not deployed. |

### Shell rc files

| Path | Target | Purpose |
|---|---|---|
| `dot_bashrc`, `dot_profile` | `~/.bashrc`, `~/.profile` | Bash startup |
| `dot_zshenv`, `dot_zprofile`, `dot_zshrc` | `~/.zshenv` etc. | Zsh startup chain (see [`ARCHITECTURE.md`](../ARCHITECTURE.md) for order) |
| `dot_vimrc`, `dot_inputrc`, `dot_psqlrc`, `dot_sqliterc`, `dot_Xresources` | `~/.*` | Classic per-tool dotfiles |
| `dot_gitconfig.tmpl`, `modify_private_dot_npmrc` | `~/.gitconfig`, `~/.npmrc` | Templated, identity/tokens injected at apply |
| `dot_cargo/config.toml.tmpl` | `~/.cargo/config.toml` | Cargo build settings |
| `dot_fdignore`, `dot_noderc`, `dot_rustfmt.toml` | `~/.*` | Per-tool config |
| `private_dot_netrc.tmpl`, `private_dot_ssh/` | `~/.netrc`, `~/.ssh/` | 0600 files |

### Large chezmoi directories

| Path          | Target            | Notes                                                                                        |
|---------------|-------------------|----------------------------------------------------------------------------------------------|
| `dot_config/` | `~/.config/`      | **Largest**: fish, zsh, nvim, ghostty, tmux, niri, mise, and about 80 other app configs.     |
| `dot_local/bin/` | `~/.local/bin/` | Helper scripts, plus the `~/.local/bin/dot` shim that execs the repo's `bin/dot`.            |
| `dot_local/share/` | `~/.local/share/` | Shared data: completions, man pages, icons, and the Go sources of `dot-ui`, `dot-ai-tui` and `dot-mcp`. |
| `dot_claude/`, `dot_codex/`, `dot_warp/` | `~/.claude/` etc. | Agent instructions and skills, and editor/terminal themes.                     |
| `private_Library/LaunchAgents/` | `~/Library/LaunchAgents/` | macOS launch agents.                                                     |
| `Code/` | `~/Code/` | Cross-repo standards (`AGENTS.md`, `REPO-STANDARD.md`, templates).                                           |

### `run_*` hooks

Scripts triggered when their content changes (or, for `run_before_`, before
every apply). Numbering follows the convention in
[`../NAMING_CONVENTIONS.md`](../NAMING_CONVENTIONS.md). Examples:

- `run_onchange_20-ghostty-config.sh.tmpl`: re-renders Ghostty config
- `run_onchange_24-build-dot-ui.sh.tmpl` to `26-build-dot-mcp.sh.tmpl`: build the Go tools
- `run_onchange_after_fonts.sh.tmpl`: post-deploy font cache refresh

---

## 2. The `dot` CLI and its framework

| Path | Purpose |
|---|---|
| `bin/` | The host `bin/dot` (bash), `dot.ps1`, and helpers (`dot-bootstrap`, `dot-theme-sync`, `dot-load-benchmark-pty`) |
| `plugins/<domain>/` | One plugin per domain: `dot-plugin.toml` (the manifest), `commands.txt` (its route fragment), `dot-<domain>` (its entry) and `libexec/` |
| `lib/dot/` | Shared bash library for the host and plugins, and `lib/dot/data/` (the command table, route and group records) |
| `lib/wasm-tools/` | `dot-sys` Rust crate (lib + bin), built for `wasm32-wasip1`: the health-probe record and the sandboxed verifier behind `dot attest verify`; gated by `rust.yml` |
| `core/` | Go core: `dot-core`, `dot-sandbox`, the host process layer and the transaction engine |
| `scripts/` | Runtime scripts the `dot` CLI and chezmoi hooks invoke (see [`../../scripts/README.md`](https://github.com/sebastienrousseau/dotfiles/blob/main/scripts/README.md)) |
| `schemas/` | JSON schemas, including `schemas/cli/` (manifest, registry, verbs, flags, domains) |
| `share/` | Generated completions, man pages and the PowerShell module |
| `pkg/` | Packaging: `brew/`, `scoop/`, `aur/`, `nix/`, `docker/` |
| `security/` | Registry public key and pinned remote-installer checksums |
| `supply-chain/` | Dependency provenance policy and state |

---

## 3. AI-assistant files: distinct roles

This is the most common source of confusion in the repo. Each file exists
on purpose:

| File                          | Deployed to           | Audience                                                         | Scope                         |
|-------------------------------|-----------------------|------------------------------------------------------------------|-------------------------------|
| `defaults/dot_claude/CLAUDE.md` | `~/.claude/CLAUDE.md` | Claude Code, in **any** cwd on this machine                    | Personal, cross-project       |
| `CLAUDE.md` (repo root)       | Not deployed          | Claude Code, when cwd is **this** repo                           | Repo-scoped guidance          |
| `AGENTS.md` (repo root)       | Not deployed          | Codex, Copilot, Cursor and other AGENTS.md readers               | Repo-scoped guidance (synced from `CLAUDE.md` by `dot agent context apply`) |
| `docs/OPENCODE.md`            | Not deployed          | OpenCode CLI, when cwd is **this** repo                          | Repo-scoped guidance (mirror) |
| `.claude/settings.local.json` | Not deployed, **not tracked** | Claude Code                                                     | Per-machine permission allowlist |

Each tracked file carries a header comment explaining its role to prevent
drift. Keep that header in place when editing.

---

## 4. Agent-protocol surface

Standards-compliant discovery endpoints that let external agents and tools
find this workstation's agent capabilities:

| Path                                | Purpose                                                                     |
|-------------------------------------|-----------------------------------------------------------------------------|
| `.well-known/agent-card.json`       | A2A v0.3 agent card: skills, capabilities, URL                              |
| `.well-known/agent.json`            | Legacy pointer card, kept for back-compat                                   |
| `.well-known/mcp/server-card.json`  | MCP server discovery manifest                                               |

---

## 5. CI/CD and repo metadata

| Path                                                             | Purpose                                                        |
|------------------------------------------------------------------|----------------------------------------------------------------|
| `.github/workflows/`                                             | Workflows: `ci.yml`, `ci-enforced.yml`, reusable lints, release pipelines |
| `.github/workflows/reusable-*.yml`                               | Shared workflow fragments                                      |
| `.github/actions/`                                               | Composite actions (`setup-chezmoi`)                            |
| `.github/ISSUE_TEMPLATE/`, `PULL_REQUEST_TEMPLATE.md`, `CODEOWNERS`, `FUNDING.yml` | Standard GitHub metadata                     |
| `CODE_OF_CONDUCT.md`, `CONTRIBUTING.md`, `SECURITY.md` (root, with copies under `.github/`) | Community and security policy       |
| `.github/security-policies/`                                     | Org-level security policy files                                |
| `.github/branch-protection-config.json`, `.github/BRANCH_PROTECTION.md`, `.github/rulesets/` | Codified branch-protection settings |
| `.github/dependabot.yml`                                         | Dependency bump schedule                                       |
| `.devcontainer/`                                                 | GitHub Codespaces + VS Code dev container                      |
| `tests/Dockerfile.test`, `tests/Dockerfile.sandbox`              | Ubuntu sandboxes for integration / e2e tests                   |
| `fuzz/`, `.clusterfuzzlite/`                                     | Go and shell fuzz harnesses, OSS-Fuzz and ClusterFuzzLite build files |

---

## 6. Build, bootstrap, and dev tooling

| Path                                    | Purpose                                                                        |
|-----------------------------------------|--------------------------------------------------------------------------------|
| `install.sh`                            | Top-level one-liner installer                                                  |
| `install/provision/`, `install/lib/`, `install/migrate/` | Platform-specific install helpers invoked by `install.sh`     |
| `GNUmakefile`, `Makefile`               | `make install` contract for the `dot` CLI; `make test` and other runners       |
| `defaults/dot_config/just/justfile`, `config/treefmt.toml` | Convenience runners and formatter config                    |
| `mise.toml`, `mise.lock`, `mise-versions.lock.json` | Mise toolchain versions (locked)                                   |
| `package.json`, `requirements-contracts.in`, `requirements-contracts.txt` | Node and Python dev dependencies              |
| `flake.nix`, `flake.lock` (root)        | Root Nix flake for `direnv` + repo dev shell                                   |
| `nix/flake.nix`, `nix/home.nix`         | Separate flake for Home Manager activation (used by `dot system update` and `ci-enforced.yml → lint-nix`) |
| `.envrc`                                | `direnv` hook into the root flake                                              |

---

## 7. Repo automation (`tools/`)

Nothing under `tools/` is deployed or called by the `dot` CLI. It's tooling
for running the repo itself (see [`../../tools/README.md`](https://github.com/sebastienrousseau/dotfiles/blob/main/tools/README.md)).

| Subdir                                    | Purpose                                                         |
|-------------------------------------------|-----------------------------------------------------------------|
| `tools/ci/`                               | CI helpers and gates (`check-cli-contract.py`, `cli_command_table.py`, `complexity.py`, `mutation-test.py`, `check-copyright-headers.sh`, ...) |
| `tools/docs/`                             | Manual and site builds, and the generators for man pages, completions and cmdlets |
| `tools/release/`, `tools/maintenance/`    | Release staging and maintenance tasks                           |

---

## 8. Documentation (`docs/`)

| Path                                  | Purpose                                                                    |
|---------------------------------------|----------------------------------------------------------------------------|
| `docs/manual/`                        | GNU-Stow-style reference manual (the v0.2.501 feature)                     |
| `docs/architecture/`                  | This file + INTEROP, fleet, walkthrough, theme contracts and AI cost docs (`ARCHITECTURE.md` here points to `docs/ARCHITECTURE.md`) |
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

## 9. Tests (`tests/`)

| Path                                      | Purpose                                                                                    |
|-------------------------------------------|--------------------------------------------------------------------------------------------|
| `tests/framework/`                        | `test_runner.sh`, `assertions.sh`, `mocks.sh`: the custom shell-test framework             |
| `tests/unit/`                             | Unit tests organised by domain (`aliases/`, `dot-cli/`, `functions/`, `shell/`, `theme/` and more; `ls tests/unit` for the list) |
| `tests/integration/`                      | End-to-end install and apply flows                                                         |
| `tests/regression/`                       | Guardrail tests for previously-broken behaviours                                           |
| `benches/`                                | `benchmark_runner.sh` and friends                                                          |
| `tests/benchmark.sh`, `tests/test-aliases.sh`, `tests/test-docker.sh` | Top-level entrypoints                                              |
| `tests/Dockerfile.sandbox`, `tests/Dockerfile.test` | Fresh-Ubuntu sandbox images for integration tests                               |

Tests execute shell source files directly: **do not** use Go template
syntax in non-`.tmpl` files, or the test framework will choke on the curly
braces.

---

## 10. Other top-level

| Path                                      | Purpose                                                                      |
|-------------------------------------------|------------------------------------------------------------------------------|
| `config/`                                 | Repo-local tool configs: `cliff.toml` (changelog), `gitleaks.toml`, `pre-commit-config.yaml`, `stylua.toml`, `treefmt.toml`, `typos.toml`, and others |
| `templates/chezmoi-data/`, `templates/projects/` | Starter scaffolding for new machines / new projects                     |
| `examples/`                               | Standalone demo scripts used by the manual and tutorials                     |
| `CHANGELOG.md`, `README.md`, `LICENSE-APACHE`, `LICENSE-MIT`, `LICENSES/`, `REUSE.toml` | Standard, and the dual licence     |
| `AGENTS.md`, `CLAUDE.md`, `DEVELOPMENT.md`, `GOVERNANCE.md`, `ROADMAP.md`, `SUPPORT.md` | Project guides                       |
| `CITATION.cff`, `DCO`, `KEYS.asc`, `llms.txt` | Citation metadata, contribution sign-off, signing keys, LLM site index   |
| `docs/CONFIG_STRATEGY.md`                 | High-level "how configuration management works here" overview                |
| `.gitattributes`, `.gitignore`, `.gitleaksignore`, `.gitleaks.toml`, `.editorconfig`, `.secrets.baseline`, `.sops.yaml`, `.luacheckrc`, `.markdownlint*.jsonc`, `.taplo.toml`, `.typos.toml`, `.yamllint.yaml` | Repo-level tool configs |
| `.pre-commit-config.yaml` → `config/pre-commit-config.yaml` | Symlink so `pre-commit` finds the canonical config                       |

---

## 11. Local-only artefacts (gitignored: if you see them, don't commit them)

The following paths can appear during local work but are excluded from
version control. If one of them ever shows up in `git status`, check the
`.gitignore` entry rather than adding the file:

| Path                     | Source                                                                       |
|--------------------------|------------------------------------------------------------------------------|
| `_build/`, `build/`      | Output of `tools/docs/build-manual.sh` and of `make`                         |
| `.pnpm-store/`           | pnpm's content-addressable store (should never appear here)                  |
| `.claude/`               | Claude Code per-machine state (`settings.local.json` permission allowlists)  |
| `node_modules/`          | Node dependency trees from repo-local scripts                                |
| `.version-sync-backup/`  | Timestamped backups from `version-sync.sh`                                   |
| `lib/wasm-tools/target/` | Rust build artefacts for the `dot-sys` crate, including the `wasm32-wasip1/release/dot-sys.wasm` module `dot attest verify` runs (and `fuzz/target/`) |
| `dot_etc/machines/`      | Host-specific installer overrides                                            |

---

## How to decide where a new file belongs

A quick decision tree for common cases:

- **New app config that lives under `~/.config/<app>/`** → `defaults/dot_config/<app>/` (see `docs/NAMING_CONVENTIONS.md` → "Adding New Modules").
- **New user-facing CLI script** → `defaults/dot_local/bin/executable_<name>`.
- **New `dot` subcommand** → declare it in `plugins/<domain>/dot-plugin.toml` and implement it in `plugins/<domain>/dot-<domain>` or its `libexec/` (see [`../adr/ADR-020-command-naming-system.md`](../adr/ADR-020-command-naming-system.md) and [`../../scripts/README.md`](https://github.com/sebastienrousseau/dotfiles/blob/main/scripts/README.md)).
- **New runtime script the CLI calls** → `scripts/<domain>/<name>.sh`.
- **New repo-only automation** (CI helper, maintenance task, release step, doc generator) → `tools/<ci|release|maintenance|docs>/<name>`.
- **New test** → `tests/unit/<domain>/test_<feature>.sh` (follow `test_{domain}_{feature}.sh` naming).
- **New doc** → pick the narrowest of `docs/architecture/`, `docs/reference/`, `docs/guides/`, `docs/operations/`, `docs/security/`.
- **New alias file** → `defaults/.chezmoitemplates/aliases/<category>/<tool>.aliases.sh` (see conventions doc).
- **New run-once hook** → `defaults/run_onchange_<NN>-<verb>-<noun>.sh.tmpl`, using the numbering tier appropriate to its category.

If none of the above fits, stop and ask in an issue or PR before
introducing a new top-level directory. The current layout is deliberate
and one-off additions cost everyone later.
