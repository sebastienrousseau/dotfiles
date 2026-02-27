# TODO

- `dot_local/bin/executable_ai_core`: Supported — central AI wrapper (llamafile + Copilot CLI fallback). Needs integration tests.
- `dot_local/bin/voice_ops`: Experimental stub (Whisper speech-to-text). Not yet implemented.
- Zellij is fully feature-gated (`features.zellij = false`). Config ignored via `.chezmoiignore.tmpl`; installation gated in `run_onchange_10-linux-packages.sh.tmpl`. Only deployed when enabled in `.chezmoidata.toml` or via workstation profile.
