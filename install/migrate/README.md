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

The RFC expected chezmoi to treat the old paths as "deleted from
source" and remove the deployed files at `~/.local/bin/dot`,
`~/.local/share/man/...`, etc. It does not: chezmoi leaves a deployed
file in place when its source entry disappears (unless
`.chezmoiremove` or an `exact_` directory says otherwise).

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
   paths. This deletes their entries from the chezmoi source state
   without deleting the deployed file. `chezmoi apply` then proceeds normally; the old
   (now-untracked) deployed files remain on disk until you remove
   them.
5. Writes the `.complete` state file (except under `--dry-run`).

Once `.chezmoiroot` is in effect, `chezmoi source-path` prints
`~/.dotfiles/defaults`, not the repo root, so the phase checks in
step 3 do not find their target files and the script forgets nothing.
That is now the intended behaviour: `~/.local/bin/dot` is managed
again (by `defaults/dot_local/bin/executable_dot.tmpl`), and
`chezmoi forget` deletes the source entry of the path it forgets, so
a Phase 2 that fired would remove that file from your checkout.
Since chezmoi leaves deployed files in place anyway (see above),
nothing is lost.

## Rollback

`rollback-v0_2_503.sh` is retired. It never worked (it read a
`current ver:` snapshot line the migration never writes, and expected
`chezmoi source-path` to be the git checkout), so it now changes
nothing, prints the steps below and exits 1.

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
