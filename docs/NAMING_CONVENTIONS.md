# Naming Conventions & Standardization Guide

This document defines the naming conventions for all files in the dotfiles repository.

---

## File Naming

| Context | Convention | Example |
|---|---|---|
| Run scripts | `run_{type}_{NN}-{verb}-{noun}.sh.tmpl` | `run_onchange_10-install-packages.sh.tmpl` |
| Shell fragments | `{NN}-{domain}-{detail}.sh.tmpl` | `90-ux-aliases.sh.tmpl` |
| Alias files | `{tool}.aliases.sh` | `git.aliases.sh` |
| Function files | `{name}.sh` (lowercase) | `apihealth.sh` |
| Test files | `test_{domain}_{feature}.sh` | `test_aliases_git.sh` |
| Scripts | `{verb}-{noun}.sh` (hyphenated) | `install-nerd-fonts.sh` |

## Run Script Numbering Tiers

| Range | Category | Examples |
|---|---|---|
| 00-09 | Audit & pre-flight | `run_before_00-audit.sh` |
| 10-19 | Package installation | `run_onchange_10-linux-packages.sh.tmpl` |
| 20-29 | Config & languages | `run_onchange_20-ghostty-config.sh.tmpl` |
| 25-29 | Language toolchains | `run_onchange_25-python-tools.sh.tmpl` |
| 30-39 | Applications | `run_onchange_30-vscode-extensions.sh.tmpl` |
| 40-49 | System defaults | `run_onchange_40-darwin-default-apps.sh.tmpl` |
| 50-59 | Assets (fonts, themes) | `run_onchange_50-install-fonts.sh.tmpl` |

---

## Adding New Modules

### New app config

1. Create `dot_config/<app>/` with chezmoi-compatible filenames
2. Add entry to `dot_config/.module-manifest.json`
3. Optionally gate with feature flag in `.chezmoidata.toml` + `.chezmoiignore.tmpl`

### New alias category

1. Create `.chezmoitemplates/aliases/<category>/<name>.aliases.sh`
2. It will be auto-discovered by the `**/*.aliases.sh` glob
3. Add to `$coreCategories` list in `90-ux-aliases.sh.tmpl` for eager loading; otherwise it loads lazily

### New function

1. Create file in `.chezmoitemplates/functions/<group>/`
2. Add to `groups.json` with the `<group>/<filename>` path
3. It auto-registers for lazy loading via `51-logic-functions-extra.sh.tmpl`

### New provisioning script

1. Create `install/provision/run_onchange_{NN}-{name}.sh.tmpl`
2. Use the numbering tiers above
3. Source `install/lib/os_detection.sh` for platform detection
4. Guard OS-specific code with `{{ if eq .chezmoi.os "darwin" }}`

---

## Directory Structure Overview

```
.chezmoitemplates/
  aliases/        # 48 categories, auto-discovered
  functions/      # Grouped by domain (api/, curl/, text/, system/, etc.)
  paths/          # PATH construction templates
  desktop/        # Desktop environment templates (dconf)

dot_config/       # Flat — chezmoi constraint, no intermediate grouping

install/
  lib/            # Shared helpers (os_detection, logging, installers)
  provision/      # run_onchange_* provisioning scripts

scripts/          # Repo-only scripts (not deployed)
  dot/            # dot CLI subcommands
  ops/            # Operations scripts
  diagnostics/    # Health checks
  security/       # Security tools
  ...

tests/            # Test suite (not deployed)
  framework/      # Test runner, assertions, mocks
  unit/           # Domain-organized unit tests
  integration/    # End-to-end tests
  performance/    # Benchmarks

docs/             # Documentation (not deployed)
  architecture/   # System design docs
  guides/         # How-to guides
  reference/      # Reference material
  security/       # Security documentation
  operations/     # Ops and maintenance docs
```
