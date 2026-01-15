# Functions Directory Organization

## Overview

The `lib/functions/` directory contains 46+ utility functions organized by category. This document describes the function categories and provides guidance for discovering and using functions.

---

## Function Categories

### Core System Functions

These provide essential platform abstractions and system information:

| Function | Purpose |
|----------|---------|
| `portable.sh` | OS detection and cross-platform abstractions (is_macos, get_file_mtime, etc.) |
| `sysinfo.sh` | Display detailed system information (CPU, RAM, disk, OS) |
| `hostinfo.sh` | Show hostname, IP addresses, network information |
| `environment.sh` | Environment variable management and inspection |
| `startup-profile.sh` | Startup mode configuration (fast/normal/full) |

**Usage:**
```bash
is_macos && echo "On macOS"
get_file_mtime /path/to/file
sysinfo
hostinfo
```

### String Transformation Functions

These handle string case conversion and manipulation:

| Function | Purpose |
|----------|---------|
| `uppercase.sh` | Convert strings to UPPERCASE |
| `lowercase.sh` | Convert strings to lowercase |
| `snakecase.sh` | Convert strings to snake_case |
| `kebabcase.sh` | Convert strings to kebab-case |
| `sentencecase.sh` | Convert strings to Sentence case |
| `titlecase.sh` | Convert strings to Title Case |
| `encode64.sh` | Base64 encoding/decoding |
| `hexdump.sh` | Convert strings to hex representation |

**Usage:**
```bash
uppercase "hello" # HELLO
lowercase "HELLO" # hello
snakecase "my string" # my_string
encode64 "text"
```

### Path & Navigation Functions

These help with directory navigation and path manipulation:

| Function | Purpose |
|----------|---------|
| `goto.sh` | Jump to directory bookmarks |
| `prependpath.sh` | Add directory to PATH |
| `cdls.sh` | CD into directory and list contents |
| `rd.sh` | Remove directory and contents safely |
| `ren.sh` | Rename files with pattern matching |
| `freespace.sh` | Check free disk space |
| `size.sh` | Calculate directory/file sizes |

**Usage:**
```bash
goto project
prependpath /usr/local/bin
cdls /path/to/dir
rd old_directory
size /path/to/dir
```

### File & Content Functions

These provide file viewing, management, and inspection:

| Function | Purpose |
|----------|---------|
| `extract.sh` | Extract compressed files automatically |
| `view-source.sh` | View file source with syntax highlighting |
| `ql.sh` | Quick look at files (macOS) |
| `hiddenfiles.sh` / `showhiddenfiles.sh` | Toggle hidden files visibility |
| `zipf.sh` | Create zip file from arguments |
| `hexdump.sh` | Display hex dump of files |
| `curlheader.sh` | Show HTTP headers for URL |
| `curlstatus.sh` | Check HTTP status of URL |
| `curltime.sh` | Measure response time |

**Usage:**
```bash
extract archive.tar.gz
view-source file.js
zipf file1 file2 file3
curlheader https://example.com
curlstatus https://example.com
```

### System Monitoring Functions

These monitor and display system state:

| Function | Purpose |
|----------|---------|
| `hstats.sh` | Show history statistics |
| `myproc.sh` | List your running processes |
| `last.sh` | Show recent login history |
| `logout.sh` | Logout cleanly |
| `whoisport.sh` | Find which process owns a port |
| `mount_read_only.sh` | Mount filesystem as read-only |
| `remove_disk.sh` | Remove mounted disk safely |

**Usage:**
```bash
hstats
myproc
whoisport 8080
mount_read_only /Volumes/disk
```

### API & HTTP Functions

These help with API debugging and HTTP operations:

| Function | Purpose |
|----------|---------|
| `apihealth.sh` | Check API health/status |
| `apilatency.sh` | Measure API response latency |
| `apiload.sh` | Load test an API |
| `httpdebug.sh` | Debug HTTP requests |
| `curlheader.sh` | Show HTTP headers |
| `curlstatus.sh` | Check HTTP status |
| `curltime.sh` | Time HTTP requests |

**Usage:**
```bash
apihealth https://api.example.com
apilatency https://api.example.com
httpdebug
```

### Utility Functions

Miscellaneous utility functions:

