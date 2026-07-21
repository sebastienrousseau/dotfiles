# shellcheck shell=bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# AI & Intelligent Assistance Aliases

# Dotfiles AI Bridge (Context-aware wrappers)
alias dai='dot ai'  # the cockpit
alias daid='dot ai' # was: dot ai dashboard
alias daish='dot ai'

alias dcl='dot ai claude'
alias dcla='dot ai claude --style architect'
alias dclh='dot ai claude --style hardener'
alias dclr='dot ai claude --style refactor'

alias dagy='dot ai agy'
alias dagya='dot ai agy --style architect'
alias dagyh='dot ai agy --style hardener'
alias dagyr='dot ai agy --style refactor'

alias dkm='dot ai kimi'
alias dkma='dot ai kimi --style architect'
alias dkmh='dot ai kimi --style hardener'
alias dkmr='dot ai kimi --style refactor'

alias dki='dot ai kiro'
alias dkia='dot ai kiro --style architect'
alias dkih='dot ai kiro --style hardener'
alias dkir='dot ai kiro --style refactor'

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

# Google Antigravity CLI
if command -v agy &>/dev/null; then
  alias agyi='agy info'
  alias agys='agy chat'
  alias agy='agy'
fi

# Moonshot Kimi CLI
if command -v kimi &>/dev/null; then
  alias km='kimi'
  alias kmc='kimi'
  alias kmp='kimi -p'
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

# Autohand Code CLI
if command -v autohand &>/dev/null; then
  alias ah='autohand'
  alias ahc='autohand chat'
  alias ahr='autohand run'
fi

# Mistral Vibe CLI
if command -v vibe &>/dev/null; then
  alias vb='vibe'
  alias vbc='vibe chat'
  alias vbr='vibe run'
fi

# Qwen Code CLI
if command -v qwen &>/dev/null; then
  alias qw='qwen'
  alias qwc='qwen chat'
  alias qwr='qwen run'
fi

# ZAI CLI (Zhipu AI)
if command -v zai &>/dev/null; then
  alias za='zai'
  alias zac='zai chat'
  alias zar='zai run'
fi

# Ghost text / inline suggestions
if command -v ghost &>/dev/null; then
  alias gt='ghost'
  alias gts='ghost suggest'
fi

# ai_core wrapper (fast query shortcut)
if command -v ai_core &>/dev/null; then
  if ! alias a >/dev/null 2>&1; then
    alias a='ai_core query'
  fi
fi
