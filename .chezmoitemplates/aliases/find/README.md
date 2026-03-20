# Find Aliases

Manage Find aliases. Part of the **Universal Dotfiles** configuration.

![Dotfiles banner][banner]

## Description

These aliases are defined in `find.aliases.sh` and are automatically loaded by `chezmoi`.

## Aliases

Command aliases for the `fd` utility, a fast alternative to `find`.
`fd` searches for files and directories in a given path with colorized
output and intuitive syntax. These aliases provide memorable shortcuts
for common operations:
- `fd` is the default alias for `fd --color always` that lists all files
  with colorized output.
- `fda` lists all files with absolute paths.
- `fdc` lists all files with case-insensitive search.
- `fdd` lists all files with details.
- `fde` lists all files with a specified extension.
- `fdf` lists all files while following symbolic links.
- `fdh` shows help for `fd`.
- `fdH` lists all files, including hidden files.
- `fdn` lists all files that match a specified glob.
- `fdo` lists all files with owner information.
- `fds` lists all files with size.
- `fdu` lists all files with exclusion rules.
- `fdv` shows the version of `fd`.
- `fdx` executes a command for each search result.

[banner]: https://kura.pro/dotfiles/v2/images/titles/title-dotfiles.svg

---

Made with ❤️ by [Sebastien Rousseau](https://github.com/sebastienrousseau)
