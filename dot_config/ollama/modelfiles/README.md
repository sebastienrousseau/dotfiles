# Ollama Custom Modelfiles

Custom model configurations for optimized local inference.

## Models

| Model | Base | Purpose |
|-------|------|---------|
| `r1-deep` | `deepseek-r1:8b` | Extended reasoning with larger context/output |

## Building Models

Build all custom models:

```bash
# r1-deep: Extended reasoning
ollama create r1-deep -f ~/.config/ollama/modelfiles/Modelfile.r1-deep
```

## Usage

```bash
# Quick reasoning (no thinking)
r1 "What's the bug in this code?"

# Deep reasoning (with thinking)
r1-deep "Find edge cases and propose the minimal safe fix."
```

## Environment Variables

Recommended settings in your shell profile or launchd:

```bash
export OLLAMA_KEEP_ALIVE="-1"           # Keep models loaded
export OLLAMA_FLASH_ATTENTION=1         # Enable Flash Attention
export OLLAMA_KV_CACHE_TYPE="q8_0"      # Half memory, minimal quality loss
export OLLAMA_MAX_LOADED_MODELS=1       # Save RAM (2 if switching often)
```