| Function | Purpose |
|----------|---------|
| `genpass.sh` | Generate secure random password |
| `keygen.sh` | Generate SSH/encryption keys |
| `stopwatch.sh` | Simple stopwatch timer |
| `matrix.sh` | Matrix "digital rain" effect |
| `backup.sh` | Backup directory with timestamp |
| `caffeine.sh` | Keep system awake (macOS) |
| `vscode.sh` | VS Code command shortcuts |
| `lazy-load.sh` | Lazy load modules on first use |

**Usage:**
```bash
genpass 16 # Generate 16-char password
keygen
stopwatch
backup /path/to/backup
caffeine on
```

---

## Discovering Functions

### List All Available Functions
```bash
ls ~/.dotfiles/lib/functions/*.sh
```

### Find Functions by Purpose
```bash
# Search for functions related to strings
ls ~/.dotfiles/lib/functions/*case.sh

# Search for API functions
ls ~/.dotfiles/lib/functions/api*.sh

# Search for curl functions
ls ~/.dotfiles/lib/functions/curl*.sh
```

### Get Help for a Function
```bash
# Most functions have built-in help
genpass --help
apihealth --help
extract --help

# Or view the source
cat ~/.dotfiles/lib/functions/genpass.sh
```

### Find Functions in History
```bash
# Search command history for function usage
history | grep "genpass"

# Use type command to find a function
type genpass
```

---

## Function Organization by Category

### By Usage Frequency
- **Common (Daily Use):** goto, cdls, size, extract, myproc, genpass
- **Regular (Weekly):** hstats, apihealth, whoisport, backup, keygen
- **Specialized (Project/Context):** apilatency, apiload, httpdebug, curltime
- **Utility (Occasional):** matrix, stopwatch, caffeine, logout

### By Shell Type
- **Bash/Zsh Compatible:** All functions work in both shells
- **macOS Specific:** ql, caffeine, mount_read_only
- **Unix/Linux Compatible:** All core functions portable

### By Performance Impact
- **Fast (<100ms):** String functions, path functions, simple utilities
- **Medium (100-500ms):** File operations, system info, API checks
- **Slow (>500ms):** Full sysinfo, API load testing

---

## Best Practices

### 1. Use Appropriate Functions for Tasks
```bash
# ✅ Good: Use genpass for passwords
genpass 20

# ❌ Bad: Avoid manually creating passwords
echo $RANDOM$RANDOM$RANDOM

# ✅ Good: Use extract for archives
extract myfile.tar.gz

# ❌ Bad: Remember different commands
tar -xzf myfile.tar.gz
```

### 2. Combine Functions Effectively
```bash
# Chain functions for complex operations
cdls /path && size . && myproc

# Use in scripts
size_output=$(size /path/to/dir)
if [[ $size_output -gt 1000000000 ]]; then
    echo "Directory too large, backing up..."
    backup /path/to/dir
fi
```

### 3. Leverage Function Help
```bash
# Most functions document their usage
genpass --help
apihealth -h
curlstatus --help

# Read source for complex functions
cat ~/.dotfiles/lib/functions/backup.sh
```

---

## Adding New Functions

To add a new function to the collection:

1. **Create a new file** in `lib/functions/`:
   ```bash
   touch ~/.dotfiles/lib/functions/myfunction.sh
   ```

2. **Follow the structure**:
   ```bash
   #!/usr/bin/env bash
   
   # Header with description
   # Function: myfunction
   # Description: What it does
   # Usage: myfunction [args]
   
   myfunction() {
       # Implementation
   }
   
   # Call if script is executed directly
   "$@"
   ```

3. **Add documentation** in this README

4. **Test in both shells**:
   ```bash
   bash -c 'source ~/.dotfiles/lib/functions/myfunction.sh && myfunction'
   zsh -c 'source ~/.dotfiles/lib/functions/myfunction.sh && myfunction'
   ```

---

## Function Statistics

- **Total Functions:** 46+
- **Categories:** 8 (System, Strings, Paths, Files, Monitoring, API, Utilities, Lazy Loading)
- **Shell Compatible:** 100% (Bash + Zsh)
- **Lines of Code:** ~3000+ total
- **Average Function Size:** 60 lines

---

## Related Documentation

- [PHASE_D_PERFORMANCE.md](../PHASE_D_PERFORMANCE.md) - Performance optimization including lazy-load.sh
- [PLATFORM_SUPPORT.md](../PLATFORM_SUPPORT.md) - Cross-platform function usage
- [QUICK_REFERENCE.md](../QUICK_REFERENCE.md) - Command quick reference
- [lib/functions.sh](./functions.sh) - Main loader that sources all functions

