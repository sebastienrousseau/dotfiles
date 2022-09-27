# Dotfiles aliases

![Banner representing the Dotfiles Library](/assets/dotfiles.svg)

This `vscode.plugin.zsh` file creates helpful shortcut aliases for many commonly
used [Visual Studio](https://visualstudio.microsoft.com) commands.

## Table of Contents

- [Dotfiles aliases](#dotfiles-aliases)
  - [Table of Contents](#table-of-contents)
    - [1.0 Visual Studio Code aliases](#10-visual-studio-code-aliases)

### 1.0 Visual Studio Code aliases

| Alias     | Command             | Description                                |
|-----------|---------------------|--------------------------------------------|
| svs | `sudo $_vscode_path $*` | svs: Editing system protected files. |
| vs | `$_vscode_path $*` | vs: Launch Visual Studio Code. |
| vsd | `vs --diff` | vsd: Open a file difference editor. Requires two file paths as arguments. |
| vsgt | `vs --goto` | vsgt: When used with file:line[:character], opens a file at a specific line and optional character position. This argument is provided since some operating systems permit : in a file name. |
| vsh | `vs --help` | vsh: Print usage. |
| vsl | `vs --locale ` | vsl: Set the display language (locale) for the VS Code session. (for example, en-US or zh-TW). |
| vsnw | `vs --new-window` | vsnw: Opens a new session of VS Code instead of restoring the previous session. |
| vsrw | `vs --reuse-window` | vsrw: Forces opening a file or folder in the last active window. |
| vst | `vs .` | vst: Open VS Code from current directory. |
| vsv | `vs --version` | vsv: Print VS Code version, GitHub commit id, and architecture. |
| vsw | `vs --wait` | vsw: Wait for the files to be closed before returning. |
