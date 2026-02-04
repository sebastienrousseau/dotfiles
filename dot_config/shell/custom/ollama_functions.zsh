# =============================================================================
# Ollama Functions - Cross-platform (macOS, Linux, WSL)
# Prefix: oq (ollama-qwen), or1 (ollama-r1) to avoid conflicts
# =============================================================================

# Skip if ollama is not installed
if ! command -v ollama &>/dev/null; then
  return 0
fi

# -----------------------------------------------------------------------------
# Quick Coding Assistant (qwen-coder-ultra)
# Usage: oq "write a Python dataclass for User"
# -----------------------------------------------------------------------------
oq() {
  if [[ -z "$1" ]]; then
    echo "Usage: oq \"your prompt here\""
    return 1
  fi
  ollama run qwen-coder-ultra "$*"
}

# -----------------------------------------------------------------------------
# Fast Reasoning (r1-ultra with --think=false)
# Usage: or1 "explain recursion"
# -----------------------------------------------------------------------------
or1() {
  if [[ -z "$1" ]]; then
    echo "Usage: or1 \"your prompt here\""
    return 1
  fi
  ollama run r1-ultra --think=false "$*"
}

# -----------------------------------------------------------------------------
# Reasoning with Visible Thinking
# Usage: or1t "solve this step by step"
# -----------------------------------------------------------------------------
or1t() {
  if [[ -z "$1" ]]; then
    echo "Usage: or1t \"your prompt here\""
    return 1
  fi
  ollama run r1-ultra "$*"
}

# -----------------------------------------------------------------------------
# Deep Reasoning (Extended context/output)
# Usage: or1d "complex analysis task"
# -----------------------------------------------------------------------------
or1d() {
  if [[ -z "$1" ]]; then
    echo "Usage: or1d \"your prompt here\""
    return 1
  fi
  ollama run r1-deep "$*"
}

# -----------------------------------------------------------------------------
# Hide Thinking Tags (filtered output)
# Usage: or1h "explain something complex"
# -----------------------------------------------------------------------------
or1h() {
  if [[ -z "$1" ]]; then
    echo "Usage: or1h \"your prompt here\""
    return 1
  fi
  ollama run r1-ultra "$*" 2>&1 | sed '/<think>/,/<\/think>/d'
}

# -----------------------------------------------------------------------------
# Model Preloading (warm up for faster first response)
# -----------------------------------------------------------------------------
ol-warm-qwen() {
  echo "Warming up qwen-coder-ultra..."
  echo "" | ollama run qwen-coder-ultra --keepalive 10m > /dev/null 2>&1
  echo "Ready!"
}

ol-warm-r1() {
  echo "Warming up r1-ultra..."
  echo "" | ollama run r1-ultra --keepalive 10m > /dev/null 2>&1
  echo "Ready!"
}

ol-warm-r1d() {
  echo "Warming up r1-deep..."
  echo "" | ollama run r1-deep --keepalive 10m > /dev/null 2>&1
  echo "Ready!"
}

ol-warm() {
  echo "Preloading all optimized models..."
  ol-warm-qwen &
  ol-warm-r1 &
  wait
  echo "All models ready!"
}

# -----------------------------------------------------------------------------
# Utility Aliases
# -----------------------------------------------------------------------------
alias ollama-status='ollama ps'
alias ollama-models='ollama list'
alias ollama-running='ollama ps --format json | jq'

# Show available custom modelfiles
ollama-modelfiles() {
  echo "Custom Modelfiles in ~/.ollama:"
  ls -1 ~/.ollama/Modelfile.* 2>/dev/null | sed 's/.*Modelfile\./  /'
}

# Quick model info
ollama-info() {
  if [[ -z "$1" ]]; then
    echo "Usage: ollama-info <model-name>"
    return 1
  fi
  ollama show "$1" --modelfile
}
