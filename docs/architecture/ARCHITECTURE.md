# Architecture

Core architectural decisions and system design of the dotfiles shell distribution.

---

## Philosophy

- **XDG-First**: Configuration lives under `~/.config/` to keep the home directory clean.
- **Multi-Shell**: First-class support for Zsh, Fish, and Nushell with a shared logic core.
- **Fast Startup**: Heavy features are deferred or autoloaded to keep the first prompt under 50ms.
- **Deterministic**: Nix Flakes provide bit-for-bit identical environments across machines.
- **Non-Blocking**: Background daemons (Pueue) handle upgrades and builds without stalling the shell.

## System Layout

```text
~/.dotfiles/
├── dot_config/          # Managed application configurations (~/.config/)
│   ├── zsh/             # Modular Zsh rc.d architecture
│   ├── fish/            # Autoloading Fish configuration
│   ├── nushell/         # Structured data shell config
│   ├── shell/           # Shared logic (aliases, paths, functions)
│   └── ...              # 50+ tool configurations (nvim, tmux, ghostty, etc.)
├── dot_local/           # Local binaries and scripts (~/.local/bin/)
├── .chezmoitemplates/   # Unified source for aliases, functions, and paths
├── scripts/             # Internal libraries and diagnostics
├── nix/                 # Nix Flake for deterministic toolchains
├── lib/wasm-tools/      # Rust source for Wasm utilities
└── install.sh           # Universal bootstrap script (zero dependencies)
```

---

## Shell Startup Strategies

### Shared: `_cached_eval`

Across Zsh, Fish, and Bash, an idempotent caching wrapper avoids redundant tool initialization (Starship, Zoxide, Atuin).

1. **Intercept** — check if a cached version of the tool's `eval` output exists in `~/.cache/shell/`.
2. **Validate** — compare the cache timestamp against the tool binary's mtime.
3. **Bypass** — if valid, `source` the cached text directly, saving 20-50ms per tool.

### Lazy-Hydration Model

To reach a fluid first-prompt target (< 50ms), the shell uses a three-phase startup:

1. **Phase 1 (Visual Paint)** — render the prompt immediately using static escape codes.
2. **Phase 2 (Async Hydration)** — dispatch tool initializations (mise, atuin, etc.) to background workers.
3. **Phase 3 (On-Demand Activation)** — environment hydration occurs on first user interaction or after 500ms of idle time.

---

## Artifact Mode

A minimal environment triggered by `DOTFILES_ARTIFACT_MODE=1`.

- **Minimalist UI** — strips prompt complexity, leaving only a green `->`.
- **Intelligence Surface** — an async Bento-style dashboard rendered via `bento.sh` that provides environment context (Node version, cloud status, Git health) without blocking the main thread.
- **Redraw Signaling** — uses `SIGWINCH` to return control after background hydration completes.

---

## Ultra-Fast Mode

Set `DOTFILES_ULTRA_FAST=1` to skip all non-essential initialization. Only core paths, aliases, and the prompt are loaded. Useful for:

- CI/CD pipelines where full shell setup is unnecessary
- Rapid scripting sessions where startup latency matters
- Benchmarking baseline shell performance

---

## Debug and Trace Modes

### DOTFILES_DEBUG=1

Enables verbose diagnostic output during shell startup. Prints which files are sourced and their load times.

### DOTFILES_TRACE=1

Enables `set -x` tracing for the entire shell startup sequence. Output is written to `~/.local/state/dotfiles/debug.log` for post-mortem analysis.

---

## Function Groups (groups.json)

Functions are organized into groups defined in `.chezmoitemplates/functions/groups.json`:

| Group | Functions | Description |
|-------|-----------|-------------|
| `api` | apihealth, apilatency, apiload | API testing utilities |
| `curl` | curlheader, curlstatus, curltime, httpdebug | HTTP debugging |
| `text` | encode64, kebabcase, lowercase, titlecase, ... | Text transformation |
| `system` | environment, freespace, hostinfo, myproc, sysinfo | System introspection |
| `files` | backup, extract, hexdump, hiddenfiles, size, zipf | File operations |
| `interactive` | banner, emoji, matrix, rainbow, stopwatch | Terminal fun |
| `nav` | cdls, goto, ql | Navigation shortcuts |
| `security` | genpass, keygen, mount_read_only | Security utilities |
| `misc` | dothelp, view-source, prependpath, caffeine | Miscellaneous |

Groups are lazy-loaded: stub functions are defined at startup, and the real implementation is loaded on first invocation. This keeps startup fast while providing 52+ functions on demand.

The `groups.json` schema maps group names to arrays of relative paths (including subdirectory):

```json
{
  "group_name": ["group_name/function1.sh", "group_name/function2.sh"]
}
```

Each `.sh` file lives in a subdirectory matching its group and defines a single function with the same name as the file (minus `.sh` extension).
