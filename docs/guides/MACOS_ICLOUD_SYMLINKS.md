---
render_with_liquid: false
---

# macOS iCloud Drive Symlinks

On macOS, this dotfiles setup can (safely) symlink personal directories into iCloud Drive so `~/Desktop`, `~/Documents`, `~/Downloads`, `~/Movies`, `~/Music`, `~/Pictures`, and `~/Public` all live in iCloud and back up automatically.

The mechanism is `defaults/run_once_before_macos-icloud-symlinks.sh.tmpl`, which chezmoi runs once (before `apply`) whenever its contents change.

## Safety guarantees

This script is the **replacement** for a previous `symlink_*.tmpl` set that had a data-loss bug (see #1018): chezmoi's built-in symlink handling does `rm -rf $target; ln -s $source $target`, which destroys real content if the target directory has data.

The current script's contract is:

| Situation | What the script does |
|---|---|
| `~/$name` is already the correct symlink to iCloud | no-op |
| `~/$name` is a symlink pointing somewhere else | **skip, log** — never overwrite your own link |
| `~/$name` is a directory with any content (including `.DS_Store`) | **skip, log** — never delete your data |
| `~/$name` is an empty directory | `rmdir` (fails safely if non-empty due to a race) + create symlink |
| `~/$name` is a regular file | **skip, log** — never touch |
| `~/$name` does not exist | create symlink directly |
| iCloud source `com~apple~CloudDocs/$name` does not exist | **skip, log** — iCloud may still be syncing |
| iCloud Drive is not set up on the Mac | **skip everything, log** — no partial state |

The script has **two kill-switches**:

- `touch ~/.dotfiles.icloud-skip` — permanent per-machine opt-out
- `DOTFILES_ICLOUD_SYMLINKS=0` — env var, one run only

And a **dry-run mode**:

- `DOTFILES_ICLOUD_DRY_RUN=1` — log every decision, take no action

## Rescue: how to link a directory that has content

If your `~/Documents` already has content and you want it in iCloud:

```bash
# 1. Move your data into iCloud MANUALLY
mv ~/Documents/* ~/Documents/.* "~/Library/Mobile Documents/com~apple~CloudDocs/Documents/" 2>/dev/null

# 2. Verify iCloud has everything
ls -la "~/Library/Mobile Documents/com~apple~CloudDocs/Documents/"

# 3. Now the dir is empty — chezmoi's next apply will do the rmdir + symlink
rmdir ~/Documents          # sanity check: this succeeds only if truly empty
chezmoi apply
```

## Log

Every run appends to `$XDG_STATE_HOME/dotfiles/icloud-symlinks.log` (default: `~/.local/state/dotfiles/icloud-symlinks.log`). Grep for `SKIP` to see why a candidate wasn't linked, or `LINK` to see what was created.

## Belt-and-braces protection

The same directory names are listed in `defaults/.chezmoiignore.tmpl`'s Darwin block, so even if the script never ran, chezmoi's regular `apply` would still refuse to touch these paths on macOS. Two independent layers of protection.

## Tests

`tests/unit/misc/test_macos_icloud_symlinks.sh` runs 16 assertions covering every branch of the refusal matrix. If any of them regress, CI blocks the merge.

## Manual override: disable entirely

If you never want the automation:

```bash
touch ~/.dotfiles.icloud-skip
```

The script sees this file in the first 5 lines of execution and exits 0 immediately, without touching the filesystem.
