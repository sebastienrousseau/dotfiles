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

## Troubleshooting

### WSL2 IO Latency
Keep projects in the Linux filesystem (`~/...`), not under `/mnt/c/`.

### WSL2 Windows Binary Path
If you've disabled WSL path sharing, make sure Windows-side binaries like `clip.exe` and `explorer.exe` are still reachable in `$PATH`.

### macOS Permissions
Grant your terminal "Full Disk Access" in System Settings so dotfiles can manage all configurations.

### Linux GUI Fallbacks
In headless environments, GUI commands like `cb` and `open` fall back to `gum log` or terminal bell instead of hanging.
