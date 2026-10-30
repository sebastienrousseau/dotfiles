# chmod Aliases

Manage file permission shortcuts built on `chmod`. Part of the **Universal Dotfiles** configuration.

![Dotfiles banner][banner]

## Description

These aliases are defined in `chmod.aliases.sh`. Loaded by the lazy alias layer `~/.config/shell/91-ux-aliases-lazy.sh`. It loads after the eager layer (zsh defers it until after startup), so its definitions replace any eager alias of the same name.

## Aliases

Each `chmod_<mode>` alias runs `change_permission <mode>`, which validates its arguments, asks before a recursive change and can back up the current permissions first; run `chmod_help` for its options. The `chmod_r_*`, `chmod_b_*` and `chmod_rb_*` functions apply 644, 755 or 775 recursively (`r`), with a backup (`b`), or both. The `chmod_<who><op><perm>` functions add (`+`) or remove (`-`) one permission (`x`, `w` or `r`) for the user, group, others or all.

| Name | Definition | Notes |
| --- | --- | --- |
| `change_permission` | function | Only when `chmod` is on PATH. |
| `symbolic_permission` | function | Only when `chmod` is on PATH. |
| `chmod_000` | `change_permission 000` | Only when `chmod` is on PATH. |
| `chmod_400` | `change_permission 400` | Read-only for owner. Only when `chmod` is on PATH. |
| `chmod_444` | `change_permission 444` | Read-only for all. Only when `chmod` is on PATH. |
| `chmod_600` | `change_permission 600` | Read/write for owner. Only when `chmod` is on PATH. |
| `chmod_644` | `change_permission 644` | Read/write for owner, read for others. Only when `chmod` is on PATH. |
| `chmod_664` | `change_permission 664` | Read/write for owner and group, read for others. Only when `chmod` is on PATH. |
| `chmod_666` | `change_permission 666` | Read/write for all. Only when `chmod` is on PATH. |
| `chmod_700` | `change_permission 700` | Full for owner only. Only when `chmod` is on PATH. |
| `chmod_744` | `change_permission 744` | Full for owner, read for others. Only when `chmod` is on PATH. |
| `chmod_755` | `change_permission 755` | Full for owner, read/execute for others. Only when `chmod` is on PATH. |
| `chmod_764` | `change_permission 764` | Full for owner, read/write for group, read for others. Only when `chmod` is on PATH. |
| `chmod_775` | `change_permission 775` | Full for owner and group, read/execute for others. Only when `chmod` is on PATH. |
| `chmod_777` | `change_permission 777` | Full permissions for all. Only when `chmod` is on PATH. |
| `chmod_1755` | `change_permission 1755` | Sticky bit + 755. Only when `chmod` is on PATH. |
| `chmod_2755` | `change_permission 2755` | Setgid + 755. Only when `chmod` is on PATH. |
| `chmod_4755` | `change_permission 4755` | Setuid + 755. Only when `chmod` is on PATH. |
| `chmod_r_644` | function | Only when `chmod` is on PATH. |
| `chmod_r_755` | function | Only when `chmod` is on PATH. |
| `chmod_r_775` | function | Only when `chmod` is on PATH. |
| `chmod_b_644` | function | Only when `chmod` is on PATH. |
| `chmod_b_755` | function | Only when `chmod` is on PATH. |
| `chmod_rb_644` | function | Only when `chmod` is on PATH. |
| `chmod_rb_755` | function | Only when `chmod` is on PATH. |
| `chmod_u+x` | function | Only when `chmod` is on PATH. |
| `chmod_u-x` | function | Only when `chmod` is on PATH. |
| `chmod_u+w` | function | Only when `chmod` is on PATH. |
| `chmod_u-w` | function | Only when `chmod` is on PATH. |
| `chmod_u+r` | function | Only when `chmod` is on PATH. |
| `chmod_u-r` | function | Only when `chmod` is on PATH. |
| `chmod_g+x` | function | Only when `chmod` is on PATH. |
| `chmod_g-x` | function | Only when `chmod` is on PATH. |
| `chmod_g+w` | function | Only when `chmod` is on PATH. |
| `chmod_g-w` | function | Only when `chmod` is on PATH. |
| `chmod_g+r` | function | Only when `chmod` is on PATH. |
| `chmod_g-r` | function | Only when `chmod` is on PATH. |
| `chmod_o+x` | function | Only when `chmod` is on PATH. |
| `chmod_o-x` | function | Only when `chmod` is on PATH. |
| `chmod_o+w` | function | Only when `chmod` is on PATH. |
| `chmod_o-w` | function | Only when `chmod` is on PATH. |
| `chmod_o+r` | function | Only when `chmod` is on PATH. |
| `chmod_o-r` | function | Only when `chmod` is on PATH. |
| `chmod_a+x` | function | Only when `chmod` is on PATH. |
| `chmod_a-x` | function | Only when `chmod` is on PATH. |
| `chmod_a+w` | function | Only when `chmod` is on PATH. |
| `chmod_a-w` | function | Only when `chmod` is on PATH. |
| `chmod_a+r` | function | Only when `chmod` is on PATH. |
| `chmod_a-r` | function | Only when `chmod` is on PATH. |
| `chmod_ru+x` | function | Only when `chmod` is on PATH. |
| `chmod_rg+x` | function | Only when `chmod` is on PATH. |
| `chmod_ro+x` | function | Only when `chmod` is on PATH. |
| `chmod_ra+x` | function | Only when `chmod` is on PATH. |
| `show_permissions` | function | Show permissions in octal format for a file/directory Minimalist version using built-in shell features only. Only when `chmod` is on PATH. |
| `permissions` | `show_permissions` | Only when `chmod` is on PATH. |
| `chmod_help` | function |  |

[banner]: https://cloudcdn.pro/dotfiles/v2/images/titles/title-dotfiles.svg

---

Made with ❤️ by [Sebastien Rousseau](https://github.com/sebastienrousseau)
