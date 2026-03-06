# shellcheck shell=bash
# Copyright (c) 2015-2026 Sebastien Rousseau. All rights reserved.
# AI & Intelligent Assistance Aliases

# Dotfiles AI Bridge (Context-aware wrappers)
alias dcl='dot cl'
alias dcla='dot cl --pattern architect'
alias dclh='dot cl --pattern hardener'
alias dclr='dot cl --pattern refactor'

alias dgmn='dot gemini'
alias dgmna='dot gemini --pattern architect'
alias dgmnh='dot gemini --pattern hardener'
alias dgmnr='dot gemini --pattern refactor'

alias dki='dot kiro'
alias dkia='dot kiro --pattern architect'
alias dkih='dot kiro --pattern hardener'
alias dkir='dot kiro --pattern refactor'

# Aider (AI Pair Programming)
if command -v aider &>/dev/null; then
  # Note: Use a fixed path for the identity file to avoid shellcheck warnings
  # and ensure it resolves correctly in different shells.
  alias aid='aider --read ~/.config/ai/identity.md'
  alias aida='aider --read ~/.config/ai/identity.md --chat-mode ask'
  alias aidc='aider --read ~/.config/ai/identity.md --chat-mode code'
  alias aidw='aider --read ~/.config/ai/identity.md --watch-files'
fi

# Claude Code
if command -v claude &>/dev/null; then
  alias cl='claude'
  alias clc='claude --chat'
  # Provide context as a system prompt if possible (assuming file read support or piping)
  alias clp='claude < ~/.config/ai/identity.md'
fi

# OpenAI Codex CLI
if command -v codex &>/dev/null; then
  alias cod='codex'
  alias codi='codex instruct'
fi

#fabric (AI Helper)
if command -v fabric &>/dev/null; then
  alias fab='fabric'
fi

# Kiro CLI (AI terminal assistant)
if command -v kiro-cli &>/dev/null; then
  alias kiro='kiro-cli'
  alias kic='kiro-cli chat'
  alias kit='kiro-cli term'
fi

# Google Gemini CLI
if command -v gemini &>/dev/null; then
  alias gemi='gemini info'
  alias gems='gemini chat'
  alias gmn='gemini'
fi

# GitHub Copilot CLI
if command -v gh &>/dev/null; then
  alias ghcp='gh copilot'
  alias ghe='gh copilot explain'
  alias ghs='gh copilot suggest'
fi

# Git AI Helpers (commit message gen & diff review)
if command -v git-ai-commit &>/dev/null; then
  alias gaic='git-ai-commit'
  alias gaice='git-ai-commit --edit'
fi

if command -v git-ai-diff &>/dev/null; then
  alias gaid='git-ai-diff'
  alias gaids='git-ai-diff --staged'
fi

# Ollama (Local LLM)
if command -v ollama &>/dev/null; then
  alias ol='ollama'
  alias oll='ollama list'
  alias ollama-show='ollama show --modelfile'
  alias olp='ollama ps'
  alias olr='ollama run'
fi

# OpenCode CLI
if command -v opencode &>/dev/null; then
  alias oc='opencode'
  alias ocr='opencode run'
fi

# Shell GPT
if command -v sgpt &>/dev/null; then
  alias ai='sgpt'
  alias aic='sgpt --code'
  alias aie='sgpt --shell'
fi

# ai_core wrapper (fast query shortcut)
if command -v ai_core &>/dev/null; then
  if ! alias a >/dev/null 2>&1; then
    alias a='ai_core query'
  fi
fi
