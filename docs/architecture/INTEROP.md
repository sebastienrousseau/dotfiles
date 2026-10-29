---
render_with_liquid: false
---

# Cross-Platform Interoperability

How dotfiles commands and shims map across macOS, Linux, and WSL2.

## Command Mapping

| Alias / Command | macOS | Linux (Debian/Arch) | WSL2 (Windows Host) |
| :--- | :--- | :--- | :--- |
| `cb` (Clipboard) | `pbcopy` / `pbpaste` | `wl-copy` / `wl-paste` (Wayland), else `xclip` or `xsel` | `clip.exe` / `powershell.exe Get-Clipboard` |
| `open` | `/usr/bin/open` | `xdg-open` | `explorer.exe` (path translated with `wslpath -w`) |
| `notify` | `osascript` (AppleScript) | `notify-send`, else prints the message | `powershell.exe` (message box) |
| `win` (run a Windows command) | N/A | N/A | Translates path arguments with `wslpath -w` |

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

In headless environments, `cb` and `open` exit 1 with an error when no backend is found (no `wl-copy`, `xclip` or `xsel`; no `xdg-open`) instead of hanging. `notify` prints the message when `notify-send` is missing.
