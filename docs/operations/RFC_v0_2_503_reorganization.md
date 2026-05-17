---
title: "RFC: v0.2.503 Repository Reorganisation"
status: Accepted — shipping incrementally in this PR
authors: ['@sebastienrousseau']
opened: 2026-05-17
accepted: 2026-05-17
target: v0.2.503
---

# RFC: v0.2.503 Repository Reorganisation

> **Status: Accepted.** This RFC was opened in this PR and
> immediately accepted by the maintainer with explicit decision to
> ship the reorganisation incrementally within v0.2.503 rather
> than the originally-proposed two-version deprecation window.
> Phases land as separate commits on `feat/v0.2.503`; each is
> independently atomic and verified by `dot lint` + the existing
> test matrix.

## Summary

Split the current chezmoi-managed monorepo into a **framework layer**
(distributable CLI + library) and a **defaults layer** (user-facing
configuration), with the framework layer publishable as a
standalone tarball to Homebrew, Scoop, and AUR. Maintain
backwards-compatible behaviour for existing users via a one-shot
migration script that runs on first apply after upgrade.

## Motivation

R4 hard-audit identified the framework/user-config intermingling
as the **highest-leverage structural gap** blocking de-facto-
framework status (`HARD_AUDIT_2026.md` §8.5 Top-5 adoption gaps).
Concrete symptoms:

1. **Distribution stuck at "curl-pipe-bash".** The Homebrew /
   Scoop / AUR manifests scaffolded in v0.2.503
   (`install/{homebrew,scoop,aur}/`) cannot publish until there's
   a single `bin/dot` tarball — chezmoi's `dot_*` / `executable_*`
   / `private_*` prefixes force the current layout. Until that's
   fixed, downstream distros have nothing to package.

2. **New contributor onboarding cost.** Even with the v0.2.503
   `STRUCTURE.md`, ~20 chezmoi-prefixed root paths require a
   concept (the chezmoi naming contract) to navigate. A
   `bin/` + `lib/` + `defaults/` layout is self-documenting.

3. **Framework forks are blocked.** Anyone wanting to fork the
   *CLI* without the maintainer's personal configs has to
   manually delete 80+ tool-specific directories under
   `dot_config/`. A clean separation makes "fork the framework,
   apply my own defaults" a one-command flow.

4. **Test surface bleed.** CI runs `chezmoi apply --dry-run` on
   every PR, exercising both framework templates AND the
   maintainer's personal defaults. A real consumer running the
   framework will not exercise the maintainer's `dot_config/aider/`
   etc. — and yet a regression there blocks CI.

The reorganisation is **breaking** for existing user installs:
chezmoi tracks deployed files by source path, so moving
`dot_local/bin/executable_dot` to `bin/dot` means the old
`~/.local/bin/dot` would be removed before the new path is
installed. Mitigation: ship a `migrate-v0.2-to-v0.3.sh` script
that runs before the first post-upgrade `chezmoi apply`.

## Detailed design

### Target layout

