---
name: vibe-model-pick
description: Override the Vibe model for all subsequent delegations. Usage: /vibe-model-pick <alias>
license: MIT
user-invocable: true
allowed-tools:
  - bash
---

# /vibe-model-pick

Extract the alias from the user's arguments, then run:
`echo <alias> > ~/.local/share/vibe-model.flag`

Confirm: "Model override set to <alias> — all Vibe runs will use this model until /vibe-model-clear."

If no alias provided, list available aliases from `~/.vibe/config.toml` and ask the user to pick one.
