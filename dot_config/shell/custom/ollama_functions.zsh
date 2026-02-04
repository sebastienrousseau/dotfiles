# shellcheck shell=bash
# ollama_functions.zsh
#
# Ultra-efficient Ollama functions for local LLM inference.
# Functions are preferred over aliases for complex argument handling.
#

# -----------------------
# Model Runner Functions
# -----------------------

# Qwen Coder - fast coding assistance
qwen() {
  if [[ $# -eq 0 ]]; then
    ollama run qwen-coder-ultra
  else
    ollama run qwen-coder-ultra "$*"
  fi
}

# DeepSeek R1 - fast reasoning (no thinking)
r1() {
  if [[ $# -eq 0 ]]; then
    ollama run r1-ultra --think=false
  else
    ollama run r1-ultra --think=false "$*"
  fi
}

# DeepSeek R1 - with thinking enabled
r1think() {
  if [[ $# -eq 0 ]]; then
    ollama run r1-ultra --think
  else
    ollama run r1-ultra --think "$*"
  fi
}

# DeepSeek R1 - thinking hidden (runs but not shown)
r1hide() {
  if [[ $# -eq 0 ]]; then
    ollama run r1-ultra --hidethinking
  else
    ollama run r1-ultra --hidethinking "$*"
  fi
}

# DeepSeek R1 - deep reasoning with extended context
r1deep() {
  if [[ $# -eq 0 ]]; then
    ollama run r1-deep --think
  else
    ollama run r1-deep --think "$*"
  fi
}

# Convenience aliases for hyphenated names
alias r1-think='r1think'
alias r1-hide='r1hide'
alias r1-deep='r1deep'

# -----------------------
# Warm-up Functions
# -----------------------
# Preload models into memory (useful before a session)

warm-qwen() {
  echo "Warming up qwen-coder-ultra..."
  ollama run qwen-coder-ultra "" >/dev/null 2>&1
  echo "Ready."
}

warm-r1() {
  echo "Warming up r1-ultra..."
  ollama run r1-ultra "" >/dev/null 2>&1
  echo "Ready."
}

warm-r1-deep() {
  echo "Warming up r1-deep..."
  ollama run r1-deep "" >/dev/null 2>&1
  echo "Ready."
}
