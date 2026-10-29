---
render_with_liquid: false
---

# Alias Deprecations

This file mirrors `scripts/dot/data/alias-deprecations.tsv`, the record `dot shell alias show <alias>` reads to report an alias as deprecated.

| Alias | Replacement | Remove In | Note |
|-------|-------------|-----------|------|
| `dlogsf` | `dklf` | `v0.2.487` | Removed duplicate logs-follow alias. The alias itself is already gone from the alias sources; only the record remains. |

No other alias is currently kept for backwards compatibility.
