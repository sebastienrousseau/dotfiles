# `defaults/` — Maintainer's User-Facing Default Configuration

This directory will hold every chezmoi-tracked file currently at the
repo root (`dot_*`, `dot_config/`, `private_dot_ssh/`, `dot_cargo/`,
`dot_warp/`, `dot_etc/`, `dot_claude/`, and the leftover parts of
`dot_local/` not promoted to `bin/` or `share/`). The move
**activates** when:

1. The `.chezmoiroot.example` file at the repo root is renamed to
   `.chezmoiroot` (the actual chezmoi config file).
2. Every dotfile listed above is moved into `defaults/` (preserving
   the chezmoi naming contract: `dot_*` → `~/.X`, `executable_*` → `+x`,
   `private_*` → `0600`, `run_onchange_*` re-fires on hash drift).
3. Users pull v0.2.503 — the auto-migration script
   (`install/migrate/migrate-v0_2-to-v0_2_503.sh`, fired by both
   `install.sh` and the `run_before_*` chezmoi hook) calls
   `chezmoi forget` on the previously-deployed paths BEFORE the
   first apply. The wrappers shipped in Phases 2 + 3 keep
   `~/.local/bin/dot` + `~/.local/share/man/man1/dot.1` working
   transparently.

## Status

Phase 4 ships in **two slices**:

| Slice | What | Status |
|---|---|---|
| **4a (this commit)** | `defaults/` directory + `.chezmoiroot.example` + this doc + migration-script Phase 4 detection (already wired). Establishes the contract; the mechanism is provably correct in isolation. | ✅ Shipped |
| **4b (follow-up commit in this PR)** | The actual subtree sweep — `git mv` every chezmoi-tracked path at root into `defaults/`. Rename `.chezmoiroot.example` → `.chezmoiroot`. Requires per-platform `chezmoi apply --dry-run` smoke (macOS + Linux + WSL + windows-latest). | 🚧 In progress |

## Why split

A move of this size touches every existing user's chezmoi
source-state. Splitting the SCAFFOLD (this commit) from the SWEEP
(4b) means:

- Reviewers can audit the migration-script Phase 4 guards
  in isolation.
- The smoke matrix (Phase 4b) tests can run against a stable
  scaffold without the noise of 100+ rename commits.
- If Phase 4b reveals a chezmoi quirk (e.g., `.chezmoiroot`
  interaction with the existing `.chezmoiignore` rules), 4a stays
  shipped and we iterate on 4b in isolation.

## Reference layout (end-state)

```
defaults/
├── home/                    # dot_* files at root deploy to ~/.X
│   ├── dot_bashrc
│   ├── dot_zshrc
│   ├── dot_zshenv
│   ├── dot_zprofile
│   ├── dot_profile
│   ├── dot_vimrc
│   ├── dot_gitconfig.tmpl
│   └── ...
├── config/                  # dot_config/ subtree (XDG)
│   ├── dot_starship/
│   ├── dot_nvim/
│   └── ...
├── cargo/                   # dot_cargo/
├── claude/                  # dot_claude/
├── etc/                     # dot_etc/
├── local/                   # dot_local/ leftover (state/, etc.)
├── warp/                    # dot_warp/
└── ssh/                     # private_dot_ssh/  (0600 enforced)
```

Per the [RFC](../docs/operations/RFC_v0_2_503_reorganization.md),
the chezmoi naming contract is preserved inside `defaults/` — the
move is purely a relocation, not a redesign of how chezmoi reads
the source.

## See also

- `../.chezmoiroot.example` — the future config (rename to activate).
- `../docs/operations/RFC_v0_2_503_reorganization.md` — full reorg plan.
- `../install/migrate/migrate-v0_2-to-v0_2_503.sh` — automatic migration tool.
- `../install/migrate/README.md` — user-facing migration doc.
