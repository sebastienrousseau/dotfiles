<img
  src="https://kura.pro/dotfiles/v2/images/logos/dotfiles.svg"
  align="right"
/>

# Dotfiles Aliases

Modular alias definitions for 46 functional domains. 

![Dotfiles banner][banner]

This directory contains modular alias definitions managed by **chezmoi**.

## How it Works

Aliases are split into small, manageable files (e.g., `git/git.aliases.sh`, `docker/docker.aliases.sh`).

During `chezmoi apply`, the main template `dot_config/shell/aliases.sh.tmpl`:
1. Scans this directory for `**/*.aliases.sh` files.
2. Aggregates them into a single `~/.config/shell/aliases.sh` file.
3. This aggregated file is sourced by your `.zshrc`.

## Usage

### Adding a New Alias
1. Create a new directory or file (e.g., `mytool/mytool.aliases.sh`).
2. Define your aliases:
   ```bash
   alias mycmd="echo 'Hello World'"
   ```
3. Apply changes:
   ```bash
   chezmoi apply
   ```

## Component List

Aliases are grouped and alphabetized for easier discovery.

### Core
- [archives](archives/README.md)
- [cd](cd/README.md)
- [chmod](chmod/README.md)
- [clear](clear/README.md)
- [configuration](configuration/README.md)
- [default](default/README.md)
- [diagnostics](diagnostics/README.md)
- [disk-usage](disk-usage/README.md)
- [docker](docker/README.md)
- [editor](editor/README.md)
- [find](find/README.md)
- [git](git/README.md)
- [gnu](gnu/README.md)
- [installer](installer/README.md)
- [interactive](interactive/README.md)
- [make](make/README.md)
- [mkdir](mkdir/README.md)
- [modern](modern/README.md)
- [ps](ps/README.md)
- [rsync](rsync/README.md)
- [sudo](sudo/README.md)
- [system](system/README.md)
- [tmux](tmux/README.md)
- [update](update/README.md)
- [uuid](uuid/README.md)

### Ecosystems
- [ai](ai/README.md)
- [benchmarks](benchmarks/README.md)
- [gcloud](gcloud/README.md)
- [go](go/README.md)
- [kubernetes](kubernetes/README.md)
- [lua](lua/README.md)
- [npm](npm/README.md)
- [pnpm](pnpm/README.md)
- [python](python/README.md)
- [rust](rust/README.md)
- [terraform](terraform/README.md)
- [vagrant](vagrant/README.md)
- [wget](wget/README.md)
- [yarn](yarn/README.md)

### Security, Compliance, and Governance
- [compliance](compliance/README.md)
- [dig](dig/README.md)
- [fonts](fonts/README.md)
- [legal](legal/README.md)
- [permission](permission/README.md)
- [security](security/README.md)
- [subversion](subversion/README.md)

### Platform Specific
- [macOS](macOS/README.md)

## Performance Profiles

The alias loader supports startup performance tuning:

- `DOTFILES_ALIAS_PROFILE=minimal`: skip heavy groups (AI, benchmarks, some infra/security modules).
- `DOTFILES_ALIAS_ECOSYSTEMS=python,node,rust,network,legacy`: load only selected ecosystem groups.
- default behavior (`all` + `standard`) loads the full alias set.

## Per-Machine Bucket Toggles

Alias buckets can be enabled/disabled in data to fit each host:

```toml
# ~/.config/chezmoi/chezmoi.toml
[data.aliases.buckets]
system = true
svn = false
```

Defaults live in `.chezmoidata.toml` under `[aliases.buckets]`.

## Strict Policy Mode

You can enforce stricter alias safety and governance:

```toml
# ~/.config/chezmoi/chezmoi.toml
[data.aliases.policy]
strict_mode = true
```

When enabled:
- destructive aliases require explicit `YES` confirmation
- `chezmoi apply` runs alias governance in strict mode before applying
- destructive actions are logged to `~/.dotfiles_destruction.log` (override with `DOTFILES_DESTRUCTIVE_LOG`)

[banner]: https://kura.pro/dotfiles/v2/images/titles/title-dotfiles.svg

---

Made with ❤️ by [Sebastien Rousseau](https://github.com/sebastienrousseau)
