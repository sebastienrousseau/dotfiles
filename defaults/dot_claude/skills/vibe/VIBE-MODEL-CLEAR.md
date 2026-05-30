---
name: vibe-model-clear
description: Clear the Vibe model override and revert to the config default.
license: MIT
user-invocable: true
allowed-tools:
  - bash
---

# /vibe-model-clear

Run: `rm -f ~/.local/share/vibe-model.flag`

Confirm: "Model override cleared — Vibe will use the config default."
