---
render_with_liquid: false
---

# Alias Cheatsheet

Auto-generated from the alias manifest.

## Core Shortcuts

| Alias | Command |
|-------|---------|
| `c` | `clear_screen` |
| `q` | `quit` |
| `e` | `${EDITOR}` |
| `h` | `history` |
| `_` | `sudo` |
| `i` | `epoch` |
| `l` | `dot_ls` |
| `ll` | `dot_ll` |
| `la` | `dot_la` |
| `lr` | `dot_lr` |
| `lra` | `dot_lra` |
| `lt` | `dot_lt` |
| `lta` | `dot_lta` |
| `a` | `ai_core query` |
| `d` | `dot` |

## Notes

- `dot shell alias export --output -` prints the current list from the alias manifest (as a plain bullet list; with no `--output` it writes `docs/ALIASES_CHEATSHEET.md`, not this page).
- Apply changes with `chezmoi apply`.
