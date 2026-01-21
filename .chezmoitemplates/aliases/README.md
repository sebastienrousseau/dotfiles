<img
  src="https://kura.pro/dotfiles/v2/images/logos/dotfiles.svg"
  align="right"
/>

# Dotfiles Aliases (v0.2.471)

Simply designed to fit your shell life 🐚

![Dotfiles banner][banner]

This directory contains modular alias definitions managed by **chezmoi**.

## 📖 How it Works

Aliases are split into small, manageable files (e.g., `git/git.aliases.sh`, `docker/docker.aliases.sh`).

During `chezmoi apply`, the main template `dot_config/shell/aliases.sh.tmpl`:
1. Scans this directory for `**/*.aliases.sh` files.
2. Aggregates them into a single `~/.config/shell/aliases.sh` file.
3. This aggregated file is sourced by your `.zshrc`.

## 🛠 Usage

### Adding a New Alias
1. Create a new directory or file (e.g., `mytool/mytool.aliases.sh`).
2. Define your aliases:
   ```bash
   alias mycmd="echo 'Hello World'"
   ```
3. Apply changes:
   ```bash
   chezmoi apply
   ```

## 🔧 Component List

<!-- markdownlint-disable MD013-->

| Directory       | Description                                      | Link                      |
| :-------------- | :----------------------------------------------- | :------------------------ |
| `archives`      | Compress and extract files and directories.      | [View README](archives/README.md) |
| `cd`            | Navigate the file system.                        | [View README](cd/README.md)       |
| `chmod`         | Change file and directory permissions.           | [View README](chmod/README.md)    |
| `clear`         | Clear the terminal screen.                       | [View README](clear/README.md)    |
| `configuration` | Manage dotfiles and shell configurations.        | [View README](configuration/README.md) |
| `default`       | Set up default shell aliases and configurations. | [View README](default/README.md)  |
| `dig`           | Query DNS name servers.                          | [View README](dig/README.md)      |
| `diagnostics`   | Self-healing and health checks (doctor, drift).  | [View README](diagnostics/README.md) |
| `disk-usage`    | Display disk usage information.                  | [View README](disk-usage/README.md) |
| `editor`        | Configure default text editors.                  | [View README](editor/README.md)   |
| `find`          | Search files and directories using `find`.       | [View README](find/README.md)     |
| `gcloud`        | Manage Google Cloud SDK tools.                   | [View README](gcloud/README.md)   |
| `git`           | Manage Git aliases and configurations.           | [View README](git/README.md)      |
| `gnu`           | Manage GNU core utilities.                       | [View README](gnu/README.md)      |
| `heroku`        | Manage Heroku CLI.                               | [View README](heroku/README.md)   |
| `interactive`   | Configure interactive shell behavior.            | [View README](interactive/README.md) |
| `kubernetes`    | Manage Kubernetes, Helm, and K9s aliases.        | [View README](kubernetes/README.md) |
| `legal`         | License scanning and compliance tools.           | [View README](legal/README.md)      |
| `macOS`         | Manage macOS-specific shell settings.            | [View README](macOS/README.md)    |
| `make`          | Manage GNU Make aliases and utilities.           | [View README](make/README.md)     |
| `mkdir`         | Create directories with custom options.          | [View README](mkdir/README.md)    |
| `modern`        | Modern Rust-based tool replacements (ls, cat).   | [View README](modern/README.md)   |
| `npm`           | Manage Node.js package manager aliases.          | [View README](npm/README.md)      |
| `permission`    | Configure file and directory permissions.         | [View README](permission/README.md) |
| `pnpm`          | Manage pnpm package manager aliases.             | [View README](pnpm/README.md)     |
| `ps`            | Manage process status commands.                  | [View README](ps/README.md)       |
| `python`        | Configure Python aliases and utilities.          | [View README](python/README.md)   |
| `rsync`         | Configure rsync for efficient file transfers.    | [View README](rsync/README.md)    |
| `rust`          | Manage Rust programming tools and configurations.| [View README](rust/README.md)     |
| `security`      | Immutability and signing configuration.          | [View README](security/README.md) |
| `subversion`    | Configure Subversion (SVN) version control.       | [View README](subversion/README.md) |
| `sudo`          | Manage superuser operations.                     | [View README](sudo/README.md)     |
| `tmux`          | Configure tmux terminal multiplexer.             | [View README](tmux/README.md)     |
| `update`        | Update dotfiles and related configurations.       | [View README](update/README.md)   |
| `uuid`          | Generate UUIDs for various use cases.            | [View README](uuid/README.md)     |
| `wget`          | Manage wget command-line tool.                   | [View README](wget/README.md)     |

<!-- markdownlint-enable MD013-->

[banner]: https://kura.pro/dotfiles/v2/images/titles/title-dotfiles.svg
