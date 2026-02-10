# Interactive Aliases

Manage Interactive aliases. Part of the **Universal Dotfiles** configuration.

![Dotfiles banner][banner]

## Description

These aliases are defined in `interactive.aliases.sh` and are automatically loaded by `chezmoi`.

## Aliases

This code provides a set of interactive aliases for common command line
operations. The aliases are designed to simplify and enhance the user
experience by adding interactive prompts before executing potentially
destructive operations.
* `cp` Copy files and directories interactively (ask before overwrite) with
verbose output.
* `del` Remove files or directories interactively (ask before each removal)
with verbose output, recursively.
* `ln` Create symbolic links interactively (ask before overwrite) with verbose
output.
* `mv` Move or rename files interactively (ask before overwrite) with verbose
output.
* `rm` Remove files or directories interactively (ask before each removal) with
verbose output.
* `zap` Alias for 'rm', removes files or directories interactively (ask before
each removal) with verbose output.
### Trash manipulation alias
* `bin` Remove all files in the trash directory (user's .Trash) forcefully and
recursively.
* `chmod` Change file or directory permissions with verbose output.
* `chown` Change file or directory owner and group with verbose output.
* `diff` Compare and show differences between two files in unified format.
* `grep` Search for a pattern in files or output, showing line numbers and
case-insensitively.
* `mkdir` Create a new directory, making parent directories as needed, with
verbose output.

[banner]: https://kura.pro/dotfiles/v2/images/titles/title-dotfiles.svg

---

Made with ❤️ by [Sebastien Rousseau](https://github.com/sebastienrousseau)
