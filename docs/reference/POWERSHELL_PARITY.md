---
render_with_liquid: false
title: "PowerShell parity matrix"
description: "What works on Windows-native PowerShell 7.4 LTS / 7.5+ vs the bash surface."
---

# PowerShell parity matrix

This document tracks what is supported on Windows-native PowerShell 7.4 LTS / 7.5+ compared to the bash/zsh surface that ships on macOS and Linux. The repo's positioning has shifted (per [ROADMAP_2026 §6.9](../operations/ROADMAP_2026.md)) to call PowerShell a first-class target rather than "best effort." This page is the contract.

## Support tiers

| Tier | Meaning | Examples |
|---|---|---|
| **Full** | Native PowerShell path; tested in CI on `windows-latest`. | `dot version`, `dot help`, `dot agents check`. |
| **WSL-bridged** | Runs under WSL2 bash with the same UX as Linux. | All `dot` subcommands, the test suite, the cold-start bench. |
| **Bash-bridged** | The PowerShell dispatcher delegates to Git Bash or WSL bash and fails clearly when bash is unavailable. | `dot registry`, `dot fleet apply`, Unix-specific diagnostics. |
| **N/A** | The command targets a Unix-only surface and is not exposed on PowerShell. | Wallpaper-driven theming via macOS `defaults`; Linux-only `lock-configs.sh`. |

## Command-by-command matrix

| Command | Windows-native | WSL2 | macOS | Linux |
|---|---|---|---|---|
| `dot version` | **Full (native)** — `Get-DotVersion` cmdlet in `scripts/dot/powershell/Dot.psm1`; reads `.chezmoidata.toml` directly, no bash | Full | Full | Full |
| `dot help` | **Full (native)** — `Invoke-DotHelp`; detailed Unix command help remains bash-bridged | Full | Full | Full |
| `dot status` | **Full (native)** — structured clean/drifted result from chezmoi | Full | Full | Full |
| `dot diff` / `apply` / `sync` / `update` | **Full (native)** — direct, exit-code-checked chezmoi operations | Full | Full | Full |
| `dot add` / `remove` / `init` / `cd` | **Full (native)** — direct chezmoi operations and source-path lookup | Full | Full | Full |
| `dot doctor` | **Full (native baseline)** — PowerShell, chezmoi, git, repo data, and module checks; Unix-only diagnostics are bash-bridged | Full | Full | Full |
| `dot agents check` | **Full (native)** — `Test-DotAgentsSync` cmdlet; CI smoke test runs the cmdlet directly | Full | Full | Full |
| `dot agents list` | **Full (native)** — structured harness/path/rendered records | Full | Full | Full |
| `dot agents render` | Bash-bridged | Full | Full | Full |
| `dot env list` | **Full (native)** — mise text or JSON inventory | Full | Full | Full |
| `dot env emit` | Bash-bridged | Full | Full | Full |
| `dot fleet status` | **Full (native)** — node, version, OS, architecture, and drift | Full | Full | Full |
| `dot fleet drift` / `events` / `apply` / `namespace` | Bash-bridged | Full | Full | Full |
| `dot registry list` / `search` / `info` / `install` | Bash-bridged; Unix path is verified, checksum-pinned, and preview-first | Full | Full | Full |
| `dot agent` / `mode` / AI commands | Bash-bridged | Full | Full | Full |
| `dot lint` | WSL-bridged (shellcheck/shfmt are Unix-native) | Full | Full | Full |
| `dot perf` / `health` / `tools` | Bash-bridged | Full | Full | Full |
| `dot theme` / `wallpaper` | N/A on native Windows | Limited | Full | Full (desktop-dependent) |
| `dot security firewall` | Bash-bridged; no native Defender mutation | N/A | Full (pf) | Full (ufw/firewalld) |
| `dot security lock-configs` | N/A (Windows ACL model differs; tracked) | N/A | Full (`chflags uchg`) | Full (`chattr +i`) |
| Shell startup integration | Full (`Microsoft.PowerShell_profile.ps1` ships) | Full (zsh, bash, fish) | Full (zsh, bash, fish, nu) | Full (zsh, bash, fish, nu) |

## What CI verifies

| Check | Platforms |
|---|---|
| `dot version` exits 0 | windows-latest, ubuntu-latest, macos-latest, macos-14 |
| `dot help` exits 0 | windows-latest, ubuntu-latest, macos-latest, macos-14 |
| `dot agents check` exits 0 | windows-latest (native), ubuntu-latest, macos-latest, macos-14 |
| Native module import, agent-body sync, harness inventory, doctor baseline, and chezmoi diff | windows-latest |
| Native dispatcher version, help, and agents check | windows-latest |
| PowerShell ≥ 7.4 | windows-latest (smoke test at `tools/ci/windows-smoke-test.ps1`) |
| PSScriptAnalyzer Error-level findings | windows-latest |
| `chezmoi --version` exits 0 | windows-latest (via scoop), all Unix matrices |
| `bash tools/ci/dot-cli-startup-bench.sh` median < 200ms | macos-latest |
| `bash tools/ci/dot-cli-startup-bench.sh` median < 150ms | ubuntu-latest |

## Known parity gaps

These are scoped in [`ROADMAP_2026 §C5`](../operations/ROADMAP_2026.md) but not in this PR's scope:

1. **Registry and fleet mutation.** Verified registry installation and multi-node fleet application still use the explicit bash bridge.
2. **Wallpaper-driven theming.** Native Windows wallpaper extraction and application are not implemented.
3. **Windows config locking.** There is no ACL/EFS equivalent of the Unix immutable-file operation.
4. **Authenticode signing.** Release provenance covers the archive, but `install.ps1` and `dot.ps1` are not Authenticode-signed for enterprise execution policies.

## Source-of-truth files

- `.github/workflows/ci.yml` — `test-windows` job (pwsh + scoop + chezmoi + smoke)
- `tools/ci/windows-smoke-test.ps1` — the actual gate
- `bin/dot.ps1` and `scripts/dot/powershell/Dot.psm1` — native dispatcher and cmdlets
- `defaults/dot_config/powershell/Microsoft.PowerShell_profile.ps1.tmpl` — deployed profile
- `scripts/dot/lib/platform.sh` — the dot_path_to_unix/native bridge (H9 audit fix)

## Why this matters

The 2026 trend brief flagged Windows-as-first-class as the highest-leverage move post-Codex-Windows-GA (launched 2026-03-04 with 500k waitlist → 2M WAU in 4 weeks). PowerShell 7.4 LTS retires 2026-11-10, so the gate sits at "7.4+" today and will tighten to "7.5+" in November. Documented here so the gate change is not a surprise.

Generated 2026-05-16 alongside the round-2 hard audit. Maintained: when adding a `dot` subcommand, update this matrix in the same PR.
