# AI Integrations (Opt-in)

AI helpers are **off by default**. You choose if and when to turn them on.

## Enable AI helpers

```bash
export DOTFILES_AI=1
exec zsh
```

This turns on the local helper scripts for context suggestions and error analysis. It does not install any AI tools.

## Steering Patterns

Patterns in `~/.dotfiles/dot_config/ai/patterns/` add focused context to AI requests.

- **Architect** — shell setup and stack tuning
- **Hardener** — security, encryption, and compliance
- **Refactor** — POSIX compatibility, performance, and linting

### Contextual Bridge

Use the `dot` CLI to run AI tools with added context:

```bash
# General usage
dot cl|copilot|gemini|kiro|sgpt|ollama|opencode|aider|autohand|vibe|qwen|zai --pattern <name> "prompt"

# Quick aliases
dcla "Optimize my zshrc"      # Claude + Architect
dgmnh "Audit my ssh config"   # Gemini + Hardener
dkir "Refactor this script"   # Kiro + Refactorer
```

The bridge adds system details (OS, architecture, date) to the prompt. This gives the AI the context it needs for accurate answers.

Supported bridge commands:

| Command | Provider |
|---------|----------|
| `dot cl` | Claude Code |
| `dot copilot` | GitHub Copilot CLI |
| `dot gemini` | Gemini CLI |
| `dot kiro` | Kiro CLI |
| `dot sgpt` | Shell-GPT |
| `dot ollama` | Ollama |
| `dot opencode` | OpenCode |
| `dot aider` | Aider |
| `dot autohand` | Autohand Code |
| `dot vibe` | Mistral Vibe |
| `dot qwen` | Qwen Code |
| `dot zai` | ZAI (Zhipu AI) |

### `dot ai` status and launcher

`dot ai` shows which AI CLIs are installed, grouped by category. If `gum` is available, it also opens a quick launcher.

Current categories:

- Agents (autonomous)
- Coding (interactive)
- General (prompt-based)
- Runtime (local)
- Cloud (platform)

The launcher is simple and fast. It shows short role labels like `agent`, `coding`, `general`, `local`, and `cloud` so you can pick quickly.

To stay fast, `dot ai` caches provider info in `~/.cache/dotfiles/ai/status.tsv` for 5 minutes. You can change this with `DOTFILES_AI_STATUS_TTL`.

Related AI commands:

- `dot ai` — check status and launch tools
- `dot ai-setup` — set up AI CLIs step by step
- `dot ai-query` — run context-aware queries on the dotfiles repo

## Optional AI CLI tools

These tools are not installed for you. Pick and install only the ones you want:

- **Agents**: `claude`, `copilot`
- **Coding assistants**: `aider`, `opencode`
- **General AI**: `gemini`, `sgpt`
- **Local-first**: `ollama`
- **Coding agents**: `autohand`, `vibe`, `qwen`, `zai`
- **Cloud / platform**: `kiro-cli`

Once installed, the dotfiles add helper functions and shortcuts. These only load when `DOTFILES_AI=1` is set.

## Agentic terminal workflows

If your terminal has built-in AI agents, keep your shell lean and fast:

- Use `DOTFILES_FAST=1` or `DOTFILES_ULTRA_FAST=1`.
- Let the terminal handle agents and its own UI.
- Keep dotfiles focused on consistency, safety, and clean repeats.

## Privacy and safety

- No AI tools are installed for you.
- No background services run by default.
- You control AI helpers with `DOTFILES_AI=1`.
