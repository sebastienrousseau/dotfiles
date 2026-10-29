# AI Aliases

Manage AI and LLM command-line aliases. Part of the **Universal Dotfiles** configuration.

![Dotfiles banner][banner]

## Description

These aliases are defined in `ai.aliases.sh`. Loaded by the lazy alias layer `~/.config/shell/91-ux-aliases-lazy.sh`. It loads after the eager layer (zsh defers it until after startup), so its definitions replace any eager alias of the same name. Skipped when `DOTFILES_ALIAS_PROFILE=minimal` at `chezmoi apply` time.

The `d*` aliases call `dot ai <agent>`, an older spelling that `dot ai` still passes to its agent module (it runs the agent one-shot with the local context). The ADR-020 spelling is `dot ai run <agent>`, which takes `--style <pattern>` too.

## Aliases

| Name | Definition | Notes |
| --- | --- | --- |
| `dai` | `dot ai` | Opens the `dot ai` cockpit. |
| `daid` | `dot ai` | Same as `dai` (it used to open the dashboard). |
| `daish` | `dot ai` | Same as `dai`. |
| `dcla` | `dot ai claude --style architect` |  |
| `dclh` | `dot ai claude --style hardener` |  |
| `dclr` | `dot ai claude --style refactor` |  |
| `dagy` | `dot ai agy` |  |
| `dagya` | `dot ai agy --style architect` |  |
| `dagyh` | `dot ai agy --style hardener` |  |
| `dagyr` | `dot ai agy --style refactor` |  |
| `dkm` | `dot ai kimi` |  |
| `dkma` | `dot ai kimi --style architect` |  |
| `dkmh` | `dot ai kimi --style hardener` |  |
| `dkmr` | `dot ai kimi --style refactor` |  |
| `dkia` | `dot ai kiro --style architect` |  |
| `dkih` | `dot ai kiro --style hardener` |  |
| `dkir` | `dot ai kiro --style refactor` |  |
| `aid` | `aider --read ~/.config/ai/identity.md` | Only when `aider` is on PATH. |
| `aida` | `aider --read ~/.config/ai/identity.md --chat-mode ask` | Only when `aider` is on PATH. |
| `aidc` | `aider --read ~/.config/ai/identity.md --chat-mode code` | Only when `aider` is on PATH. |
| `aidw` | `aider --read ~/.config/ai/identity.md --watch-files` | Only when `aider` is on PATH. |
| `cl` | `claude` | Only when `claude` is on PATH. |
| `clc` | `claude --chat` | Only when `claude` is on PATH. |
| `clp` | `claude < ~/.config/ai/identity.md` | Pipes `~/.config/ai/identity.md` to Claude Code on stdin. Only when `claude` is on PATH. Replaces `clp` from `clear.aliases.sh` (eager layer). |
| `cod` | `codex` | Only when `codex` is on PATH. Replaces the `cod` directory shortcut from the cd aliases (eager layer). |
| `codi` | `codex instruct` | Only when `codex` is on PATH. |
| `fab` | `fabric` | Only when `fabric` is on PATH. |
| `kiro` | `kiro-cli` | Only when `kiro-cli` is on PATH. |
| `kiri` | `kiro-cli` | Only when `kiro-cli` is on PATH. |
| `kic` | `kiro-cli chat` | Only when `kiro-cli` is on PATH. |
| `kit` | `kiro-cli term` | Only when `kiro-cli` is on PATH. |
| `agyi` | `agy info` | Only when `agy` is on PATH. |
| `agys` | `agy chat` | Only when `agy` is on PATH. |
| `km` | `kimi` | Only when `kimi` is on PATH. |
| `kmc` | `kimi` | Only when `kimi` is on PATH. |
| `kmp` | `kimi -p` | Only when `kimi` is on PATH. |
| `ghcp` | `gh copilot` | Only when `gh` is on PATH. |
| `ghe` | `gh copilot explain` | Only when `gh` is on PATH. |
| `ghs` | `gh copilot suggest` | Only when `gh` is on PATH. |
| `gaic` | `git-ai-commit` | Only when `git-ai-commit` is on PATH. |
| `gaice` | `git-ai-commit --edit` | Only when `git-ai-commit` is on PATH. |
| `gaid` | `git-ai-diff` | Only when `git-ai-diff` is on PATH. |
| `gaids` | `git-ai-diff --staged` | Only when `git-ai-diff` is on PATH. |
| `ol` | `ollama` | Only when `ollama` is on PATH. |
| `oll` | `ollama list` | Only when `ollama` is on PATH. |
| `ollama-show` | `ollama show --modelfile` | Only when `ollama` is on PATH. |
| `olp` | `ollama ps` | Only when `ollama` is on PATH. |
| `olr` | `ollama run` | Only when `ollama` is on PATH. |
| `oc` | `opencode` | Only when `opencode` is on PATH. |
| `ocr` | `opencode run` | Only when `opencode` is on PATH. |
| `ai` | `sgpt` | Only when `sgpt` is on PATH. |
| `aic` | `sgpt --code` | Only when `sgpt` is on PATH. |
| `aie` | `sgpt --shell` | Only when `sgpt` is on PATH. |
| `ah` | `autohand` | Only when `autohand` is on PATH. |
| `ahc` | `autohand chat` | Only when `autohand` is on PATH. |
| `ahr` | `autohand run` | Only when `autohand` is on PATH. |
| `vb` | `vibe` | Only when `vibe` is on PATH. |
| `vbc` | `vibe chat` | Only when `vibe` is on PATH. |
| `vbr` | `vibe run` | Only when `vibe` is on PATH. |
| `qw` | `qwen` | Only when `qwen` is on PATH. |
| `qwc` | `qwen chat` | Only when `qwen` is on PATH. |
| `qwr` | `qwen run` | Only when `qwen` is on PATH. |
| `za` | `zai` | Only when `zai` is on PATH. |
| `zac` | `zai chat` | Only when `zai` is on PATH. |
| `zar` | `zai run` | Only when `zai` is on PATH. |
| `gt` | `ghost` | Only when `ghost` is on PATH. |
| `gts` | `ghost suggest` | Only when `ghost` is on PATH. |
| `a` | `ai_core query` | Only when `ai_core` is on PATH and `a` is not already an alias. |

[banner]: https://cloudcdn.pro/dotfiles/v2/images/titles/title-dotfiles.svg

---

Made with ❤️ by [Sebastien Rousseau](https://github.com/sebastienrousseau)
