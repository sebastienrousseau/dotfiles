# shellcheck shell=bash
# AI & Intelligent Assistance Aliases

# Aider (AI Pair Programming)
if command -v aider &>/dev/null; then
  alias aid='aider'
  alias aida='aider --chat-mode ask'
  alias aidc='aider --chat-mode code'
  alias aidw='aider --watch-files'
fi

# Claude Code
if command -v claude &>/dev/null; then
  alias cl='claude'
  alias clc='claude --chat'
fi

# OpenAI Codex CLI
if command -v codex &>/dev/null; then
  alias cod='codex'
  alias codi='codex instruct'
fi

# Fabric (AI Helper)
if command -v fabric &>/dev/null; then
  alias fab='fabric'
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
