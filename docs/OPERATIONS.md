# OPERATIONS HANDBOOK

**Version:** 0.2.471  
**Last Updated:** January 15, 2026

> A concise guide to managing, troubleshooting, and maintaining your dotfiles.

---

## Quick Start (5 Minutes)

### Installation

On a fresh macOS or Ubuntu machine:

```bash
git clone https://github.com/sebastienrousseau/dotfiles ~/.dotfiles
cd ~/.dotfiles
dotfiles bootstrap
exec $SHELL
```

### First Check

```bash
dotfiles doctor              # Check system health
dotfiles status              # View configuration
```

### Daily Use

```bash
dotfiles help                # List all commands
dotfiles update              # Pull latest changes
dotfiles bench               # Check startup performance
```

---

## Commands Reference

### `dotfiles help`
Show command help and examples.

```bash
dotfiles help                # Full help
dotfiles help bootstrap      # Help for specific command
```

### `dotfiles doctor`
Run comprehensive diagnostics.

```bash
dotfiles doctor              # Standard checks
dotfiles doctor --paranoid   # Extended security checks
```

**What it checks:**
- Shell environment
- Git and SSH configuration
- PATH ordering and safety
- GPG agent setup
- File permissions
- Dotfiles modules
- Package managers (brew, apt)

### `dotfiles bootstrap`
Initialize dotfiles on a fresh machine (idempotent — safe to run multiple times).

```bash
dotfiles bootstrap           # Full bootstrap
dotfiles bootstrap --dry-run # Preview only
dotfiles bootstrap --yes     # CI mode (no prompts)
```

**What it does:**
1. Creates necessary directories
2. Installs OS-specific packages (brew on macOS, apt on Ubuntu)
3. Symlinks `dotfiles` command to `~/.local/bin`
4. Initializes baseline metrics
5. Clears cache to activate changes

### `dotfiles update`
Pull latest changes and refresh configuration.

```bash
dotfiles update              # Update & refresh cache
```

### `dotfiles status`
Display current configuration and system information.

```bash
dotfiles status              # Full status report
```

**Shows:**
- Version and git branch
- OS, architecture, shell
- Loaded modules and aliases
- Cache status

### `dotfiles bench`
Run startup performance benchmarks.

```bash
dotfiles bench               # 3 iterations (default)
dotfiles bench 10            # 10 iterations
```

**Outputs:**
- Per-run startup times
- Average, min, max
- Comparison to baseline
- Regression warnings if > 20% slower

### `dotfiles export`
Snapshot system state for portability (when migrating machines).

```bash
dotfiles export              # Create ~/.dotfiles/state/<hostname>.json
```

**Captures:**
- OS, arch, shell versions
- Installed packages
- PATH entries
- Enabled features
- Performance baselines

---

## Profiles & Customization

### Startup Profiles

Control which modules load at startup:

```bash
DOTFILES_STARTUP_MODE=fast bash    # Fast: essentials only (~200ms)
DOTFILES_STARTUP_MODE=normal bash  # Normal: recommended (default)
DOTFILES_STARTUP_MODE=full bash    # Full: everything loaded
```

### Environment Variables

```bash
# Performance
export DOTFILES_CACHE_DISABLE=0     # Enable/disable startup cache
export DOTFILES_STARTUP_MODE=normal # fast, normal, or full

# Safety
export DOTFILES_PARANOID=1          # Enable extra security checks

# Logging
export DOTFILES_VERBOSE=1           # Increase verbosity (0-3)
export DOTFILES_LOG_FILE=/tmp/dlog  # Log to file
```

### What's Safe to Change

✅ **Safe to modify:**
- Colors and prompt customization in `lib/aliases/`
- Add your own aliases in `lib/aliases/local/`
- Environment variables (most)
- Keyboard shortcuts and keybindings

❌ **Don't modify without testing:**
- PATH manipulation in `.bashrc` or `.zshrc`
- Core functions in `lib/functions/`
- `.bashrc`/`.zshrc` main initialization

❌ **Never modify:**
- `.git/` directory
- Core history system
- Version file

---

## Troubleshooting

### Shell Won't Start

**Symptom:** Interactive shell hangs or exits immediately

**Fix:**
```bash
# Clear cache
rm ~/.bash_dotfiles_cache

# Test syntax
bash -n ~/.bashrc
zsh -n ~/.zshrc

# Disable optimizations
DOTFILES_CACHE_DISABLE=1 exec $SHELL
```

### Slow Startup

**Symptom:** Shell takes >1 second to initialize

**Fix:**
```bash
# Benchmark current performance
dotfiles bench 5

# Try fast mode
DOTFILES_STARTUP_MODE=fast bash

# Check which modules are slow
time source ~/.bashrc

# Export system state for comparison
dotfiles export
```

### Aliases/Functions Not Working

**Symptom:** Command not found after update

**Fix:**
```bash
# Reload configuration
exec $SHELL

# Check if function exists
declare -f function_name

# List all loaded aliases
alias | grep pattern

# Run smoke tests
scripts/smoke-tests.sh
```

### Git Configuration Issues

**Symptom:** Git not working as expected

**Fix:**
```bash
# Check dotfiles git setup
cd ~/.dotfiles && git status

# Verify global config
git config --global --list

# Check SSH
ssh -T git@github.com
```

### Permission Denied Errors

**Symptom:** "Permission denied" on scripts

