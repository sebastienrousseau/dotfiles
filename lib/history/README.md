# History Module

Shell history management for Bash and Zsh with deduplication, sorting, and clearing.

## Module Structure

```
lib/history/
├── README.md                # This file
├── default.history.sh       # Main entry point (replaces old history.sh)
├── logging.sh              # Structured logging utilities
├── utils.sh                # Temporary file management and formatting
├── backup.sh               # File backup and atomic replacement
├── core.sh                 # Main history management functions
└── config.sh               # Shell-specific configuration and aliases
```

## Quick Start

Source the main module in your shell configuration:

```bash
source ~/.dotfiles/lib/history/default.history.sh
```

Then use the `h` command:

```bash
h              # Display history
h -c           # Clear history (with backup)
h -s           # Sort and remove duplicates
h -l [args]    # List with custom arguments
```

## Functions

### `dotfiles_history`
Main function for history management. Supports:
- `-c`: Clear history file
- `-s`: Sort history and remove duplicates
- `-l`: List history with arguments

### `apply_shell_configurations`
Applies shell-specific history settings (Bash/Zsh).
Called automatically during module load.

### `configure_history`
Sets up history aliases (`h`, `hs`, `hc`).
Called automatically during module load.

### `format_history_output`
Colorizes history display with configurable colors.

### `backup_file`
Creates atomic backups before modifying files.

### `atomic_replace`
Safely replaces files using atomic `mv` operation.

### `log_message`
Structured logging with configurable levels and output targets.

## Configuration

Set environment variables to customize behavior:

```bash
# Verbosity (0=minimal, 1=normal, 2=debug, 3=trace)
export DOTFILES_VERBOSE=1

# Disable backups if needed
export DOTFILES_NO_BACKUP=1

# Custom backup suffix
export DOTFILES_BACKUP_SUFFIX=".backup"

# Color codes for output
export DOTFILES_NUM_COLOR="33"      # Yellow (history numbers)
export DOTFILES_CMD_COLOR="36"      # Cyan (commands)

# Logging
export DOTFILES_LOG_LEVEL=2         # Log info and above
export DOTFILES_LOG_FILE="~/.history.log"
```

## Advantages Over Monolithic Design

✅ **Modular**: Each module has a single responsibility
✅ **Maintainable**: 50-80 lines per file vs 545 lines total
✅ **Testable**: Functions can be tested in isolation
✅ **Reusable**: Modules can be sourced independently
✅ **Documented**: Clear boundaries and dependencies
✅ **Efficient**: Load only what you need

## Module Dependencies

```
default.history.sh
└── config.sh
    └── core.sh
        ├── utils.sh
        │   └── logging.sh
        └── backup.sh
            └── logging.sh
```

## Backward Compatibility

The old `lib/history.sh` file is maintained for backward compatibility.
All functionality is identical; only the internal structure has changed.

## Examples

### Display history with custom format
```bash
h 1 50    # Show entries 1-50
h 100     # Show last 100 entries
```

### Clear history with verbose output
```bash
DOTFILES_VERBOSE=2 h -c
```

### Sort with custom colors
```bash
DOTFILES_NUM_COLOR=32 DOTFILES_CMD_COLOR=37 h -s
```

### Custom logging
```bash
DOTFILES_LOG_LEVEL=3 DOTFILES_LOG_FILE=~/.history.log h -s
```

## See Also

- [lib/history/default.history.sh](default.history.sh) - Main entry point
- [lib/history/core.sh](core.sh) - Core functions
- [docs/PLATFORM_SUPPORT.md](../../docs/PLATFORM_SUPPORT.md) - Platform-specific info
