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
dot cl|copilot|gemini|kiro|sgpt|ollama|opencode|aider|autohand|vibe|qwen|zai --pattern <name> "prompt"

# Quick aliases
dcla "Optimize my zshrc"      # Claude + Architect
dgmnh "Audit my ssh config"   # Gemini + Hardener
dkir "Refactor this script"   # Kiro + Refactorer
```

The bridge automatically injects system metadata (OS, Architecture, Date) into the prompt, giving the AI the technical context it needs for accurate answers.

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

`dot ai` provides a categorized status view for installed AI CLIs and opens an interactive launcher when `gum` is available.

Current categories:

- Agents (autonomous)
- Coding (interactive)
- General (prompt-based)
- Runtime (local)
- Cloud (platform)

The launcher stays flat and fast, but adds compact role labels such as `agent`, `coding`, `general`, `local`, and `cloud` for quick selection.

To keep the command responsive, `dot ai` caches provider presence and version metadata in `~/.cache/dotfiles/ai/status.tsv` for 5 minutes by default. Override the cache TTL with `DOTFILES_AI_STATUS_TTL`.

Related AI commands:

- `dot ai` for status and launching
- `dot ai-setup` for interactive AI CLI bootstrap
- `dot ai-query` for context-aware queries over the dotfiles repo

## Optional AI CLI tools

These tools aren't installed automatically. Install only what you want:

- **Agents**: `claude`, `copilot`
- **Coding assistants**: `aider`, `opencode`
- **General AI**: `gemini`, `sgpt`
- **Local-first**: `ollama`
- **Coding agents**: `autohand`, `vibe`, `qwen`, `zai`
- **Cloud / platform**: `kiro-cli`

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
