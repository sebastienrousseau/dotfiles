<!--
  Role:     Personal, cross-project Claude Code preferences.
  Deployed: ~/.claude/CLAUDE.md (via chezmoi — the dot_claude/ source prefix
            strips to .claude/ on apply).
  Audience: Claude Code, when it operates in ANY working directory on this
            machine. Applies to every project you work on.

  Distinct from:
    - CLAUDE.md       (repo root) — instructions scoped to THIS repo only.
    - docs/OPENCODE.md         — the OpenCode CLI equivalent of the above.

  Keep this file terse — style and tooling preferences only. Anything
  project-specific belongs in that project's own CLAUDE.md, not here.
-->

# Personal Claude Code Preferences

## Style

- Concise responses, no filler
- Use conventional commits
- Shell: 2-space indent, set -euo pipefail
- Lua: stylua formatting

## Handing over commands

Whenever I need to run shell steps myself (signed-commit flows
where your Bash tool can't reach my ssh-agent, interactive
prompts, anything destructive that needs my eyes first), hand
them over as ONE runnable script — never scattered one-liners.

- A single fenced ```bash block, or a file under `.git/`, or
  somewhere else outside the working tree.
- First line: `set -euo pipefail`.
- Quote heredocs (`<<'EOF'`) so commit messages don't
  interpolate.
- Normalise cwd up front: `cd "$(git rev-parse --show-toplevel)"`.
- Multi-phase work goes in one script with labelled sections,
  not multiple scripts I have to chain.
- After the script, one line on what it does and what to tell
  you next.

Applies to every project, not just the one this preference was
captured in.

## Tools

- Package manager: mise (not asdf, not nvm)
- Shell: zsh (primary), fish, bash
- Editor: Neovim with lazy.nvim
- Dotfiles: chezmoi-managed
