# AI Integrations (Opt-in)

Dotfiles keeps AI helpers **disabled by default**. You decide if and when to enable them.

## Enable AI helpers

```bash
export DOTFILES_AI=1
exec zsh
```

This enables the local helper scripts (context suggestions and error analysis) without installing any AI tools.

## Steering Patterns

Managed patterns in `~/.dotfiles/dot_config/ai/patterns/` prepend specialized context to AI requests.

- **Architect** — shell infrastructure and stack optimization
- **Hardener** — security, encryption, and compliance
- **Refactor** — POSIX portability, performance, and linting

### Contextual Bridge

Use the `dot` CLI to invoke AI tools with automated context:

```bash
# General usage
dot cl|gemini|kiro --pattern <name> "prompt"

# Quick aliases
dcla "Optimize my zshrc"      # Claude + Architect
dgmnh "Audit my ssh config"   # Gemini + Hardener
dkir "Refactor this script"   # Kiro + Refactorer
```

The bridge automatically injects system metadata (OS, Architecture, Date) into the prompt, giving the AI the technical context it needs for accurate answers.

## Optional AI CLI tools

These tools aren't installed automatically. Install only what you want:

- **Local-first**: `ollama` (run models locally)
- **Cloud**: `codex`, `sgpt`, `claude`, `gemini` (provider CLIs)

After installation, the dotfiles can surface basic helper functions and shortcuts, but only when `DOTFILES_AI=1` is set.

## Agentic terminal workflows

If you use an agentic terminal (e.g., terminals with built-in workflow agents), keep your shell minimal and fast:

- Use `DOTFILES_FAST=1` or `DOTFILES_ULTRA_FAST=1`.
- Let the terminal layer handle agents and UI.
- Keep dotfiles focused on consistency, safety, and reproducibility.

## Privacy and safety

- No AI tools are installed automatically.
- No background daemons are enabled by default.
- You control whether AI helpers load via `DOTFILES_AI=1`.
