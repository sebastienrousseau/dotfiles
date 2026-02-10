<img
  src="https://kura.pro/dotfiles/v2/images/logos/dotfiles.svg"
  alt="dotfiles logo"
  width="66"
  align="right"
/>

# Dotfiles Functions (v0.2.480)

> Simply designed to fit your shell life 

![Dotfiles banner][banner]

A comprehensive collection of shell utilities and functions to enhance your productivity across macOS, Linux, and Windows environments.

## How it Works

Functions are defined as individual `.sh` files in this directory.

During `chezmoi apply`, the main template `dot_config/shell/functions.sh.tmpl`:
1. Scans this directory for `**/*.sh` files.
2. Aggregates them into `~/.config/shell/functions.sh`.
3. This file is sourced by `.zshrc`, making all functions immediately available.

## Usage

### Adding a New Function
1. Create a new `.sh` file (e.g., `myfunc.sh`).
2. Add your function definition.
3. Apply changes:
   ```bash
   chezmoi apply
   ```

[banner]: https://kura.pro/dotfiles/v2/images/titles/title-dotfiles.svg

## Function Categories

### API Testing & Monitoring

| Function | Description | Usage |
|----------|-------------|-------|
| `apihealth` | Check health/status of one or multiple APIs | `apihealth [OPTIONS] URL [URL ...]` |
| `apilatency` | Monitor API response time over multiple requests | `apilatency URL [COUNT] [INTERVAL]` |
| `apiload` | Perform basic load testing on API endpoints | `apiload URL [REQUESTS] [DELAY]` |
| `httpdebug` | Debug HTTP requests with detailed timing metrics | `httpdebug [options] [url]` |

### HTTP/Web Utilities

| Function | Description | Usage |
|----------|-------------|-------|
| `curlheader` | View HTTP headers for a given URL | `curlheader [header] [url]` |
| `curlstatus` | Check HTTP status code for a URL | `curlstatus [url]` |
| `curltime` | Measure timing metrics for HTTP requests | `curltime [url]` |
| `view-source` | View the source code of a website | `view-source URL` |
| `whoisport` | Find what process is using a specific port | `whoisport PORT` |

### File Management

| Function | Description | Usage |
|----------|-------------|-------|
| `backup` | Create timestamped backups with compression | `backup [--max-size SIZE] [--keep N] <files...>` |
| `encode64`/`decode64` | Base64 encoding/decoding | `encode64 "string"` / `decode64 "base64string"` |
| `extract` | Extract various archive formats | `extract [file]` |
| `hexdump` | Display file contents in hex format | `hexdump [file] [lines]` |
| `ren` | Batch rename file extensions | `ren OLD_EXT NEW_EXT` |
| `size` | Check file or directory size | `size [file/directory]` |
| `zipf` | Create ZIP archives | `zipf [folder]` |

### File Naming Utilities

| Function | Description | Usage |
|----------|-------------|-------|
| `kebabcase` | Convert filenames to kebab-case | `kebabcase <files...>` |
| `lowercase` | Convert filenames to lowercase | `lowercase <files...>` |
| `sentencecase` | Convert filenames to sentence case | `sentencecase <files...>` |
| `snakecase` | Convert filenames to snake_case | `snakecase <files...>` |
| `titlecase` | Convert filenames to Title Case | `titlecase <files...>` |
| `uppercase` | Convert filenames to UPPERCASE | `uppercase <files...>` |

###  System Utilities

| Function | Description | Usage |
|----------|-------------|-------|
| `caffeine` | Prevent system from sleeping | `caffeine [command]` |
| `environment` | Detect operating system environment | `environment` |
| `freespace` | Clean purgeable disk space | `freespace [disk]` |
| `hiddenfiles` | Toggle visibility of hidden files in Finder | `hiddenfiles [show|hide]` |
| `hostinfo` | Display detailed host information | `hostinfo` |
| `hstats` | View statistics about most used commands | `hstats` |
| `last` | List recently modified files | `last [minutes]` |
| `logout` | Cross-platform logout utility | `logout [--force]` |
| `myproc` | List processes owned by current user | `myproc` |
| `stopwatch` | Simple terminal stopwatch | `stopwatch` |
| `sysinfo` | Display system information with emoji OS icons | `sysinfo` |

#### Caffeine Commands

The `caffeine` utility prevents your system from sleeping or activating the screensaver.

| Command | Description |
|---------|-------------|
| `caffeine daemon` | Start the caffeine daemon (creates a lockfile) |
| `caffeine status` | Check if the daemon is running and active |
| `caffeine query` | Same as status, but returns exit code instead of printing |
| `caffeine start` | Start keeping the screen awake |
| `caffeine stop` | Stop keeping the screen awake |
| `caffeine toggle` | Toggle keeping the screen awake |
| `caffeine shutdown` | Completely shut down the caffeine daemon |
| `caffeine diagnostic` | Show diagnostic information |
| `caffeine version` | Show version information |
| `caffeine help` | Show help message |

**Cross-Platform Support**: Works on macOS (using native `caffeinate`), Linux (using `xdg-screensaver` and `xset`), and Windows (using PowerShell simulated keypresses).

### Security & Credentials

| Function | Description | Usage |
|----------|-------------|-------|
| `genpass` | Generate strong random passwords | `genpass [num_blocks] [separator]` |
| `keygen` | Generate SSH key pairs with strong encryption | `keygen [name] [email] [type] [bits]` |

### Navigation & Directory Management

| Function | Description | Usage |
|----------|-------------|-------|
| `cdls` | Change directory and list contents | `cdls [directory]` |
| `goto` | Quickly navigate to a directory | `goto [directory]` |
| `mount_read_only` | Mount read-only disk image as read-write | `mount_read_only [image]` |
| `rd` | Remove directory and its files | `rd [directory]` |
| `remove_disk` | Safely eject disk | `remove_disk [disk]` |

### Miscellaneous

| Function | Description | Usage |
|----------|-------------|-------|
| `matrix` | Terminal Matrix-style effects | `matrix [options]` |
| `prependpath` | Add a directory to PATH without duplicates | `prependpath [directory]` |
| `ql` | Open file in macOS Quick Look | `ql [file]` |
| `vscode` | Open file in Visual Studio Code | `vscode [file]` |

## Compatibility

Most utilities work across platforms, with specific adaptations for:

-  **macOS**: Full support with macOS-specific utilities
-  **Linux**: Compatible with common Linux distributions
-  **Windows**: Windows support via WSL, Cygwin, or Git Bash

## Function Documentation

Each function includes comprehensive documentation accessible via the `--help` flag:

```bash
apihealth --help
```

## License

MIT License © 2015-2026 Sebastien Rousseau

---

Made With ❤️ in London, United Kingdom • [dotfiles.io](https://dotfiles.io)
