<img
  src="https://kura.pro/dotfiles/v2/images/logos/dotfiles.svg"
  alt="dotfiles logo"
  width="66"
  align="right"
/>

# Dotfiles Path Configuration Scripts

Simply designed to fit your shell life 🐚

![Dotfiles banner][banner]

This repository includes two scripts designed to manage and customize the system `PATH` variable for enhanced environment configuration. The scripts are organized and detailed below.

## 🔑 Scripts List

<!-- markdownlint-disable MD013-->

### Path Configuration

| Script            | Description                                       | Usage                          |
| :---------------- | :----------------------------------------------- | :----------------------------- |
| `custom.paths.sh` | Configure custom paths for frameworks and tools. | `source custom.paths.sh`      |
| `default.paths.sh`| Set default paths for common system utilities.   | `source default.paths.sh`     |

### Features

#### `custom.paths.sh`

- **System Paths:** Adds essential directories like `/usr/local/bin`, `/usr/bin`, etc.
- **Frameworks & Applications:** Adds paths for frameworks like Apple binaries, TeX Live, Cargo, Go, and Node.js.
- **Application-Specific Paths:** Configures paths for tools like Topaz Photo AI, Little Snitch, and iTerm.
- **Deduplication:** Ensures no duplicate entries in the `PATH` variable.

#### `default.paths.sh`

- **System Paths:** Sets up basic system directories like `/usr/local/bin`, `/usr/local/sbin`, `/usr/bin`, etc.
- **Homebrew Paths:** Includes paths for Homebrew binaries and sbin.
- **Ruby Paths:** Adds paths for Ruby binaries and gem directories, checking installation methods.

### Usage

| Command                     | Description                     |
| :-------------------------- | :------------------------------ |
| `source custom.paths.sh`    | Apply custom path configuration.|
| `source default.paths.sh`   | Apply default path configuration.|
| `echo $PATH`                | Verify the current `PATH`.      |

<!-- markdownlint-enable MD013-->

[banner]: https://kura.pro/dotfiles/v2/images/titles/title-dotfiles.svg
