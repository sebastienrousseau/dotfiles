# Migration

This directory holds the one-time migration for the v0.2.503
repository reorganisation. You should never need to read it unless
something goes wrong.

## How it works

When you upgrade to v0.2.503 or later (the v0.2.503 repository
reorganisation per
`docs/operations/RFC_v0_2_503_reorganization.md`), two paths run the
migration:

1. **`install.sh` upgrade path.** If you re-run `install.sh` (the
   standard upgrade flow), it runs `migrate-v0_2-to-v0_2_503.sh`
   from `~/.dotfiles` or `~/.local/share/chezmoi`, whichever has it
   and is executable, BEFORE invoking `chezmoi apply`. It does no
   version detection of its own; the script decides whether there is
   work to do, and a non-zero exit only prints a warning.
2. **Manual invocation.** If you want explicit control:

   ```sh
   bash install/migrate/migrate-v0_2-to-v0_2_503.sh --verbose
   bash install/migrate/migrate-v0_2-to-v0_2_503.sh --dry-run
   ```

`install/provision/run_before_00-migrate-v0_2_503.sh.tmpl` was meant
as a third trigger on every `chezmoi apply`, but it never runs:
`install/provision/` sits outside `.chezmoiroot` (`defaults`), so
chezmoi does not see it, and `install.sh --provision` only runs the
`run_once_install_*` and `run_onchange_*` scripts there.

Both paths converge on the same script. The script's first
action is checking the state file
`~/.local/state/dotfiles/v0_2_503-migration/.complete`. If that
file exists, the script exits 0 immediately (pass `--force` to run
it again).

## What the migration does

`v0.2.503` moves chezmoi-managed source paths:

| Phase | From | To |
|---|---|---|
| 2 | `dot_local/bin/executable_dot` (old chezmoi-tracked path) | `bin/dot` (canonical) + thin chezmoi wrapper that execs it |
| 3 | `dot_local/share/man/man1/dot.1` | `share/man/man1/dot.1` |
| 3 | `dot_local/share/zsh/completions/_dot` | `share/completions/zsh/_dot` |
| 4 | `dot_*`, `dot_config/`, etc. | `defaults/...` (via `.chezmoiroot`) |

Without intervention, chezmoi would see the old paths as "deleted
from source" and REMOVE the deployed files at `~/.local/bin/dot`,
`~/.local/share/man/...`, etc. BEFORE deploying the new ones — a
brief but real window where the user's environment is broken.

The migration:

1. Marks itself complete and exits if chezmoi is missing, has no
   source configured, or neither `~/.local/bin/dot` nor
   `~/.local/share/man/man1/dot.1` exists (a fresh install).
2. Writes a snapshot log, `snapshot-<UTC timestamp>.log`, next to the
   state file.
3. Detects which phases are active by looking for their target files
   (`bin/dot`, `share/man/man1/dot.1`, `.chezmoiroot`) under
   `chezmoi source-path`.
4. Calls `chezmoi forget --force` on the corresponding deployed
   paths. This un-tracks them from chezmoi state without deleting
   the file on disk. `chezmoi apply` then proceeds normally; the old
   (now-untracked) deployed files remain on disk until you remove
   them.
5. Writes the `.complete` state file (except under `--dry-run`).

Note that once `.chezmoiroot` is in effect, `chezmoi source-path`
prints `~/.dotfiles/defaults`, not the repo root, so the phase checks
in step 3 do not find their target files and the script forgets
nothing.

## Rollback

`rollback-v0_2_503.sh` does not work today. It looks for a
`current ver:` line in the newest snapshot, but the migration writes
only `target ver:`, so it stops with "snapshot missing 'current ver:'
line". It also expects `chezmoi source-path` to be the git checkout,
which with `.chezmoiroot` it is not.

To go back to a pre-0.2.503 release by hand:

```sh
cd ~/.dotfiles
git fetch --tags origin
git checkout v0.2.502
chezmoi apply
```

## What if the migration script isn't present?

Your checkout predates v0.2.503, so it has no
`install/migrate/` directory. Two recovery paths:

1. Manually fetch + run the script:

   ```sh
   curl -fsSL \
     https://raw.githubusercontent.com/sebastienrousseau/dotfiles/v0.2.504/install/migrate/migrate-v0_2-to-v0_2_503.sh \
     | bash
   ```

2. Or update the checkout first (`git -C ~/.dotfiles pull`), then
   re-run `install.sh`, which picks up the script automatically.

## See also

- `docs/operations/RFC_v0_2_503_reorganization.md` — the full RFC.
- `migrate-v0_2-to-v0_2_503.sh` — the migration script source.
- `install.sh`: the upgrade path that runs it.