Following the [Debian/aws-cli](https://github.com/Debian/aws-cli)
discipline (every top-level path has a clear purpose; contributor
orients in <30 seconds):

```
.
├── bin/                          # CLI entrypoints
│   ├── dot                       # was dot_local/bin/executable_dot
│   ├── dot-load-benchmark-pty    # was dot_local/bin/executable_dot-load-benchmark-pty
│   ├── dot-theme-sync            # was dot_local/bin/executable_dot-theme-sync
│   ├── dot-bootstrap             # was dot_local/bin/executable_dot-bootstrap
│   └── dot-update                # was dot_local/bin/executable_update (renamed)
├── lib/                          # Framework library (no chezmoi)
│   ├── commands/                 # was scripts/dot/commands/
│   ├── ui.sh                     # was scripts/dot/lib/ui.sh
│   ├── utils.sh                  # was scripts/dot/lib/utils.sh
│   ├── platform.sh               # was scripts/dot/lib/platform.sh
│   ├── log.sh                    # was scripts/dot/lib/log.sh
│   ├── bento.sh                  # was scripts/dot/lib/bento.sh
│   └── secrets_provider.sh       # was scripts/lib/secrets_provider.sh
├── share/                        # OS-conventional resources
│   ├── man/man1/dot.1            # was dot_local/share/man/man1/dot.1
│   ├── completions/              # was dot_local/share/zsh/completions/
│   └── docs/                     # was docs/
├── defaults/                     # User-facing default config (was dot_config/, etc.)
│   ├── home/                     # dotfiles deployed to $HOME (dot_X → .X)
│   ├── config/                   # dotfiles deployed to $XDG_CONFIG_HOME
│   └── tools/                    # per-tool configs (mise/, npmrc/, ...)
├── install/                      # Distribution + bootstrap
│   ├── install.sh                # was install.sh (moved one level down)
│   ├── homebrew/dot.rb           # already at install/homebrew/ in v0.2.503
│   ├── scoop/dot.json            # already at install/scoop/    in v0.2.503
│   ├── aur/PKGBUILD              # already at install/aur/      in v0.2.503
│   ├── provision/                # was install/provision/ (chezmoi run_onchange_ hooks)
│   └── migrate/                  # NEW: migrate-v0_2-to-v0_3.sh + rollback
├── tests/                        # unchanged
├── examples/                     # unchanged
├── tools/                        # NEW: ops scripts not shipped to users
│   ├── ci/                       # was scripts/ci/
│   ├── release/                  # was scripts/release/
│   ├── maintenance/              # was scripts/maintenance/
│   ├── docs/                     # was scripts/docs/
│   └── version-sync.sh           # was scripts/version-sync.sh
├── .chezmoiroot                  # NEW: points at defaults/
├── README.md
├── LICENSE
├── CHANGELOG.md
├── CLAUDE.md  /  AGENTS.md  /  per-harness renders
└── (no more dot_X at root)
```

### chezmoi adaptation

`.chezmoiroot` lets chezmoi treat a subdirectory as the source
root. With `.chezmoiroot = "defaults"`, chezmoi will look for
`defaults/home/dot_zshrc`, `defaults/config/dot_starship.toml`,
etc. — and deploy to the normal `~/.zshrc` / `~/.config/starship.toml`
paths.

This means:
- Repo top-level is no longer required to follow chezmoi naming.
- `bin/dot` is a plain shell script, not `dot_local/bin/executable_dot`.
- `share/man/man1/dot.1` is a plain file, not chezmoi-deployed.
- A Homebrew formula can `bin.install 'bin/dot'` directly.

### Migration tool

`install/migrate/migrate-v0.2-to-v0.3.sh`:

1. Detect existing chezmoi state at `~/.local/share/chezmoi` /
   `~/.config/chezmoi/chezmoi.toml`.
2. Read the user's pinned source repo from chezmoi.toml; if it's
   `sebastienrousseau/dotfiles@<v0.2.x>`, warn and confirm.
3. Run `chezmoi diff` and persist the per-file output to
   `~/.local/state/dotfiles/v0_2_to_v0_3_pre_diff.log` so the
   user has a record of pre-migration state.
4. Run `chezmoi forget` for paths that are moving (no destructive
   delete — chezmoi forget only un-tracks).
5. Update `~/.config/chezmoi/chezmoi.toml` to point at the new
   sourceDir with `.chezmoiroot` honoured.
6. Run `chezmoi apply` — picks up the new layout and re-creates
   the user's files at their canonical paths.
7. Run `dot doctor` and `dot lint` to verify.

The migration is **idempotent** and **safe to abort**: at step 4
the chezmoi state is removed but no user data is deleted. At step
6 chezmoi notices "these files already exist on disk with content
matching the source" and is a no-op.

### Library bash-source paths

Today `scripts/dot/commands/<cmd>.sh` does:
```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/utils.sh"
```

After reorganisation:
```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils.sh"   # commands/<cmd>.sh → lib/utils.sh
```

Or, more robustly, drive lookup from a single env var set by `bin/dot`:
```bash
: "${DOT_LIB:=$(dirname "$(realpath "$0")")/../lib}"
source "$DOT_LIB/utils.sh"
```

The Homebrew formula sets `$DOT_LIB` to `${libexec}/lib` so
`bin/dot` finds its library wherever the package manager installed
it.

### Distribution surface

Once `bin/dot` is standalone:

| Channel | Artefact | Verify command |
|---------|----------|----------------|
| Homebrew tap | `dot-${VERSION}-${OS}-${ARCH}.tar.gz` | `brew install sebastienrousseau/tap/dot && dot version` |
| Scoop bucket | `dot.json` → `dot-${VERSION}-windows-${ARCH}.zip` | `scoop install dot && dot version` |
| AUR | `dotfiles-git` PKGBUILD building from source | `paru -S dotfiles-git && dot version` |
| `install.sh` | Same SHA256-verified path as today | `bash install.sh` |
| Direct tarball | Cosign-signed + SLSA-attested release asset | per `docs/security/VERIFY_RELEASE.md` |

The chezmoi-managed `defaults/` subtree is **only** consumed when
a user wants the maintainer's opinionated config layer. It's a
strict superset: install `dot` standalone for the CLI; layer
`defaults/` on top if you want the wallpaper-theming +
multi-shell setup.

## Backwards compatibility

| Surface | v0.2.x behaviour | v0.2.503 behaviour | Breaking? |
|---------|------------------|------------------|-----------|
| `~/.local/bin/dot` | Deployed by chezmoi | Replaced by Homebrew/Scoop install, OR symlinked by chezmoi from the new source | Yes — path may move; migration script handles it |
| `~/.zshrc` etc | Source-pinned at `dot_zshrc` | Source-pinned at `defaults/home/dot_zshrc`, chezmoi reads via `.chezmoiroot` | No — destination path unchanged |
| `dot <cmd>` API | All subcommands work as documented | Same | No |
| `scripts/dot/commands/*.sh` consumers | Direct source paths used in user customisations | Path moves to `lib/commands/*.sh` | Yes — affects any user who source'd these directly |
| `.chezmoidata.toml` | Repo root | Repo root (unchanged for compatibility with old user `chezmoi init` flows) | No |

### Two-version deprecation window

v0.2.503 ships with the migration script and a deprecation warning
in `dot doctor`. v0.4.0 removes any v0.2.x shim code. Users who
skip v0.2.503 entirely (v0.2.x → v0.4.0) hit a hard error and must
run the migration tool from a v0.3.x release manually.

## Alternatives considered

### A) Keep the chezmoi monorepo as-is

**Pros**: zero migration cost; works today.
**Rejected**: blocks Homebrew/Scoop/AUR publication permanently. The
Top-5 adoption gap remains. R4 audit's "9.0/10 internal · 7.5/10
adoption" plateau persists.

### B) Two-repo split (framework + defaults)

Publish `dot` framework at `sebastienrousseau/dot` and the
maintainer's personal defaults at `sebastienrousseau/dotfiles`.

**Pros**: cleanest possible separation. Framework forks trivial.
**Rejected (for v0.3)**: requires a second repo, doubles the CI
matrix, and forces users to install from two sources. Defer to
v0.4 if v0.3 single-repo with `.chezmoiroot` proves insufficient.

### C) Rename current root files only (cosmetic)

Just rename `dot_local/bin/executable_dot` → `bin/executable_dot`
without `.chezmoiroot`.

**Rejected**: chezmoi only resolves the `executable_` /
`dot_` prefixes for files inside its source root, so moving the
prefixed file outside breaks chezmoi-driven install entirely
without giving us a standalone tarball.

## Unresolved questions

1. **How does the `defaults/` subtree behave when a user wants to override one default?** Today they edit `dot_config/X.tmpl` directly. Post-reorg, do they: (a) edit `defaults/config/X.tmpl` and live with merge conflicts on framework updates, or (b) use a chezmoi `data` override + template conditional, or (c) maintain a second repo layered atop `defaults/`?
2. **Should `install/migrate/` ship in the regular framework install, or only via a one-shot `https://...migrate.sh` URL?** Bundling it forever increases install size; URL-only requires the user to find and trust the right URL during a stressful upgrade moment.
3. **Does `.chezmoiroot` survive existing user customisations in `~/.config/chezmoi/chezmoi.toml`?** Needs verification on a real upgrade test.
4. **Windows-native `bin/dot`**: standalone PowerShell rewrite, or wrapper that shells to bash via WSL/git-bash? `POWERSHELL_PARITY.md` documents the current stub state.

## Implementation plan

| Phase | Scope | Effort |
|-------|-------|--------|
| 1 | Draft + ratify this RFC. Get user OK. | Done (this PR's draft) |
| 2 | Create `defaults/`, `bin/`, `lib/`, `share/`, `tools/` and copy files. Update bash source paths. Add `.chezmoiroot`. | 1 week |
| 3 | Write `install/migrate/migrate-v0_2-to-v0_3.sh`. Test against a synthetic v0.2.503-installed environment. | 3 days |
| 4 | Update CI: every workflow that references `scripts/`, `dot_local/`, `dot_config/` needs path updates. | 3 days |
| 5 | Update every doc that references the old paths. Most are in `docs/manual/`. | 1 day |
| 6 | Cut v0.2.999 RC as a deprecation-warning-only release; let real users dry-run the migration. | 1 day + 2-week soak |
| 7 | Cut v0.2.503 with the actual reorg + migration tool. | 1 day |
| 8 | Publish to Homebrew/Scoop/AUR using `install/{homebrew,scoop,aur}/` scaffolds. | 1 week |
| **Total** | | **~5 weeks calendar time** |

## See also

- `HARD_AUDIT_2026.md` §8.3 — cross-platform gap analysis.
- `HARD_AUDIT_2026.md` §8.5 — Top-5 de-facto adoption gaps.
- `STRUCTURE.md` — today's layout (honest about the chezmoi-prefix forcing function).
- `GOVERNANCE.md` — RFC process this document follows.
- `install/README.md` — distribution-channel publication checklist.
- Reference: [Debian/aws-cli](https://github.com/Debian/aws-cli) — clean top-level discipline.
