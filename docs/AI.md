# AI Integrations (Opt-in)

Dotfiles keeps AI helpers **disabled by default**. You decide if and when to enable them.

## Enable AI helpers

```bash
export DOTFILES_AI=1
exec zsh
```

This enables the local helper scripts (context suggestions and error analysis) without installing any AI tools.

## Unified Identity Context

To ensure consistent responses across different AI providers, we use a centralized identity file:
`~/.config/ai/identity.md`

This file contains your professional profile, coding style preferences, and workspace context. Managed aliases for `aider` and `claude` automatically reference this file to provide high-quality, tailored assistance.

### Management
Edit the source at `~/.dotfiles/dot_config/ai/identity.md` to update your preferences globally.

## Optional AI CLI tools

These tools are **not** installed automatically. Install only what you want:

- **Local-first**: `ollama` (run models locally)
- **Cloud**: `codex`, `sgpt`, `claude`, `gemini` (provider CLIs)

After installation, the dotfiles can surface basic helper functions and shortcuts, but only when `DOTFILES_AI=1` is set.

## Optional autocomplete helpers

If you want AI-assisted completion, keep it strictly opt-in and local when possible. A typical pattern is:

1. Install the tool you want.
2. Wire it behind a wrapper function.
3. Gate it with `DOTFILES_AI=1`.

This keeps startup fast and avoids accidental background activity.

## Agentic terminal workflows

If you use an agentic terminal (e.g., terminals with built-in workflow agents), keep your shell minimal and fast:

- Use `DOTFILES_FAST=1` or `DOTFILES_ULTRA_FAST=1`.
- Let the terminal layer handle agents and UI.
- Keep dotfiles focused on consistency, safety, and reproducibility.

## Privacy and safety

- No AI tools are installed automatically.
- No background daemons are enabled by default.
- You control whether AI helpers load via `DOTFILES_AI=1`.
