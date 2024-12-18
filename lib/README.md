<img
  src="https://kura.pro/dotfiles/v2/images/logos/dotfiles.svg"
  alt="dotfiles logo"
  width="66"
  align="right"
/>

# Dotfiles Shell Configuration Scripts

Simply designed to fit your shell life 🐚

![Dotfiles banner][banner]

This repository includes various scripts to enhance your shell experience, manage configurations, and customize behavior. The scripts are organized and detailed below.

## 🔑 Scripts List

<!-- markdownlint-disable MD013-->

### Alias Management

| Script            | Description                                      | Usage                          |
| :---------------- | :----------------------------------------------- | :----------------------------- |
| `aliases.sh`      | Manage and load custom shell aliases.            | `source aliases.sh`           |

#### Features

- **Remove All Aliases:** Clears all existing aliases in the current shell environment.
- **Load Custom Aliases:** Sources alias definitions from a specified directory within `.dotfiles`.

### Configuration Management

| Script            | Description                                      | Usage                          |
| :---------------- | :----------------------------------------------- | :----------------------------- |
| `configurations.sh` | Load custom shell configurations.              | `source configurations.sh`    |

#### Features

- **Custom Configurations:** Loads shell-specific configurations from the `.dotfiles` directory.
- **Error Handling:** Reports missing configuration files or sourcing issues.

### Function Management

| Script            | Description                                      | Usage                          |
| :---------------- | :----------------------------------------------- | :----------------------------- |
| `functions.sh`    | Load custom executable functions.                | `source functions.sh`         |

#### Features

- **Custom Functions:** Sources user-defined functions from the `.dotfiles/lib/functions` directory.
- **Directory Check:** Ensures the functions directory exists before sourcing.

### History Management

| Script            | Description                                      | Usage                          |
| :---------------- | :----------------------------------------------- | :----------------------------- |
| `history.sh`      | Manage and configure shell history behavior.     | `source history.sh`           |

#### Features

- **Clear History:** Clears the history file and removes duplicates.
- **List History:** Displays shell history with enhanced formatting.
- **History Configuration:** Sets up shell-specific history options for Bash and Zsh.

### Path Management

| Script            | Description                                      | Usage                          |
| :---------------- | :----------------------------------------------- | :----------------------------- |
| `paths.sh`        | Load custom path configurations.                 | `source paths.sh`             |

#### Features

- **Load Paths:** Adds directories to the shell `PATH` variable from `.dotfiles/lib/paths`.
- **Error Reporting:** Alerts the user if the paths directory is missing.

### Usage

| Command                     | Description                              |
| :-------------------------- | :--------------------------------------- |
| `source <script>.sh`        | Apply the respective script configuration.|
| `echo $PATH`                | Verify the current `PATH`.               |
| `h` or `history`            | Access custom history management.        |

<!-- markdownlint-enable MD013-->

[banner]: https://kura.pro/dotfiles/v2/images/titles/title-dotfiles.svg
