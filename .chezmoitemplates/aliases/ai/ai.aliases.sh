# shellcheck shell=bash
# AI & Intelligent Assistance Aliases

# GitHub Copilot CLI
if command -v gh &>/dev/null; then
  alias ghcp='gh copilot'
  alias ghs='gh copilot suggest'
  alias ghe='gh copilot explain'
fi

# Fabric (AI Helper)
if command -v fabric &>/dev/null; then
  alias fab='fabric'
fi

# Ollama (Local LLM)
if command -v ollama &>/dev/null; then
  alias ol='ollama'
  alias olr='ollama run'
  alias oll='ollama list'
  alias olp='ollama ps'
  alias ollama-status='ollama ps'
  alias ollama-show='ollama show --modelfile'
fi

# Aider (AI Pair Programming)
if command -v aider &>/dev/null; then
  alias aid='aider'
  alias aidc='aider --chat-mode code'
  alias aida='aider --chat-mode ask'
  alias aidw='aider --watch-files'
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

# Claude Code
if command -v claude &>/dev/null; then
  alias cl='claude'
  alias clc='claude --chat'
fi

# Shell GPT
if command -v sgpt &>/dev/null; then
  alias ai='sgpt'
  alias aic='sgpt --code'
  alias aie='sgpt --shell'
fi
