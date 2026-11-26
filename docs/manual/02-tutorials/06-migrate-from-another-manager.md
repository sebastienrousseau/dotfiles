---
render_with_liquid: false
---

<!-- Moved from the README (wave 2, R2.3); the text is unchanged. -->

# One-minute migration from another dotfiles manager

The one-minute version is `dot config init`. It clones any GitHub user's
dotfiles repository through this harness, refuses to clobber an
existing chezmoi source without `--force`, insists on HTTPS, and
previews with `--dry-run`:

```bash
dot config init alice --dry-run     # preview: what github.com/alice/dotfiles would do
dot config init alice               # clone + apply through the dot harness
dot config init https://... --no-apply
```

Coming from a specific tool? The headline mapping is below, and
`dot config init <user> --dry-run` shows the repository URL and
target directory it would use before anything is written.

| Coming from | What changes |
|---|---|
| **yadm** | bare-repo tracking → a chezmoi source tree; `yadm alt` → `.tmpl` files driven by `.chezmoidata.toml`; `yadm encrypt` → age / SOPS through `dot secret` |
| **GNU Stow** | one package directory per tool → one `dot_config/<tool>/` tree, deployed by `chezmoi apply` instead of a symlink farm |
| **bare git repository** (`config` alias) | `$HOME` as work tree → `~/.dotfiles` as source; `config status` → `dot status` / `dot diff` |
| **plain chezmoi** | keep your source tree as it is; gain `dot doctor` / `doctor fix` / `theme` / `secret` / `fleet` on top; `chezmoi apply` → `dot sync` |

Upgrades between versions of this project are a different document:
[`docs/operations/MIGRATION.md`](../../../docs/operations/MIGRATION.md).
