# ADR-008: Alias System Architecture

## Status

Accepted

## Date

2026-03-08

## Context

The dotfiles manage 98 alias files across 30+ categories (git, docker, kubernetes, python, security, etc.). These need to load fast, support per-machine toggling, and work across Zsh, Bash, Fish, and Nushell.

**Design questions:**
1. How to organize alias files for maintainability?
2. How to control which aliases load on which machines?
3. How to balance startup speed with alias availability?
4. How to bridge POSIX aliases to non-POSIX shells?

## Decision

### Organization

Aliases are organized by tool/domain in `.chezmoitemplates/aliases/<category>/<name>.aliases.sh`:

```text
aliases/
  git/git.aliases.sh, signing.aliases.sh
  docker/docker.aliases.sh
  kubernetes/kubernetes.aliases.sh
  security/crypto-utils.aliases.sh, ssh-keys.aliases.sh, ...
  default/default.aliases.sh
  ...
```

### Profile Tiers

Three profiles control alias scope (set in `.chezmoidata.toml`):

| Profile | Scope | Use Case |
|---------|-------|----------|
| `minimal` | Core only, excludes interactive/sudo | Servers, containers |
| `standard` | All core + selected ecosystem | Laptops, workstations |
| `full` | Everything including heavy/specialized | Dev machines |

### Bucket Toggles

Per-category flags in `.chezmoidata.toml` under `[aliases.buckets]`:
```toml
[aliases.buckets]
system = true
svn = false    # disable on machines without SVN
```

### Two-Phase Loading

1. **Eager (90-ux-aliases.sh):** Core categories loaded at shell startup (~40KB). Includes: archives, cd, clear, configuration, default, diagnostics, disk-usage, editor, git, interactive, installer, mkdir, modern, ps, rsync, sudo, system.

2. **Lazy (91-ux-aliases-lazy.sh):** Ecosystem aliases deferred until first prompt via `precmd` hook. Includes: docker, kubernetes, terraform, gcloud, python, npm, rust, security, etc.

### Function Groups (groups.json)

Functions use a parallel system with `groups.json` as a registry:
- Groups: api, curl, text, system, files, interactive, nav, security, misc
- Lazy-loaded per group on first invocation
- Stub functions replaced with real implementations on first call

## Consequences

### Positive
- Adding aliases is self-service: create a file in the right category
- Per-machine customization without forking
- Lazy loading keeps startup under 200ms even with 98 alias files
- `groups.json` enables automated bridge generation for Fish/Nushell

### Negative
- Alias definitions wrap in functions (`set_default_aliases()`) for sourcing safety, adding complexity
- Two-phase loading means some aliases aren't available until after first prompt
- Profile/bucket system requires understanding .chezmoidata.toml

### Trade-offs
- Chose file-per-category over monolithic alias file for maintainability
- Chose runtime extraction for Fish/Nushell over maintaining parallel definitions
- Chose lazy loading over compile-time bundling for flexibility