**Fix:**
```bash
# Make dotfiles executable
chmod +x ~/.dotfiles/bin/dotfiles
chmod +x ~/.dotfiles/scripts/*.sh

# Fix home directory permissions
chmod 700 ~

# Fix .ssh directory
chmod 700 ~/.ssh
chmod 600 ~/.ssh/*
```

---

## Performance Baseline & Regressions

### Understanding Baselines

Startup time baselines are stored in `metrics/baselines.json` as percentile ranges:

- **p50** (50th percentile): Typical startup time (50% of runs faster)
- **p95** (95th percentile): Worst-case startup time (only 5% of runs slower)
- **Regression threshold:** +20% or +50ms (whichever is larger)

### Checking for Regressions

```bash
# Run benchmark
dotfiles bench 10

# Compare to baseline
cat ~/.dotfiles/metrics/baselines.json

# If slower: identify cause
DOTFILES_STARTUP_MODE=fast bash   # Test fast mode
time source ~/.bashrc             # Profile modules
```

### Updating Baselines

After optimization or system changes:

```bash
# Record new baseline
dotfiles doctor --baseline

# This updates baselines.json with current performance
```

---

## Updating & Maintenance

### Regular Updates

```bash
# Weekly/monthly
cd ~/.dotfiles
git pull
dotfiles update        # Refresh cache

# Check for issues
dotfiles doctor
```

### Before Pushing Changes

```bash
# Validate syntax
bash -n ~/.bashrc
zsh -n ~/.zshrc

# Run tests
scripts/smoke-tests.sh

# Check performance hasn't regressed
dotfiles bench 3

# Verify doctor passes
dotfiles doctor
```

### Safe Rollback

```bash
# Revert last commit
cd ~/.dotfiles
git revert HEAD

# Or reset to last stable version
git reset --hard origin/main

# Refresh
dotfiles update
exec $SHELL
```

---

## Security & Best Practices

### What Must Never Regress

- ✅ Shell startup (< 1s on reasonable hardware)
- ✅ All aliases available (817+ aliases)
- ✅ All functions available (46+ functions)
- ✅ No syntax errors in rc files
- ✅ No password/secret in version control
- ✅ Proper file permissions (600 on ssh config, 700 on .ssh)

### Security Checks

Run regularly:

```bash
# Standard checks
dotfiles doctor

# Paranoid checks (extra security)
DOTFILES_PARANOID=1 dotfiles doctor

# Manual checks
scripts/smoke-tests.sh
```

### Common Security Issues

| Issue | Check | Fix |
|-------|-------|-----|
| World-writable PATH | `dotfiles doctor` | Move to ~/.local/bin |
| SSH key readable | `ls -la ~/.ssh/` | `chmod 600 ~/.ssh/*` |
| Git credentials exposed | `git config --list` | Use credential helper |
| . in PATH | `echo $PATH` | Remove current dir |
| Stale SSH agent | `ps aux \| grep ssh` | Restart agent |

---

## Directory Structure

```
~/.dotfiles/
├── bin/
│   └── dotfiles          # Main CLI entrypoint
├── lib/
│   ├── aliases/          # Alias definitions
│   ├── functions/        # Function definitions
│   ├── history/          # History management
│   └── metrics/          # Performance baselines
├── scripts/
│   ├── bootstrap.sh      # Main bootstrap
│   ├── bootstrap.macos.sh
│   ├── bootstrap.ubuntu.sh
│   ├── doctor.sh         # Diagnostic tool
│   ├── smoke-tests.sh    # Test suite
│   └── measure-startup.sh
├── docs/
│   ├── OPERATIONS.md     # This file
│   ├── README.md         # Getting started
│   └── PHASE_D_*         # Performance docs
├── state/                # System snapshots (.json)
└── metrics/              # Performance data
```

---

## Getting Help

### Built-in Help

```bash
dotfiles help            # Command reference
dotfiles help <cmd>      # Help for specific command
dotfiles doctor          # Diagnose issues
```

### Documentation

- **README.md** — Quick start & overview
- **OPERATIONS.md** — This handbook
- **docs/PHASE_D_PERFORMANCE.md** — Performance deep dive
- **docs/INDEX.md** — Full documentation index

### Debugging Commands

```bash
# Check shell version
bash --version
zsh --version

# Count modules
ls ~/.dotfiles/lib/*.sh

# Count aliases
alias | wc -l

# Check cache
file ~/.bash_dotfiles_cache

# Trace startup
PS4='+ ${BASH_SOURCE}:${LINENO}: ' bash -x -c 'source ~/.bashrc' 2>&1 | head -20
```

---

## FAQ

**Q: Is it safe to customize?**  
A: Yes! Add local customizations to `lib/aliases/local/` and use environment variables. Core files are protected by git.

**Q: How do I report a bug?**  
A: Run `dotfiles doctor`, capture output, and open an issue on GitHub with your OS/shell version.

**Q: Can I use this on multiple machines?**  
A: Yes! Use `dotfiles export` to snapshot configuration, then compare between machines.

**Q: What if a module conflicts with my system?**  
A: Disable it temporarily: `DOTFILES_LOAD_CLOUD_ALIASES=0 bash`. File an issue if the conflict is valid.

**Q: How often should I update?**  
A: Weekly is recommended. Updates are backward compatible and safe to run anytime.

---

## Support

For issues, questions, or suggestions:

1. Check this handbook (OPERATIONS.md)
2. Run `dotfiles doctor` to diagnose
3. Check docs/INDEX.md for relevant topics
4. Open an issue on GitHub with full output from `dotfiles status`

---

**Version:** 0.2.471  
**Last Updated:** January 15, 2026  
**Website:** https://dotfiles.io
