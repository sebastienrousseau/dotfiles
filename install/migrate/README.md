# Migration

The framework upgrades itself **automatically and seamlessly** when
you pull a new release. You should never need to read this directory
unless something goes wrong.

## How it works

When you upgrade to v0.2.503 (the first release with the v0.2.503
repository reorganisation per
`docs/operations/RFC_v0_2_503_reorganization.md`), three independent
triggers attempt to run the migration:

1. **`install.sh` upgrade path.** If you re-run `install.sh` (the
   standard upgrade flow), it detects pre-0.2.503 state and runs
   `migrate-v0_2-to-v0_2_503.sh` BEFORE invoking `chezmoi apply`.
2. **`chezmoi apply` hook.** `install/provision/run_before_00-migrate-v0_2_503.sh.tmpl`
   is a chezmoi `run_before_*` script that fires on every apply. It
   invokes the same migration script, which is idempotent.
3. **Manual invocation.** If you want explicit control:

   ```sh
   bash install/migrate/migrate-v0_2-to-v0_2_503.sh --verbose
   ```

All three paths converge on the same script. The script's first
action is checking the state file
`~/.local/state/dotfiles/v0_2_503-migration/.complete`. If that
file exists, the script exits 0 immediately — exactly-once
semantics.

## What the migration does

`v0.2.503` moves chezmoi-managed source paths:

| Phase | From | To |
|---|---|---|
| 2 | `dot_local/bin/executable_dot` | `bin/dot` |
| 3 | `dot_local/share/man/man1/dot.1` | `share/man/man1/dot.1` |
| 3 | `dot_local/share/zsh/completions/_dot` | `share/completions/zsh/_dot` |
| 4 | `dot_*`, `dot_config/`, etc. | `defaults/...` (via `.chezmoiroot`) |

Without intervention, chezmoi would see the old paths as "deleted
from source" and REMOVE the deployed files at `~/.local/bin/dot`,
`~/.local/share/man/...`, etc. BEFORE deploying the new ones — a
brief but real window where the user's environment is broken.

The migration:

1. Detects which phases are active in the new source (looks for the
   target files like `bin/dot`).
2. Calls `chezmoi forget --force` on the corresponding deployed
   paths. This un-tracks them from chezmoi state without deleting
   the file on disk.
3. `chezmoi apply` then proceeds normally. The new paths populate;
   the old (now-untracked) deployed files remain on disk until you
   explicitly remove them (or until the next major bump cleans up
   the post-migration leftovers).
4. Marks `~/.local/state/dotfiles/v0_2_503-migration/.complete` so
   the script becomes a no-op on every subsequent apply.

## Rollback

If `dot doctor` reports issues you can't immediately fix:

```sh
bash install/migrate/rollback-v0_2_503.sh
```

This reads the snapshot in
`~/.local/state/dotfiles/v0_2_503-migration/` and restores the
pre-migration source version + re-applies it.

## What if the migration script isn't present?

You're upgrading from a release older than v0.2.503 to a release
≥ v0.2.503 where the script wasn't yet bundled. Two recovery paths:

1. Manually fetch + run the script:

   ```sh
   curl -fsSL \
     https://raw.githubusercontent.com/sebastienrousseau/dotfiles/v0.2.503/install/migrate/migrate-v0_2-to-v0_2_503.sh \
     | bash
   ```

2. Or just re-run `install.sh` from the new source — it picks up
   the script automatically.

## See also

- `docs/operations/RFC_v0_2_503_reorganization.md` — the full RFC.
- `migrate-v0_2-to-v0_2_503.sh` — the migration script source.
- `install/provision/run_before_00-migrate-v0_2_503.sh.tmpl` — the chezmoi-apply hook.
- `install.sh` — the upgrade-path detection.
