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
| **Full** | Native PowerShell path; tested in CI on `windows-latest`. | `dot version`, `dot help`, `dot agents check` (via WSL-bash fallback). |
| **WSL-bridged** | Runs under WSL2 bash with the same UX as Linux. | All `dot` subcommands, the test suite, the cold-start bench. |
| **Stub** | The command exists as a PowerShell entry-point but delegates to bash. | `dot init`, `dot fleet apply` (require chezmoi/ssh; both Windows-installable). |
| **N/A** | The command targets a Unix-only surface and is not exposed on PowerShell. | Wallpaper-driven theming via macOS `defaults`; Linux-only `lock-configs.sh`. |

## Command-by-command matrix

| Command | Windows-native | WSL2 | macOS | Linux |
|---|---|---|---|---|
| `dot version` | **Full (native)** — `Get-DotVersion` cmdlet in `scripts/dot/powershell/Dot.psm1`; reads `.chezmoidata.toml` directly, no bash | Full | Full | Full |
| `dot help` | **Full (native)** — `Invoke-DotHelp` cmdlet; `dot help <subcmd>` still bash-bridged | Full | Full | Full |
| `dot doctor` | Full (subset of checks; some Unix-only checks return N/A) | Full | Full | Full |
| `dot init <user>` | Full (requires `chezmoi` on PATH — install via `scoop install chezmoi`) | Full | Full | Full |
| `dot agents check` | **Full (native)** — `Test-DotAgentsSync` cmdlet; CI smoke test runs the cmdlet directly | Full | Full | Full |
| `dot agents render` / `list` | Stub (bash-bridged — `render` is a multi-harness mustache-equivalent rewrite, tracked as a separate ticket) | Full | Full | Full |
| `dot fleet status` / `drift` / `events` | Full | Full | Full | Full |
| `dot fleet apply` | Stub (bash-bridged + requires Windows OpenSSH `ssh.exe` on PATH; no native pwsh-side test in CI yet — tracked in ROADMAP §C5 follow-up) | Full | Full | Full |
| `dot fleet namespace set` | Full | Full | Full | Full |
| `dot registry list` / `search` / `info` | Full | Full | Full | Full |
| `dot registry install <name>` | Scaffold (no behavior yet on any platform) | Scaffold | Scaffold | Scaffold |
| `dot agent` / `dot mode` | Full | Full | Full | Full |
| `dot ai` / `dot ai-setup` / `dot ai-query` | Full | Full | Full | Full |
| AI bridges (`cl`, `codex`, `copilot`, `gemini`, `goose`, etc.) | Full when the underlying AI CLI is installed (scoop / winget / native) | Full | Full | Full |
| `dot lint` | WSL-bridged (shellcheck/shfmt are Unix-native) | Full | Full | Full |
| `dot perf` | Full (uses pwsh `Measure-Command` on the PS path) | Full | Full | Full |
| `dot health` | Full | Full | Full | Full |
| `dot tools` | Full (uses winget/scoop on Windows; brew/apt elsewhere) | Full | Full | Full |
| `dot theme` (wallpaper-driven) | Stub (Windows wallpaper API needs additional work) | Stub (X11 only — Wayland support pending) | Full | Full (X11 only) |
| `dot wallpaper` | Stub | Stub | Full | Full |
| `dot security firewall` | Full (Windows Defender Firewall via `Set-NetFirewallProfile`) | N/A | Full (pf) | Full (ufw/firewalld) |
| `dot security lock-configs` | N/A (Windows ACL model differs; tracked) | N/A | Full (`chflags uchg`) | Full (`chattr +i`) |
| Shell startup integration | Full (`Microsoft.PowerShell_profile.ps1` ships) | Full (zsh, bash, fish) | Full (zsh, bash, fish, nu) | Full (zsh, bash, fish, nu) |

## What CI verifies

| Check | Platforms |
|---|---|
| `dot version` exits 0 | windows-latest, ubuntu-latest, macos-latest, macos-14 |
| `dot help` exits 0 | windows-latest, ubuntu-latest, macos-latest, macos-14 |
| `dot agents check` exits 0 | windows-latest (via bash on PATH), ubuntu-latest, macos-latest, macos-14 |
| PowerShell ≥ 7.4 | windows-latest (smoke test at `tools/ci/windows-smoke-test.ps1`) |
| PSScriptAnalyzer Error-level findings | windows-latest |
| `chezmoi --version` exits 0 | windows-latest (via scoop), all Unix matrices |
| `bash tools/ci/dot-cli-startup-bench.sh` median < 200ms | macos-latest |
| `bash tools/ci/dot-cli-startup-bench.sh` median < 150ms | ubuntu-latest |

## Known parity gaps (deferred to follow-up PRs)

These are scoped in [`ROADMAP_2026 §C5`](../operations/ROADMAP_2026.md) but not in this PR's scope:

1. **Native PowerShell `dot.ps1` dispatcher.** Today the Windows path either uses `bash dot` (when bash is on PATH via Git for Windows / WSL) or shells out via `pwsh -Command`. A truly idiomatic PowerShell dispatcher with native cmdlet semantics (verb-noun naming, `[CmdletBinding()]`, pipeline support) is a separate effort.
2. **Wallpaper-driven theming on Windows.** Requires SystemParametersInfo W32 API or `Set-ItemProperty HKCU:\Control Panel\Desktop`. macOS-native today.
3. **`dot security lock-configs` for Windows.** Needs an ACL/EFS-based equivalent of `chattr +i` / `chflags uchg`. Not in this PR's scope; documented here so it doesn't get re-discovered.
4. **Native Windows installer signing.** The repo signs the bootstrap tarball via Cosign keyless; a SignTool-signed `install.ps1` for code-signing-enforced enterprises is a future enhancement.

## Source-of-truth files

- `.github/workflows/ci.yml` — `test-windows` job (pwsh + scoop + chezmoi + smoke)
- `tools/ci/windows-smoke-test.ps1` — the actual gate
- `dot_config/powershell/Microsoft.PowerShell_profile.ps1` — the deployed PowerShell profile (if present)
- `scripts/dot/lib/platform.sh` — the dot_path_to_unix/native bridge (H9 audit fix)

## Why this matters

The 2026 trend brief flagged Windows-as-first-class as the highest-leverage move post-Codex-Windows-GA (launched 2026-03-04 with 500k waitlist → 2M WAU in 4 weeks). PowerShell 7.4 LTS retires 2026-11-10, so the gate sits at "7.4+" today and will tighten to "7.5+" in November. Documented here so the gate change is not a surprise.

Generated 2026-05-16 alongside the round-2 hard audit. Maintained: when adding a `dot` subcommand, update this matrix in the same PR.
