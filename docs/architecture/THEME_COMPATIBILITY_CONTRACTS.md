# Theme compatibility contracts

The first strangler-migration guard is executable compatibility evidence, not
a new mutation engine. The legacy theme path remains authoritative at runtime.

## Rendered configuration baselines

Run `python3 scripts/theme/check-render-goldens.py` to render and compare 72
checked-in fixtures: Ghostty, Kitty, Alacritty, WezTerm, Foot and tmux; Maui and
Berlin; light and dark; macOS, Linux-desktop and WSL template inputs. CI runs
the same matrix on both a Linux and a macOS host using pinned chezmoi.

The harness copies only the palette catalogue and the theme-name partial into
a temporary source directory. It executes templates, never `apply`, hooks,
reloads, package installs, or desktop changes. Private config/cache/state paths
avoid the user's chezmoi state. Fonts, shell, host identity and platform inputs
are fixed. The header version is `0.0.0` so release-number churn is checked by
the existing version gates rather than obscuring palette diffs.

When intentionally changing output, run the same command with `--update`, review
the text diffs, then rerun without that option. Missing, changed and obsolete
fixtures fail the check; CI never accepts new goldens automatically.

These are **rendered configuration** goldens, not pixel screenshots or proof of
native terminal execution on every listed platform. Foot's macOS input is a
template compatibility case, not a claim that Foot runs on macOS. Real terminal
screenshots, tmux widths 80/100/120/160, font fallbacks, focus/prefix/zoom states
and high-contrast cases remain separate acceptance work.

## Ownership inventory

[`theme-ownership.json`](../../schemas/theme-ownership.json) inventories every
file returned by the legacy `theme_transaction_targets` function, including
its macOS/non-macOS branches. Its
[`schema`](../../schemas/theme-ownership.schema.json) defines closed records
with an adapter, format, ownership granularity and snapshot rollback policy.
The unit contract compares resolved paths and adapters with the actual pure
enumeration functions for Darwin, Linux and the Windows compatibility selector.

The inventory is read-only evidence, **not a capability grant**. It does not
authorize new paths, make plugins safe, replace symlink/path validation, or
provide durable recovery. `snapshot` describes the current in-process rollback,
not a power-loss-safe WAL. Native Windows orchestration is not certified by
testing its selector.

Provider settings are user-owned shared files; listed dotted keys name only
the appearance fields the compatibility adapter intends to change. Legacy
JSON writers still reserialize whole documents and TOML editing is not a
general comment-preserving AST implementation. DMS remains explicitly
`adapter-defined`: its external writer's field-level ownership is unresolved,
so it cannot be silently treated as safe for the future strict core.

Other mutations—wallpaper/desktop preferences, caches, command effects,
transaction journals and reloads—are outside this file-inventory scope. The
next contract increment must classify those effects and define the six ADRs
before moving authority into `dot-core`.
