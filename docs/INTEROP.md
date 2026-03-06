# Cross-Platform Interoperability

How dotfiles commands and shims map across macOS, Linux, and WSL2.

## Command Mapping

| Alias / Command | macOS | Linux (Debian/Arch) | WSL2 (Windows Host) |
| :--- | :--- | :--- | :--- |
| `cb` (Clipboard) | `pbcopy` / `pbpaste` | `xclip` / `wl-copy` | `clip.exe` / `powershell.exe` |
| `open` | `open` | `xdg-open` | `wslview` / `explorer.exe` |
| `notify` | `osascript` (AppleScript) | `notify-send` / `gum log` | `powershell.exe` (Toast) / `gum` |
| `win` (Paths) | N/A | N/A | `wslpath` |
| `browser` | `open` | `xdg-open` | `powershell.exe Start-Process` |

## Infrastructure Parity

| Feature | macOS | Linux | WSL2 |
| :--- | :--- | :--- | :--- |
| **Package Manager** | Homebrew (`brew`) | `apt` / `pacman` / `nix` | `apt` + Windows binaries |
| **Shell Startup** | Async lazy-hydration | Async lazy-hydration | Async (optimized for IO) |
| **Environment** | native plist / launchctl | systemd / dbus | systemd (if enabled) / init |
| **Hardware** | Secure Enclave | TPM 2.0 / LUKS | Windows Hello bridge |

## Virtualization and Containers

- **Docker** — native Docker Desktop on macOS/Windows; native engine on Linux.
- **Nix** — unified declarative environments across all three platforms.
- **Mise** — polyglot runtime management with cross-platform parity.

## Troubleshooting

### WSL2 IO Latency
Keep projects in the Linux filesystem (`~/...`), not in `/mnt/c/...`.

### WSL2 Windows Binary Path
Commands calling Windows-side binaries (`clip.exe`, `explorer.exe`, `cmd.exe`) require those binaries in your Windows `%PATH%`. WSL usually inherits this automatically. If you've disabled path sharing, ensure Windows-side paths are accessible.

### macOS Permissions
Grant Terminal/iTerm2/Ghostty "Full Disk Access" in System Settings to allow dotfiles to manage all configurations.

### Linux GUI Fallbacks
In headless environments (SSH), GUI commands like `cb` and `open` fall back to `gum log` or terminal bell to prevent script hangs.
