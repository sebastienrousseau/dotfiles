# Localization Readability Audit

Note: Flesch metrics are English-centric. For localized pages, they are used as a plain-language proxy when Latin word boundaries are available.

## Readability Scorecard

| Language | Reading Ease | Grade Level | Passive % | Avg Sentence Length |
| :--- | ---: | ---: | ---: | ---: |
| ar | n/a | n/a | n/a | n/a |
| de | n/a | n/a | n/a | n/a |
| es | n/a | n/a | n/a | n/a |
| fr | n/a | n/a | n/a | n/a |
| he | n/a | n/a | n/a | n/a |
| hi | n/a | n/a | n/a | n/a |
| id | n/a | n/a | n/a | n/a |
| it | n/a | n/a | n/a | n/a |
| ja | n/a | n/a | n/a | n/a |
| ko | n/a | n/a | n/a | n/a |
| nl | n/a | n/a | n/a | n/a |
| pl | n/a | n/a | n/a | n/a |
| pt | n/a | n/a | n/a | n/a |
| ro | n/a | n/a | n/a | n/a |
| ru | n/a | n/a | n/a | n/a |
| th | n/a | n/a | n/a | n/a |
| tr | n/a | n/a | n/a | n/a |
| uk | n/a | n/a | n/a | n/a |
| vi | n/a | n/a | n/a | n/a |
| zh | n/a | n/a | n/a | n/a |
| zh-tw | n/a | n/a | n/a | n/a |

## Parity Gap Table

| Priority | Locale | Route | Deviation |
| :--- | :--- | :--- | :--- |

## Active & Simple Diff

### docs/adr/ADR-007-multi-shell-parity.md

- Source: **Nushell spoke:** Hybrid approach: - Aliases: Runtime bash extraction cached to (in ), sourced by - Functions: Chezmoi template-generated wrappers delegating to bash (in ) **Parity tiers:** - **Tier 1 (Full):** Zsh, Bash — all aliases, functions, lazy loading, cached eval - **Tier 2 (Bridged):** Fish — all simple aliases, all functions via wrappers, caching - **Tier 3 (Compatible):** Nushell — simple aliases (no complex bash syntax), all functions via bash delegation - Single source of truth for aliases and functions - Adding a new alias/function automatically propagates to all shells - Nushell users get access to 40+ functions that were previously unavailable - Fish users get mtime-aware caching via - Complex bash aliases (pipes, conditionals) are skipped for Nushell - Function calls in Fish/Nushell incur bash subprocess overhead (~5ms per call) - Cache invalidation requires shell restart or manual cache clear - Nushell's rapid development may break bridge syntax in future versions - Very large alias sets may slow Nushell startup during cache generation.
- Simplified: **Nushell spoke:** Hybrid approach: - Aliases: Runtime bash extraction cached to (in ), sourced by - Functions: Chezmoi template-generated wrappers delegating to bash (in ) **Parity tiers:** - **Tier 1 (Full):** Zsh, Bash — all aliases, functions, lazy loading, cached eval - **Tier 2 (Bridged):** Fish — all simple aliases, all functions via wrappers, caching - **Tier 3 (Compatible):** Nushell — simple aliases (no complex bash syntax), all functions via bash delegation - Single source of truth for aliases and functions -. Adding a new alias/function automatically propagates to all shells - Nushell users get access to 40+ functions that were previously unavailable - Fish users get mtime-aware caching via - Complex bash aliases (pipes, conditionals) are skipped for Nushell - Function calls in Fish/Nushell incur bash subprocess overhead (~5ms per call) - Cache invalidation requires shell restart or manual cache clear - Nushell's rapid development may break bridge syntax in future versions - Very large alias sets may slow Nushell startup during cache generation

### docs/guides/TROUBLESHOOTING.md

- Source: ) **Problem:** LSP not working - Install required language servers - Check for status - Review for errors **Problem:** Git aliases not working - Check if Git config is applied: - Re-apply dotfiles: **Problem:** Delta (diff pager) not showing colors - Verify is installed - Confirm your terminal supports 256 colors **Problem:** kubectl context issues - List contexts: - Switch context: - Check kubeconfig: **Problem:** Minikube won't start - Verify Docker is running - Try: - Check logs: **Problem:** High memory usage - Look for runaway processes: or - Review shell history size in atuin config - Disable unused plugins **Problem:** Nix isn't installed or commands not found - Ensure you have followed the installation guide: - On Linux, you might need to enable experimental features in : - Verify the daemon is running: **Problem:** Systemd isn't available (mostly WSL2) - Dotfiles functions that rely on systemd (like management) will fallback to direct execution.
- Simplified: ) **Problem:** LSP not working - Install required language servers - Check for status - Review for errors **Problem:** Git aliases not working - Check if Git config is applied: - Re-apply dotfiles: **Problem:** Delta (diff pager) not showing colors - Verify is installed - Confirm your terminal supports 256 colors **Problem:** kubectl context issues - List contexts: - Switch context: - Check kubeconfig: **Problem:** Minikube won't start - Verify Docker is running - Try: - Check. logs: **Problem:** High memory usage - Look for runaway processes: or - Review shell history size in atuin config - Disable unused plugins **Problem:** Nix isn't installed or commands not found - Ensure you have followed the installation guide: - On Linux, you might need to enable experimental features in : - Verify the daemon is running: **Problem:** Systemd isn't available (mostly WSL2) - Dotfiles functions that rely on systemd (like management) will fallback to direct execution

### docs/operations/VERSION_SYNC.md

- Source: sh --verify || echo "Version drift detected" The GitHub Actions workflow provides metrics: - Files scanned - Files updated - Verification status - Processing time - Local backups in - GitHub Actions artifacts (30-day retention) - Git history for rollback permissions: contents: write # Required for commits pull-requests: write # Required for PR comments - Version format validation ( pattern) - File path validation (no directory traversal) - Change verification before commit - All changes logged in Git history - GitHub Actions run history - Backup preservation - Git operations use shallow fetch when possible - Pattern compilation cached - File discovery optimized with - File processing is sequential but optimized - Git operations batched - Verification runs concurrently with updates - Typical run time: 30-60 seconds - Memory usage: <100MB - Network usage: Minimal (only Git operations) 1.
- Simplified: sh --verify || echo "Version drift detected" The GitHub Actions workflow provides metrics: - Files scanned - Files updated - Verification status - Processing time - Local backups in - GitHub Actions artifacts (30-day retention) - Git history for rollback permissions: contents: write # Required for commits pull-requests: write # Required for PR comments - Version format validation ( pattern) - File path validation (no directory traversal) - Change. verification before commit - All changes logged in Git history - GitHub Actions run history - Backup preservation - Git operations use shallow fetch when possible - Pattern compilation cached - File discovery optimized with - File processing is sequential but optimized - Git operations batched - Verification runs concurrently with updates - Typical run time: 30-60 seconds - Memory usage: <100MB - Network usage: Minimal (only Git operations) 1

## Localized Terminology Glossary

| Term | Rule |
| :--- | :--- |
| macOS | Keep official Apple spelling in all locales. |
| Linux | Keep as Linux. |
| WSL | Keep as WSL on first use. |
| Chezmoi | Keep product name in English. |
| `dot doctor` | Keep command unchanged in all locales. |
| shell | Localize only in prose; never inside commands or paths. |
| alias | Localize in prose when natural; keep code examples unchanged. |

## Priority Action Register

- [P0] Meaning Drifts: 0
- [P1] Readability Blockers: 0
- [P2] Stylistic Polishing: 0
