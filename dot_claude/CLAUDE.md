<!--
  Role:     Personal, cross-project Claude Code preferences.
  Deployed: ~/.claude/CLAUDE.md (via chezmoi — the dot_claude/ source prefix
            strips to .claude/ on apply).
  Audience: Claude Code, when it operates in ANY working directory on this
            machine. Applies to every project you work on.

  Distinct from:
    - CLAUDE.md       (repo root) — instructions scoped to THIS repo only.
    - OPENCODE.md     (repo root) — the OpenCode CLI equivalent of the above.

  Keep this file terse — style and tooling preferences only. Anything
  project-specific belongs in that project's own CLAUDE.md, not here.
-->

# Personal Claude Code Preferences

## Style
- Concise responses, no filler
- Use conventional commits
- Shell: 2-space indent, set -euo pipefail
- Lua: stylua formatting

## Tools
- Package manager: mise (not asdf, not nvm)
- Shell: zsh (primary), fish, bash
- Editor: Neovim with lazy.nvim
- Dotfiles: chezmoi-managed
