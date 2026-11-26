---
render_with_liquid: false
---

<!-- Moved from the README (wave 2, R2.3); the text is unchanged. -->

# Five shells, one alias hub

The dotfiles expose one command surface over five shells through a
hub-and-spoke bridge ([ADR-007](../../../docs/adr/ADR-007-multi-shell-parity.md)):

- **Hub** — canonical aliases and functions live once, in Bash/POSIX,
  under `defaults/.chezmoitemplates/aliases/` and
  `defaults/.chezmoitemplates/functions/`. Adding one propagates to
  every shell.
- **Tier 1 (full): zsh, bash** — direct inclusion, lazy loading,
  `_cached_eval`, staged `rc.d` modules.
- **Tier 2 (bridged): fish** — a runtime bash bridge with a cached
  `abbr` table (878 entries source in 34 ms, down from 170 ms when
  they were `alias` functions), plus native `dot` completions.
- **Tier 3 (compatible): nushell** — simple aliases extracted and
  cached to `~/.cache/nushell/bash-aliases.nu`; functions delegate to
  bash at roughly 5 ms per call
  ([ADR-011](../../../docs/adr/ADR-011-nushell-tier3-keep.md) explains why it
  stays).
- **PowerShell** — a managed profile, the native `dot.ps1` for the
  daily workflow, and a parity contract that runs on every PR
  ([`docs/reference/POWERSHELL_PARITY.md`](../../../docs/reference/POWERSHELL_PARITY.md)).

[`tests/integration/test_shell_parity.sh`](../../../tests/integration/test_shell_parity.sh)
verifies the canonical command surface and a runtime smoke in every
shell present on the runner; the `Reliability Gate` workflow adds
WSL and PowerShell contract jobs.

```bash
dot cli completion show zsh      # completions are generated from the command registry,
dot cli completion show fish     # never hand-maintained — bash, zsh, fish, and nu
dot shell alias status --tiers   # which alias tiers and ecosystems are enabled here
dot shell alias show gco         # provenance and deprecation status of one alias
```
