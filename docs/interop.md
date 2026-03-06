# 🌐 Cross-Platform Interoperability Matrix

This document outlines how dotfiles commands and shims map across macOS, Linux, and WSL2 environments to ensure a "World-Class" experience regardless of the host.

## 📋 Command Mapping

| Alias / Command | macOS | Linux (Debian/Arch) | WSL2 (Windows Host) |
| :--- | :--- | :--- | :--- |
| `cb` (Clipboard) | `pbcopy` / `pbpaste` | `xclip` / `wl-copy` | `clip.exe` / `powershell.exe` |
| `open` | `open` | `xdg-open` | `wslview` / `explorer.exe` |
| `notify` | `osascript` (AppleScript) | `notify-send` / `gum log` | `powershell.exe` (Toast) / `gum` |
| `win` (Paths) | N/A | N/A | `wslpath` |
| `browser` | `open` | `xdg-open` | `powershell.exe Start-Process` |

## 🛠️ Infrastructure Parity

| Feature | macOS Implementation | Linux Implementation | WSL2 Implementation |
| :--- | :--- | :--- | :--- |
| **Package Manager** | Homebrew (`brew`) | `apt` / `pacman` / `nix` | `apt` + Windows Binaries |
| **Shell Startup** | Async Lazy-Hydration | Async Lazy-Hydration | Async (Optimized for IO) |
| **Environment** | native plist / launchctl | systemd / dbus | systemd (if enabled) / init |
| **Hardware** | Secure Enclave | TPM 2.0 / LUKS | Windows Hello Bridge |

## 🏗️ Virtualization & Containers

- **Docker**: Uses native Docker Desktop on macOS/Windows, or native engine on Linux.
- **Nix**: Unified declarative environments across all three.
- **Mise**: Polyglot runtime management (Node, Python, Go, Rust) with bit-for-bit parity.

## 🆘 Troubleshooting Platform Issues

### WSL2 IO Latency
If you experience slowness, ensure your project is located in the Linux filesystem (`~/...`) and NOT in `/mnt/c/...`.

### WSL2 Windows Binary Path (The #1 Gotcha)
Commands that call Windows-side binaries (like `clip.exe`, `explorer.exe`, or `cmd.exe`) require those binaries to be in your **Windows %PATH%**. While WSL usually inherits this automatically, if you've disabled path sharing or customized your environment heavily, ensure the Windows-side paths are accessible to WSL.

### macOS Permissions
Ensure Terminal/iTerm2/Ghostty has "Full Disk Access" in System Settings to allow dotfiles to manage all configurations.

### Linux GUI Fallbacks
In headless environments (SSH), GUI commands like `cb` and `open` will fallback to `gum log` or terminal bell triggers to prevent script hangs.
