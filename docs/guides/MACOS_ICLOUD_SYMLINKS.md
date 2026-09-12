---
render_with_liquid: false
---

# macOS iCloud Drive Symlinks

On macOS, this dotfiles setup can (safely) symlink personal directories into iCloud Drive so `~/Desktop`, `~/Documents`, `~/Downloads`, `~/Movies`, `~/Music`, `~/Pictures`, and `~/Public` all live in iCloud and back up automatically.

The mechanism is `defaults/run_before_macos-icloud-symlinks.sh.tmpl`, which chezmoi runs before **every** `apply` — not once, and not only when the script changes. That is deliberate: a run-once script gets a single attempt, and on a fresh Mac that attempt lands while iCloud Drive is still syncing the folder tree down, so every candidate would skip and the one chance would be spent. Running each time lets it link whatever has become safe to link since the last apply. Repeat runs are no-ops that cost a few milliseconds.

## `~/Desktop` and `~/Documents` are a special case

macOS has its own **"Desktop & Documents Folders"** iCloud feature (System Settings -> Apple Account -> iCloud -> iCloud Drive -> Options). When it is on, macOS itself syncs those two folders, and it marks them in the iCloud container by putting symlinks there pointing *back* at your home directory:

```text
com~apple~CloudDocs/Desktop    -> ~/Desktop
com~apple~CloudDocs/Documents  -> ~/Documents
```

Check whether it is on:

```bash
defaults read com.apple.finder FXICloudDriveDesktop    # 1 = Desktop sync on
defaults read com.apple.finder FXICloudDriveDocuments  # 1 = Documents sync on
```

**If those return `1`, `~/Desktop` and `~/Documents` are already fully synced to iCloud and across your devices — by macOS, not by this script.** They will show as `SKIP ... iCloud source is itself a symlink` in the log. That is the correct outcome, not a failure.

Do **not** apply the manual migration recipe below to `~/Desktop` or `~/Documents` while native sync is on: you would be moving data into a symlink that points back at its own source, fighting a feature macOS is already managing. Turn native sync off first if you genuinely want the symlink approach — but for these two folders the native feature is the better mechanism, since Finder, Migration Assistant, and iOS all understand it.

The symlink approach in this guide is for the folders macOS does *not* cover natively: `~/Downloads`, `~/Movies`, `~/Music`, `~/Pictures`, `~/Public`.

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
| iCloud source `com~apple~CloudDocs/$name` is itself a symlink | **skip, log** — macOS's native Desktop & Documents sync owns it (see below) |

The script has **two kill-switches**:

- `touch ~/.dotfiles.icloud-skip` — permanent per-machine opt-out
- `DOTFILES_ICLOUD_SYMLINKS=0` — env var, one run only

And a **dry-run mode**:

- `DOTFILES_ICLOUD_DRY_RUN=1` — log every decision, take no action

## Rescue: how to link a directory that has content

If one of the non-native folders (`~/Downloads`, `~/Movies`, `~/Music`, `~/Pictures`, `~/Public`) already has content and you want it in iCloud — the example uses `Documents`, which applies only if you have turned native Desktop & Documents sync **off**:

```bash
# 1. Move your data into iCloud MANUALLY
mv ~/Documents/* ~/Documents/.* "~/Library/Mobile Documents/com~apple~CloudDocs/Documents/" 2>/dev/null

# 2. Verify iCloud has everything
ls -la "~/Library/Mobile Documents/com~apple~CloudDocs/Documents/"

# 3. Now the dir is empty — chezmoi's next apply will do the rmdir + symlink
rmdir ~/Documents          # sanity check: this succeeds only if truly empty
chezmoi apply
```

## After the links exist: what changes

Linking a folder into iCloud does exactly what it says, and that has consequences worth understanding *before* you migrate rather than after.

**Storage.** Everything saved to a linked folder counts against your iCloud quota, not just local disk. `~/Downloads` is the one that catches people out.

**Deletion.** Deleting a file from a linked folder deletes it from iCloud, and therefore from every device signed into that account. There is no local-only copy any more. This is inherent to symlinking and is not something the hook can guard.

**Eviction.** macOS may evict a synced file's contents to reclaim disk space, leaving a placeholder behind. Reading it downloads it again — so a script that walks one of these folders can block on the network where it used to return instantly.

**Two things in this repository write into these folders.** Neither runs during `chezmoi apply`; both are commands you invoke deliberately:

| What | Where | Why it matters after linking |
|---|---|---|
| `scripts/theme/merge-wallpaper.sh` | `~/Pictures/Wallpapers` (override with `DOTFILES_WALLPAPER_DIR`) | Merges a light/dark pair into one `.heic` and then **deletes both source files**. After linking, that pair is consumed from iCloud. Point `DOTFILES_WALLPAPER_DIR` at a local directory to keep the library off iCloud. |
| `defaults/dot_config/mpv/mpv.conf` | `~/Pictures/Screenshots` | `screenshot-directory` is set here, so mpv screenshots land in iCloud. |

Nothing else in this repository writes into the seven folders, and chezmoi itself never touches them: they are listed in the Darwin block of `.chezmoiignore.tmpl`, and `chezmoi managed` reports none of them among the paths it controls.

## Log

Every run appends to `$XDG_STATE_HOME/dotfiles/icloud-symlinks.log` (default: `~/.local/state/dotfiles/icloud-symlinks.log`). Grep for `SKIP` to see why a candidate wasn't linked, or `LINK` to see what was created.

## Belt-and-braces protection

The same directory names are listed in `defaults/.chezmoiignore.tmpl`'s Darwin block, so even if the script never ran, chezmoi's regular `apply` would still refuse to touch these paths on macOS. Two independent layers of protection.

## Tests

Three suites, 52 assertions, all of them run under `/bin/bash` 3.2 as well as bash 5:

- `tests/unit/misc/test_macos_icloud_symlinks.sh` — 29 assertions covering every branch of the refusal matrix.
- `tests/regression/test_macos_icloud_symlinks_safety.sh` — 12 assertions on the data-loss invariants, checking that named canary files survive.
- `tests/regression/test_macos_icloud_symlinks_manifest.sh` — 11 assertions that hash the *whole* sandbox tree before and after, so a file lost in a path nobody named still shows up. Verified to drop from 11/11 to 4/11 against a deliberately reintroduced #1018.

`tests/regression/test_gate_integrity.sh` adds 10 more asserting those gates fail when they should. If any of them regress, CI blocks the merge.

## Manual override: disable entirely

If you never want the automation:

```bash
touch ~/.dotfiles.icloud-skip
```

The script sees this file in the first 5 lines of execution and exits 0 immediately, without touching the filesystem.
