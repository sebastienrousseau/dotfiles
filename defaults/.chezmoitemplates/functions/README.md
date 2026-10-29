<img
  src="https://cloudcdn.pro/dotfiles/v2/images/logos/dotfiles.svg"
  alt="dotfiles logo"
  width="66"
  align="right"
/>

# Dotfiles Functions (v0.2.539)

> Modular shell utilities managed by Chezmoi

![Dotfiles banner][banner]

A comprehensive collection of shell utilities and functions to enhance your productivity across macOS, Linux, and Windows environments.

## How it Works

Functions are defined as individual `.sh` files in this directory. During `chezmoi apply`, three
templates in `defaults/dot_config/shell/` turn them into shell layers:

1. `50-logic-functions-core.sh.tmpl` inlines `utils/*.sh` (logging helpers and the `yy` yazi
   wrapper) into `~/.config/shell/50-logic-functions-core.sh`.
2. `51-logic-functions-extra.sh.tmpl` reads `groups.json`, which assigns every other file to a
   group (`api`, `curl`, `files`, `interactive`, `misc`, `nav`, `security`, `system`, `text`). For
   each file it writes a stub function named after the file (for example `extract` for
   `files/extract.sh`). The first call of any stub in a group sources the whole group, then runs
   the real function. The output is `~/.config/shell/51-logic-functions-extra.sh`.
3. `50-logic-functions.sh.tmpl` inlines every `**/*.sh` file into
   `~/.config/shell/50-logic-functions.sh`, which the fish bridge
   (`defaults/dot_config/fish/conf.d/functions.fish.tmpl`) runs functions from.

Bash sources the core and extra layers before the alias layers; zsh sources the eager alias layer
first and the function layers later. So that a name resolves the same in both shells, the extra
layer leaves out every file whose function an alias file also defines (today `backup`, `extract`
and `goto`): it writes no stub for it and does not load it with its group, and the alias-file
version wins in zsh and bash alike (see [archives](../aliases/archives/README.md) and
[cd](../aliases/cd/README.md)). The fish bridge still uses the files here.

A stub exists for the function named after its file, and for the extra names listed in the
template's `$extraStubs` (today `decode64` in `text/encode64.sh`). Other functions in a file, such
as `lazy_nvm` in `misc/lazy_loaders.sh`, exist only after a stub from the same group has run once.

## Usage

### Adding a New Function

1. Create a new `.sh` file in a category directory (e.g., `misc/myfunc.sh`) that defines a
   function with the same name as the file.
2. Add the file to its group in `groups.json` (files in `utils/` load eagerly instead).
3. Apply changes:

   ```bash
   chezmoi apply
   ```

[banner]: https://cloudcdn.pro/dotfiles/v2/images/titles/title-dotfiles.svg

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
| `backup` | Create timestamped backups with compression (fish only; zsh and bash use the [archives](../aliases/archives/README.md) `backup`) | `backup [--max-size SIZE] [--keep N] <files...>` |
| `encode64`/`decode64` | Base64 encoding/decoding | `encode64 "string"` / `decode64 "base64string"` |
| `extract` | Extract various archive formats (fish only; zsh and bash use the [archives](../aliases/archives/README.md) `extract`) | `extract [file]` |
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

### System Utilities

| Function | Description | Usage |
|----------|-------------|-------|
| `caffeine` | Prevent system from sleeping | `caffeine [command]` |
| `environment` | Detect operating system environment | `environment` |
| `freespace` | Clean purgeable disk space | `freespace [disk]` |
| `hiddenfiles` | Toggle visibility of hidden files in Finder | `hiddenfiles [show\|hide]` |
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
| `goto` | Quickly navigate to a directory (fish only; zsh and bash use the [cd](../aliases/cd/README.md) bookmark `goto`) | `goto [directory]` |
| `mount_read_only` | Mount read-only disk image as read-write | `mount_read_only [image]` |
| `rd` | Remove directory and its files | `rd [directory]` |
| `remove_disk` | Safely eject disk | `remove_disk [disk]` |

### Miscellaneous

| Function | Description | Usage |
|----------|-------------|-------|
| `banner` | Print a figlet banner (runs `scripts/tools/figlet-banner.sh` from the source checkout) | `banner [args]` |
| `cmatrix` | Run cmatrix with defaults | `cmatrix [options]` |
| `dothelp` | Search the deployed aliases and functions | `dothelp [search_term]` |
| `emoji` | Emoji picker | `emoji` |
| `lazy_nvm`, `lazy_rbenv`, `lazy_sdk` | Load nvm, rbenv or SDKMAN on first use (`misc/lazy_loaders.sh`) | loaded with the `misc` group |
| `matrix` | Terminal Matrix-style effects | `matrix [options]` |
| `pipes` | Terminal pipes screensaver | `pipes` |
| `prependpath` | Add a directory to PATH without duplicates | `prependpath [directory]` |
| `ql` | Open file in macOS Quick Look | `ql [file]` |
| `rainbow` | Rainbow output through lolcat, or plain `cat` without it | `rainbow [args]` |
| `showhiddenfiles` | Show hidden files in Finder (macOS) | `showhiddenfiles` |
| `yy` | Run yazi and change to its last directory on exit (`utils/yazi.sh`) | `yy [path]` |

## Compatibility

Most utilities work across platforms, with specific adaptations for:

- **macOS**: Full support with macOS-specific utilities
- **Linux**: Compatible with common Linux distributions
- **Windows**: Windows support via WSL, Cygwin, or Git Bash

## Function Documentation

Each function includes comprehensive documentation accessible via the `--help` flag:

```bash
apihealth --help
```

## License

MIT License © 2015-2026

---

Made With ❤️ in London, United Kingdom • [dotfiles.io](https://dotfiles.io)
