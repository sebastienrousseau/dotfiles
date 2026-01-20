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
fi
