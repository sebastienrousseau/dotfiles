# AI Aliases

Manage AI & LLM aliases (GitHub Copilot, Ollama). Part of the **Universal Dotfiles** configuration.

![Dotfiles banner][banner]

## Description

These aliases are defined in `ai.aliases.sh` and are automatically loaded by `chezmoi`.

## Aliases

### GitHub Copilot
- `ghcp` - Copilot shortcut
- `ghs` - Suggest code
- `ghe` - Explain code

### Ollama (Local LLM)
- `ol` - Ollama shortcut
- `olr` - Run a model
- `oll` - List installed models
- `olp` - Show running models
- `ollama-status` - Show loaded models and memory usage
- `ollama-show` - View model configuration (Modelfile)

> **Note:** Ollama aliases are only defined when `ollama` is installed.

[banner]: https://kura.pro/dotfiles/v2/images/titles/title-dotfiles.svg
