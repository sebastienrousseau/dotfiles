---
name: dotfiles-bootstrap
description: |
  Bootstrap a workstation with the dotfiles framework. Takes a GitHub
  user / owner+repo / explicit clone URL and runs `dot init` (which
  shells out to chezmoi) with the right safety prompts. Honors the
  active agent profile (`ask` / `plan` / `apply` / `audit`) so it
  defaults to dry-run in safer modes and full apply in `apply`.
version: 1.0.0
maintainer: Sebastien Rousseau <sebastian.rousseau@gmail.com>
license: MIT
tags: [dotfiles, chezmoi, bootstrap, provisioning, workstation, agents]
requires:
  - chezmoi >= 2.47
  - bash >= 4.0
  - git
homepage: https://github.com/sebastienrousseau/dotfiles
docs: https://doc.dotfiles.io/manual/
---

# dotfiles-bootstrap

Provision a new workstation from a public dotfiles repository through
the [`sebastienrousseau/dotfiles`](https://github.com/sebastienrousseau/dotfiles) harness.

This skill is for Claude Code to invoke `dot init <user>` on the user's behalf — most useful when the user says "set me up like Alice" or "bootstrap a fresh laptop using my GitHub dotfiles."

## What this skill does

When invoked, it:

1. **Verifies** the target argument is one of:
   - a GitHub username (e.g. `alice` → expands to `github.com/alice/dotfiles`)
   - an `owner/repo` pair (e.g. `alice/configs`)
   - a full HTTPS or `git@host:path` clone URL
2. **Refuses** plain `http://` URLs (no transit integrity).
3. **Reads** the user's current agent profile from `$DOT_AGENT_PROFILE` (defaults to `ask`):
   - `ask` → run `dot init <user> --dry-run` (read-only preview)
   - `plan` → run `dot init <user> --dry-run` and explain the plan
   - `apply` → run `dot init <user>` (full apply with `chezmoi apply`)
   - `audit` → run `dot init <user> --no-apply` (clone only, no chezmoi apply)
4. **Surfaces** the trust prompt warnings before any clone runs — the target repo's scripts execute with the user's privileges.
5. **Reports** the outcome (success / failed / aborted-by-trust-prompt) so the user can decide next steps.

## Invocation pattern

```bash
# canonical
dot init <user>                       # github.com/<user>/dotfiles
dot init <owner>/<repo>               # github.com/<owner>/<repo>
dot init <https-or-ssh-url>           # explicit URL

# safety flags
dot init <user> --dry-run             # preview only
dot init <user> --no-apply            # clone, skip chezmoi apply
dot init <user> --force               # overwrite existing chezmoi source dir
```

## Profile-aware defaults

| Profile  | Default flag set       | Notes                                                |
|----------|------------------------|------------------------------------------------------|
| `ask`    | `--dry-run`            | Show the plan; ask the user before running for real. |
| `plan`   | `--dry-run`            | Same plan, augmented with chezmoi diff if available. |
| `apply`  | (no flags)             | Full apply; interactive trust prompt remains.        |
| `audit`  | `--no-apply`           | Clone the source; let the user inspect before apply. |

## Failure modes the skill surfaces

- `chezmoi` not installed → instruct user to run `install.sh` first
- URL refuses HTTPS check → ask user for explicit confirmation if SSH
- Target chezmoi source dir already exists → ask user about `--force`
- Trust prompt aborted → return cleanly, no state mutation
- `chezmoi init` non-zero exit → surface the chezmoi stderr to the user

## Why this skill exists

Closes the round-1 audit's adoption gap "bootstrap a foreign dotfiles repo through this framework's harness." Without the skill, a Claude Code session has to remember the right flag set for the user's current trust posture; with the skill, the profile dictates the safe default.

## References

- `dot init` source: [`scripts/dot/commands/init.sh`](https://github.com/sebastienrousseau/dotfiles/blob/main/scripts/dot/commands/init.sh)
- Roadmap entry: [ROADMAP_2026 §B2](https://github.com/sebastienrousseau/dotfiles/blob/main/docs/operations/ROADMAP_2026.md)
- AGENTS.md / CLAUDE.md sync: `dot agents render`
