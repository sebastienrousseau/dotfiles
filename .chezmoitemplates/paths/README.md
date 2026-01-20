<img
  src="https://kura.pro/dotfiles/v2/images/logos/dotfiles.svg"
  alt="dotfiles logo"
  width="66"
  align="right"
/>

# Dotfiles Path Configuration (v0.2.471)

Simply designed to fit your shell life 🐚

![Dotfiles banner][banner]

This directory manages your system `PATH` variable using modular scripts.

## 📖 How it Works

Path configurations are split into priority-based files. `chezmoi` aggregates them alphabetically.

1. `dot_config/shell/paths.sh.tmpl` scans this directory.
2. Content is aggregated into `~/.config/shell/paths.sh`.
3. Sourced by `.zshrc` at startup.

## 🔑 Scripts List

| Script | Description |
| :--- | :--- |
| `00-default.paths.sh` | Sets base system paths (`/usr/bin`, `/sbin`, etc.) and Homebrew. Loaded first. |
| `99-custom.paths.sh` | Sets custom user paths (Language SDKs, local bins). Loaded last to ensure precedence. |

## 🛠 Usage

### Adding a user path
1. Edit `99-custom.paths.sh` or create a new file (e.g. `50-myproject.paths.sh`).
2. Add `export PATH="$PATH:/path/to/dir"`.
3. Apply changes:
   ```bash
   chezmoi apply
   ```
4. Verify:
   ```bash
   echo $PATH
   ```

<!-- markdownlint-enable MD013-->

[banner]: https://kura.pro/dotfiles/v2/images/titles/title-dotfiles.svg
