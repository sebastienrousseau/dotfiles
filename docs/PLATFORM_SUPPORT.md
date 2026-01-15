# Platform Support

## Supported Platforms

🅳🅾🆃🅵🅸🅻🅴🆂 is tested and supported on:

- **macOS** (Apple Silicon and Intel)
  - Primary development platform
  - Bash 5.3.9+ (via Homebrew)
  - Zsh 5.9+ (system or Homebrew)
  
- **Linux** (Ubuntu 22.04 LTS+, Debian 12+)
  - Target portability platform
  - Bash 5.0+ (system default)
  - Zsh 5.8+ (optional, via apt)

## Unsupported Platforms

The following platforms are explicitly **not** supported:

- **Windows (native)**: Use WSL2 instead
- **Bash 3.x**: Requires Bash 4+ for associative arrays
- **macOS versions**: Pre-2018 systems using BSD tools exclusively

## OS Detection

The codebase detects the operating system using the POSIX standard `uname -s` command:

```bash
source ~/.dotfiles/lib/functions/portable.sh

if is_macos; then
    # macOS-specific code
    stat -f %m "$file"  # macOS file modification time
elif is_linux; then
    # Linux-specific code
    stat -c %Y "$file"  # Linux file modification time
fi
```

### Supported Patterns

- **macOS**: `uname -s` returns `"Darwin"`
- **Linux**: `uname -s` returns `"Linux"`

Avoid hardcoding:
- ❌ `/opt/homebrew/bin/bash` (macOS only)
- ✅ `/usr/bin/env bash` (portable across platforms)

## Portable Abstractions

The `lib/functions/portable.sh` module provides cross-platform wrappers for OS-specific commands:

### `is_macos`
Returns 0 if running on macOS, 1 otherwise.

```bash
if is_macos; then
    echo "Running on macOS"
fi
```

### `is_linux`
Returns 0 if running on Linux, 1 otherwise.

```bash
if is_linux; then
    echo "Running on Linux"
fi
```

### `get_file_mtime <file>`
Get file modification time in seconds since epoch (portable across macOS/Linux).

```bash
mtime=$(get_file_mtime ~/.zshrc)
age_seconds=$(($(date +%s) - mtime))
```

**Implementation:**
- macOS: `stat -f %m <file>`
- Linux: `stat -c %Y <file>`

### `get_file_perms <file>`
Get file permissions in octal format (e.g., `0644`, `0700`).

```bash
perms=$(get_file_perms ~/.ssh)
if [[ "$perms" == "0700" ]]; then
    echo "SSH directory has correct permissions"
fi
```

**Implementation:**
- macOS: `stat -f %p <file> | tail -c 4`
- Linux: `stat -c %a <file>` (with `0` prefix added)

## Platform-Specific Code Guidelines

### Do Use Portable Abstractions

```bash
# ✅ Good: Uses portable abstraction
source "$DOTFILES_ROOT/lib/functions/portable.sh"
mtime=$(get_file_mtime "$file")
```

### Do Guard Homebrew Paths

```bash
# ✅ Good: macOS-only guard
if [[ "$(uname -s)" == "Darwin" ]] && [[ -s /opt/homebrew/opt/nvm/nvm.sh ]]; then
    source /opt/homebrew/opt/nvm/nvm.sh
elif [[ -s "$HOME/.nvm/nvm.sh" ]]; then
    source "$HOME/.nvm/nvm.sh"
fi
```

### Do NOT Hardcode Platform Paths

```bash
# ❌ Bad: macOS-only, fails on Linux
stat -f %m "$file"

# ❌ Bad: Hardcoded Homebrew path in shebang
#!/opt/homebrew/bin/bash

# ❌ Bad: No platform check
source /opt/homebrew/opt/nvm/nvm.sh
```

### Do Use System Package Managers Appropriately

```bash
# ✅ Good: Detects package manager availability
if command -v brew >/dev/null 2>&1; then
    # Homebrew available (typically macOS)
    PACKAGE_MGR="brew"
elif command -v apt >/dev/null 2>&1; then
    # APT available (typically Linux)
    PACKAGE_MGR="apt"
fi
```

## Command Differences Across Platforms

### File Statistics (stat)

| Command | macOS | Linux |
|---------|-------|-------|
| Modification time | `stat -f %m` | `stat -c %Y` |
| Permissions | `stat -f %p` | `stat -c %a` |
| File size | `stat -f %z` | `stat -c %s` |

