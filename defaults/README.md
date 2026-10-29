# `defaults/`: the chezmoi source root

This directory holds every chezmoi-managed file: the maintainer's
user-facing default configuration. The repo-root `.chezmoiroot` file
contains `defaults`, so chezmoi reads its source state from here and
nothing outside this directory is deployed to `$HOME`.

The chezmoi naming contract applies unchanged: `dot_*` deploys as
`~/.X`, `executable_*` sets `+x`, `private_*` sets `0600`, and
`run_onchange_*` scripts re-run when their content hash changes.

## Layout

```
defaults/
├── .chezmoidata.toml        # feature flags, profiles, version (source of truth)
├── .chezmoidata/            # extra data files (apple, hardware, keybinds, ...)
├── .chezmoitemplates/       # reusable partials (aliases, functions, ...)
├── .chezmoi.toml.tmpl       # chezmoi config template
├── .chezmoiignore.tmpl      # per-platform ignore rules
├── dot_bashrc, dot_zshrc, dot_zshenv, dot_zprofile, dot_profile, dot_vimrc, ...
├── dot_config/              # XDG configs (~/.config/*)
├── dot_local/               # ~/.local (bin/, share/ sources)
├── dot_claude/, dot_codex/, dot_cargo/, dot_warp/
├── private_dot_ssh/         # ~/.ssh (0600)
├── private_Library/         # macOS ~/Library
├── Code/                    # ~/Code standards (AGENTS.md, templates)
└── run_*                    # chezmoi build and refresh hooks
```

Repo-only material (`bin/`, `lib/`, `plugins/`, `scripts/`, `tools/`,
`tests/`, `docs/`, `install/`) lives outside this directory, so
`chezmoi apply` never deploys it. Package provisioning
(`install/provision/`) runs only through `install.sh --provision`.

## History

The move into `defaults/` shipped in v0.2.503. Users upgrading from
an older layout are migrated by
`install/migrate/migrate-v0_2-to-v0_2_503.sh`, which `install.sh` runs
before the first apply (the provision hook
`install/provision/run_before_00-migrate-v0_2_503.sh.tmpl` also calls it).

## See also

- [RFC: v0.2.503 reorganization](../docs/operations/RFC_v0_2_503_reorganization.md): the original plan.
- [`install/migrate/README.md`](../install/migrate/README.md): user-facing migration doc.
- `../install/migrate/migrate-v0_2-to-v0_2_503.sh`: the migration tool.
