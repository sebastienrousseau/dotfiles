# Claude Code Configuration

## Project Context

This is a personal development environment. I value:

- **Correctness over speed** - Take time to understand before acting
- **Minimal changes** - Don't refactor unless asked
- **Security-first** - Never commit secrets, validate inputs
- **Unix philosophy** - Small, composable tools

## Coding Standards

### Shell Scripts (Bash/Zsh)
- Use `shellcheck` compliance
- Quote all variables: `"$var"` not `$var`
- Use `[[ ]]` over `[ ]` in bash/zsh
- Prefer `command -v` over `which`
- Always handle errors explicitly

### Git Commits
- Sign all commits (GPG/SSH)
- Use conventional commits: `feat:`, `fix:`, `docs:`, `refactor:`
- Keep commits atomic and focused
- Include `Co-Authored-By` when AI-assisted

### Documentation
- Keep docs close to code
- Use ADRs for architectural decisions
- Prefer examples over explanations

## Environment

- **Shell**: Zsh with zinit
- **Editor**: Neovim (Lua config)
- **Dotfiles**: Managed by chezmoi
- **Package managers**: Homebrew (macOS), apt (Linux)

## Preferences

- Dark theme (Tokyo Night)
- Monospace fonts with ligatures (JetBrains Mono, Fira Code)
- Keyboard-driven workflows
- Terminal-first development

## Do NOT

- Add emojis unless explicitly requested
- Create README files proactively
- Over-engineer simple tasks
- Make assumptions about intent - ask instead
