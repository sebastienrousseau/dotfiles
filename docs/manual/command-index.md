---
render_with_liquid: false
---

# Command Index

Generated from `dot help all`. To refresh after adding or renaming
a subcommand, run `tools/docs/generate-command-index.sh`. The CI
job `lint/command-index` fails when this file is stale.

| Command | Summary |
|---------|---------|
| `dot add` | Add a file to chezmoi source |
| `dot agent` | Profile-aware execution, agent card, a2a-card, session log, checkpoints, and conformance |
| `dot agent` | a2a-card Show or validate the A2A v0.3 agent card |
| `dot agent` | card Show the local agent card metadata |
| `dot agent` | checkpoint Manage agent run checkpoints (save/list/show/replay) |
| `dot agent` | conformance Run the A2A conformance test suite |
| `dot agent` | delegate Delegate execution to an allowed sub-agent |
| `dot agent` | log Tail the agent session audit log |
| `dot agents` | check Verify AGENTS.md tracks CLAUDE.md (exit 1 if drifted) |
| `dot agents` | list Show recognised AI agent harnesses and their config paths |
| `dot agents` | render Regenerate AGENTS.md and per-harness config from CLAUDE.md |
| `dot agy` | Antigravity CLI with context patterns |
| `dot ai` | AI fleet cockpit, gateway, and cost |
| `dot ai` | ask Context-aware RAG query over your dotfiles |
| `dot ai` | chat Start an interactive AI session with a chosen tool |
| `dot ai` | cost Report AI spend across every provider from the unified run log |
| `dot ai` | delegate Delegate a coding task to a cheaper AI model under agent policy |
| `dot ai` | doctor Diagnose AI tooling configuration and connectivity |
| `dot ai` | install Install AI CLI tools via mise/native installers |
| `dot ai` | login Interactive setup/authentication for installed AI CLI tools |
| `dot ai` | run Run a one-shot prompt with an AI tool |
| `dot ai` | serve Run the local AI gateway/proxy that routes non-Claude providers |
| `dot ai` | tools Show installed AI CLI tools and their versions |
| `dot ai-query` | Context-aware RAG query over your dotfiles |
| `dot ai-setup` | Interactive setup for all AI CLI tools |
| `dot aider` | Aider with context patterns |
| `dot aliases` | cheatsheet Generate the alias cheatsheet markdown |
| `dot aliases` | list List all shell aliases shipped by the dotfiles |
| `dot aliases` | search Search aliases by term |
| `dot aliases` | stats Show alias usage counts from shell history |
| `dot aliases` | tiers Show which alias tiers/ecosystems are enabled |
| `dot aliases` | why Show details and deprecation status for a single alias |
| `dot attest` | Export workstation attestation evidence (--json |
| `dot backup` | Create a compressed backup of your home |
| `dot bundle` | Create offline archive of dotfiles environment |
| `dot cache-refresh` | Regenerate shell caches for ultra-fast startup |
| `dot cd` | Print source directory path (use: cd $(dot cd)) |
| `dot chaos` | Simulate config corruption to test self-healing |
| `dot cl` | Claude CLI with context patterns |
| `dot commit` | AI-powered conventional commit |
| `dot completion` | Generate shell completions (bash/zsh/fish/nu) from the command registry |
| `dot copilot` | GitHub Copilot CLI with context patterns |
| `dot diff` | Show chezmoi diff with exclusions |
| `dot dns-doh` | Enable DNS-over-HTTPS [macOS,Linux] |
| `dot docs` | Show repo README |
| `dot doctor` | Deep audit: tools, paths, portability, AI analysis (--ai |
| `dot edit` | Open chezmoi source in $EDITOR |
| `dot encrypt-check` | Check disk encryption status |
| `dot env` | Tool versions (mise) |
| `dot env` | emit Emit a portable workstation environment manifest (SBOM; --format json) |
| `dot env` | install Install requested tool versions via mise |
| `dot env` | list List managed tool versions via mise |
| `dot env` | prune Show or remove orphan tool installs (--yes to commit) |
| `dot env` | use Pin a tool version globally/locally via mise |
| `dot firewall` | Apply firewall hardening [macOS,Linux] |
| `dot fleet` | Show fleet node status, drift, and namespace (--json for machine output) |
| `dot fleet` | apply SSH to every host in fleet.toml and run dot sync (or a custom --cmd) |
| `dot fleet` | drift Check for configuration drift across managed files |
| `dot fleet` | enforce Show or set RBAC enforcement mode (advisory/strict) for agent profiles |
| `dot fleet` | events Show recent fleet events from local event log |
| `dot fleet` | namespace Show or set the active namespace for multi-tenant isolation |
| `dot fleet` | status Show this node's fleet status: id, namespace, version, OS, drift, last apply |
| `dot fonts` | Install (default) or patch Nerd Fonts (JetBrainsMono by default) |
| `dot help` | Show this help message |
| `dot history` | Shell history analysis |
| `dot keys` | Keybindings (sign-check: verify git signing) |
| `dot keys` | sign-check Verify git commit-signing configuration and key availability |
| `dot kiro` | Kiro CLI with context patterns |
| `dot learn` | Start the interactive tour of your new tools |
| `dot lint` | Lint shell scripts (--fix |
| `dot load-bench` | Measure time to heavy-layer readiness |
| `dot lock-screen` | Enforce lock screen idle settings [Linux] |
| `dot mcp` | Inspect MCP policy, supply chain, and registry |
| `dot mcp` | doctor Run the MCP policy/supply-chain/config audit |
| `dot mcp` | registry Show the configured MCP server registry |
| `dot metrics` | Show recent observability metrics (JSONL) |
| `dot mode` | Set or inspect agent operating profiles (ask/plan/apply/audit) |
| `dot mode` | current Show the active agent profile and its policy |
| `dot mode` | doctor Validate the agent-profiles.json config and default profile |
| `dot mode` | list List available agent operating profiles (ask/plan/apply/audit) |
| `dot mode` | run Run a command under a given agent profile with a checkpoint |
| `dot mode` | set Switch the active agent profile |
| `dot mode` | show Show details of a specific agent profile |
| `dot new` | Create a new project from a template |
| `dot ollama` | Ollama with context patterns |
| `dot opencode` | OpenCode with context patterns |
| `dot packages` | List installed packages and package managers |
| `dot patterns` | edit Edit an AI steering pattern in $EDITOR |
| `dot patterns` | list List AI steering patterns |
| `dot patterns` | view View an AI steering pattern |
| `dot perf` | Show performance mode and quick timing |
| `dot policy` | Check and enforce security policies across the environment |
| `dot profile` | Show/switch configuration profile |
| `dot profile` | set Set the active configuration profile (run dot sync to apply) |
| `dot profile` | show Show the active configuration profile and feature flags |
| `dot registry` | info Print full metadata for a registry module |
| `dot registry` | install Install a registry module (scaffold) |
| `dot registry` | list List modules in the configured module registry |
| `dot registry` | search Filter registry modules by keyword |
| `dot registry` | set-url Override the registry URL (https only; persists) |
| `dot registry` | url Show the active registry URL |
| `dot rollback` | Rollback dotfiles to a previous state |
| `dot sandbox` | Launch a safe sandbox preview (Docker/Podman) |
| `dot score` | System health and security scorecard |
| `dot search` | Find commands by keyword |
| `dot secret-audit` | Audit secret hygiene and leakage surface |
| `dot secrets` | Edit encrypted secrets (age) |
| `dot secrets` | edit Edit the encrypted secrets file (age) |
| `dot secrets` | get Retrieve a secret value (--raw for plaintext) |
| `dot secrets` | list List indexed secret keys |
| `dot secrets` | load Emit export lines for a secrets bucket (use with eval) |
| `dot secrets` | provider Show the active secrets provider |
| `dot secrets` | set Store a secret value under a key |
| `dot secrets-create` | Create an encrypted secrets file |
| `dot secrets-init` | Initialize age key for secrets |
| `dot sgpt` | Shell-GPT with context patterns |
| `dot snapshot` | Capture baseline system snapshot |
| `dot ssh-cert` | Manage short-lived SSH certificates |
| `dot ssh-key` | Encrypt an SSH key locally with age |
| `dot status` | Show configuration drift (chezmoi status) |
| `dot sync` | Apply dotfiles (alias for apply; --pull to fetch, --check to preview) |
| `dot telemetry` | Disable OS telemetry [macOS,Linux] |
| `dot teleport` | Deploy the dotfiles environment to a remote host over SSH |
| `dot theme` | Switch terminal theme (dark/light) |
| `dot theme` | current Show the current theme info |
| `dot theme` | family Cycle between theme families |
| `dot theme` | list Show all available terminal/wallpaper themes |
| `dot theme` | rebuild Regenerate themes from system and custom wallpapers |
| `dot theme` | set Set a theme by name (interactive picker if omitted) |
| `dot theme` | sync Sync the dotfiles theme with system dark/light mode |
| `dot theme` | toggle Toggle light/dark within the current theme family |
| `dot tools` | Show or install nix packages |
| `dot tools` | docs Show the full tools markdown documentation |
| `dot tools` | install Enter the Nix development shell with all managed tools |
| `dot tune` | Apply OS tuning (opt-in) [macOS,Linux] |
| `dot uninstall` | Remove the managed dotfiles environment (prompts unless --force) |
| `dot upgrade` | Update system toolchains, plugins, and dotfiles |
| `dot usb-safety` | Disable automount for removable media [Linux] |
| `dot version` | Show version information. |
| `dot wallpaper` | Apply a wallpaper from your library [macOS,Linux] |
| `dot wallpaper` | rotate Rotate to the next wallpaper in your library |
| `dot wallpaper` | sync Sync wallpaper from your library |
