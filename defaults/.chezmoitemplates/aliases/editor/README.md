# Editor Aliases

Manage editor aliases that follow `$EDITOR`. Part of the **Universal Dotfiles** configuration.

![Dotfiles banner][banner]

## Description

These aliases are defined in `editor.aliases.sh`. Loaded by the eager alias layer `~/.config/shell/90-ux-aliases.sh` (a core category).

Only the generic aliases (`e`, `edit`, `editor`, `mate`, `n`, `v`) and `editrc` are always set. The rest depend on the value of `$EDITOR` when the file loads, and the short legacy names (`vi`, `vim`, `ne`, `em`, `et`, `st`) also need `DOTFILES_LEGACY_EDITOR_ALIASES=1`.

## Aliases

| Name | Definition | Notes |
| --- | --- | --- |
| `e` | `${EDITOR}` | Common editor aliases that work with any editor. |
| `edit` | `${EDITOR}` |  |
| `editor` | `${EDITOR}` |  |
| `mate` | `${EDITOR}` |  |
| `n` | `${EDITOR}` |  |
| `v` | `${EDITOR}` | Only when `v` is not already an alias. |
| `vi` | `nvim` | Only when `$EDITOR` is `nvim` or `*/nvim`, `DOTFILES_LEGACY_EDITOR_ALIASES=1`. |
| `vim` | `nvim` | Only when `$EDITOR` is `nvim` or `*/nvim`, `DOTFILES_LEGACY_EDITOR_ALIASES=1`. |
| `nvimrc` | `nvim "${HOME}/.config/nvim/init.lua"` | Only when `$EDITOR` is `nvim` or `*/nvim`. |
| `nvimlua` | `nvim "${HOME}/.config/nvim/init.lua"` | Only when `$EDITOR` is `nvim` or `*/nvim`. |
| `nvimconf` | `nvim "${HOME}/.config/nvim"` | Only when `$EDITOR` is `nvim` or `*/nvim`. |
| `vsc` | `code` | Only when `$EDITOR` is `code` or `*/code`. |
| `vsca` | `code --add` | Only when `$EDITOR` is `code` or `*/code`. |
| `vscd` | `code --diff` | Only when `$EDITOR` is `code` or `*/code`. |
| `vscn` | `code --new-window` | Only when `$EDITOR` is `code` or `*/code`. |
| `vscr` | `code --reuse-window` | Only when `$EDITOR` is `code` or `*/code`. |
| `vscu` | `code --user-data-dir` | Only when `$EDITOR` is `code` or `*/code`. |
| `vsced` | `code --extensions-dir` | Only when `$EDITOR` is `code` or `*/code`. |
| `vscex` | `code --install-extension` | Only when `$EDITOR` is `code` or `*/code`. |
| `vsclist` | `code --list-extensions` | Only when `$EDITOR` is `code` or `*/code`. |
| `nanorc` | `nano "${HOME}/.nanorc"` | Only when `$EDITOR` is `nano` or `*/nano`. |
| `ne` | `nanoedit` | Enhanced nano with line numbers and smooth scrolling. Only when `$EDITOR` is `nano` or `*/nano`, `DOTFILES_LEGACY_EDITOR_ALIASES=1`. |
| `emacs-nw` | `emacs -nw` | Only when `$EDITOR` is `emacs` or `*/emacs`. |
| `emacsc` | `emacsclient` | Only when `$EDITOR` is `emacs` or `*/emacs`. |
| `emacsrc` | `emacs ~/.emacs` | Only when `$EDITOR` is `emacs` or `*/emacs`. |
| `em` | `emacs` | Only when `$EDITOR` is `emacs` or `*/emacs`, `DOTFILES_LEGACY_EDITOR_ALIASES=1`. |
| `et` | `emacs -nw` | Terminal mode. Only when `$EDITOR` is `emacs` or `*/emacs`, `DOTFILES_LEGACY_EDITOR_ALIASES=1`. |
| `st` | `subl` | Only when `$EDITOR` is `subl` or `*/subl`, `DOTFILES_LEGACY_EDITOR_ALIASES=1`, `st` is not already an alias. |
| `stt` | `subl .` | Open current directory. Only when `$EDITOR` is `subl` or `*/subl`. |
| `stn` | `subl -n` | Open in new window. Only when `$EDITOR` is `subl` or `*/subl`. |
| `editrc` | function | Open a configuration file: `editrc bash\|zsh\|vim\|nvim\|tmux\|git\|ssh\|alias\|dotfiles`. `vim` and `nvim` both open `$NVIM_INIT` or `~/.config/nvim/init.lua`. |

[banner]: https://cloudcdn.pro/dotfiles/v2/images/titles/title-dotfiles.svg

---

Made with ❤️ by [Sebastien Rousseau](https://github.com/sebastienrousseau)