### sed (In-Place Editing)

| Operation | macOS | Linux |
|-----------|-------|-------|
| In-place edit | `sed -i ''` | `sed -i` |
| Backup suffix | `sed -i .bak` | `sed -i.bak` |

### readlink

| Platform | Command | Portable Alternative |
|----------|---------|----------------------|
| macOS | `readlink` (no -f) | `python3 -c "import os; print(os.path.realpath('$file'))"` |
| Linux | `readlink -f` | Same as above |

### Date

| Operation | macOS | Linux |
|-----------|-------|-------|
| Unix timestamp | `date +%s` | `date +%s` |
| Format date | `date -f %s` | `date --date @$s` |

## Package Manager Paths

### Homebrew (macOS)

- **Apple Silicon (M1/M2)**: `/opt/homebrew`
- **Intel**: `/usr/local/Cellar`
- Cellar packages: `/opt/homebrew/Cellar/<package>/<version>`
- Opt packages: `/opt/homebrew/opt/<package>`

### System Packages (Linux)

- **Debian/Ubuntu**: `/usr/bin`, `/usr/local/bin`
- **Configuration**: `/etc`
- **Package database**: `/var/lib/apt/lists`

## Testing Portability

### Local Testing (macOS)

```bash
# Run doctor.sh health checks
~/.dotfiles/scripts/doctor.sh

# Run with specific profile
~/.dotfiles/scripts/doctor.sh --profile laptop

# Save baseline metrics
~/.dotfiles/scripts/doctor.sh --baseline
```

### Ubuntu Testing (Recommended)

```bash
# In WSL2, Docker, or native Ubuntu environment:
git clone https://github.com/sebastienrousseau/dotfiles.git
cd dotfiles
bash scripts/doctor.sh --audit
```

### Docker Testing

```dockerfile
FROM ubuntu:22.04
RUN apt-get update && apt-get install -y bash zsh
COPY . /root/.dotfiles
WORKDIR /root/.dotfiles
CMD ["bash", "scripts/doctor.sh", "--audit"]
```

## Known Limitations

### Bash 4.0+ Required

Associative arrays (used in `scripts/doctor.sh`) require Bash 4.0 or later.

- macOS system bash (3.2) is too old
- Use Homebrew: `brew install bash`

### BSD vs GNU Tools

macOS includes BSD versions of standard Unix tools, which have different options than GNU versions:

- `stat`: BSD vs GNU
- `sed`: Different in-place syntax
- `find`: Some option differences
- `grep`: Some regex differences

### NVM and Node.js Paths

- **macOS (Homebrew)**: `/opt/homebrew/opt/nvm/nvm.sh`
- **Linux**: `~/.nvm/nvm.sh`
- **WSL**: Either location depending on installation

## Contributing Portable Code

When adding new features:

1. **Test on both macOS and Linux** (or WSL)
2. **Use portable abstractions** from `lib/functions/portable.sh`
3. **Guard platform-specific paths** with `if [[ "$(uname -s)" == ... ]]`
4. **Document differences** in code comments
5. **Avoid assumptions** about tool availability or paths

Example:

```bash
#!/usr/bin/env bash
# Source portable abstractions
DOTFILES_ROOT="${HOME}/.dotfiles"
# shellcheck source=../lib/functions/portable.sh
source "${DOTFILES_ROOT}/lib/functions/portable.sh"

# Your code here
if is_macos; then
    # macOS-specific implementation
    :
elif is_linux; then
    # Linux-specific implementation
    :
fi
```

## Reporting Platform Issues

If you encounter platform-specific issues:

1. **Specify your environment**:
   - OS and version: `uname -a`
   - Shell: `echo $SHELL && bash --version`
   - Relevant tools: `brew list` or `apt list --installed`

2. **Run diagnostics**:
   ```bash
   ~/.dotfiles/scripts/doctor.sh > diagnostics.txt 2>&1
   ```

3. **Check portability**: Use `lib/functions/portable.sh` functions

4. **Create a PR** with platform guards and tests

## See Also

- [lib/functions/portable.sh](../lib/functions/portable.sh) - Portable abstractions
- [scripts/doctor.sh](../scripts/doctor.sh) - Health check and diagnostics
- [REFACTORING_2026-01-15.md](../REFACTORING_2026-01-15.md) - Recent changes
