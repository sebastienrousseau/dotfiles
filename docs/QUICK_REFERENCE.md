# Dotfiles Doctor - Quick Reference

## Commands

```bash
# Basic Usage
dotfiles doctor                          # Standard health check
dotfiles doctor --help                   # Show help

# Profiles (adjust performance thresholds)
dotfiles doctor --profile laptop         # Standard (150/250/500/1000ms)
dotfiles doctor --profile server         # Relaxed (300/500/1000/2000ms)
dotfiles doctor --profile ci             # Strict (100/200/400/800ms)
dotfiles doctor --profile development    # Dev (200/300/600/1200ms)

# Baseline Tracking
dotfiles doctor --baseline               # Save current metrics
dotfiles doctor                          # Compare to baseline

# Audit Mode (read-only, never fails)
dotfiles doctor --audit                  # Report only

# Environment Variable
export DOTFILES_DOCTOR_PROFILE=server    # Set default profile
dotfiles doctor                          # Uses server profile
```

---

## Profiles

| Profile | Excellent | Good | Acceptable | Blocker | Use Case |
|---------|-----------|------|------------|---------|----------|
| **default** | 150ms | 250ms | 500ms | 1000ms | Standard desktop |
| **laptop** | 150ms | 250ms | 500ms | 1000ms | Same as default |
| **server** | 300ms | 500ms | 1000ms | 2000ms | Production servers |
| **ci** | 100ms | 200ms | 400ms | 800ms | CI/CD pipelines |
| **development** | 200ms | 300ms | 600ms | 1200ms | Dev environments |

---

## Output Examples

### Standard Check
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  🏥 Dotfiles Health Check
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

▸ Shell Startup Performance (Profile: default)
  ✓ Zsh startup: 107ms (excellent)
  ⚠ Bash startup: 1546ms (slow, approaching blocker threshold)

▸ Required Files
  ✓ Zsh configuration exists
  ✓ Bash configuration exists

Summary
  Total checks: 15
  Passed: 13
  Warnings: 2

Status: All checks passed!
```

### With Baseline
```
▸ Shell Startup Performance (Profile: default)
  ✓ Zsh startup: 115ms (baseline: 107ms, +8ms regression) (excellent)
  ⚠ Bash startup: 1520ms (baseline: 1546ms, -26ms improvement) (slow)
```

### Audit Mode
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  🏥 Dotfiles Health Check
  🔍 Audit Mode: Report Only
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  ✓ Zsh startup: 107ms (excellent)
  ⚠ [AUDIT] Multiple compinit calls detected

  ℹ  Audit mode: All issues reported as warnings
Status: Audit complete
Exit: 0
```

---

## Checks Performed

1. **Shell Startup Performance**
   - Measures Zsh/Bash startup time
   - Compares to profile thresholds
   - Shows baseline regression/improvement

2. **Required Files**
   - .zshrc, .zshenv, .bashrc, .profile
   - ~/.dotfiles directory structure

3. **Duplicate Sourcing**
   - Multiple compinit calls
   - Duplicate PATH additions
   - mise activate duplicates

4. **PATH Sanity**
   - Homebrew in PATH
   - Dotfiles bin in PATH
   - No critical PATH issues

5. **Shell Syntax**
   - Validates .zshrc syntax (Zsh)
   - Validates .bashrc syntax (Bash)

6. **Cache Status**
   - Dotfiles cache freshness
   - Cache modification time

7. **Environment Variables**
   - $HOME set correctly
   - $DOTFILES_VERSION present
   - Critical variables defined

8. **Security**
   - File permissions (.zshrc, .bashrc, etc.)
   - Directory permissions (.ssh, .gnupg)

---

## Exit Codes

| Code | Meaning | When |
|------|---------|------|
| 0 | Success | All checks passed or warnings only |
| 0 | Audit | Always in `--audit` mode |
| 1 | Failure | Errors found (not in audit mode) |

---

## Baseline Metrics

### Location
```
~/.dotfiles/metrics/startup.json
```

### Format
```json
{
  "timestamp": "2026-01-15T10:59:44Z",
  "profile": "default",
  "hostname": "rousseau-mbp-m1",
  "os": "Darwin",
  "arch": "arm64",
  "startup_times": {
    "zsh_ms": 107,
    "bash_ms": 1546
  }
}
```

### When to Update
- After major optimizations
- When changing machines
- After OS/tool upgrades
- Periodically (monthly)

---

## Workflows

### New Machine Setup
```bash
# 1. Clone dotfiles
git clone <repo> ~/.dotfiles

# 2. Audit check (don't fail)
cd ~/.dotfiles && ./scripts/doctor.sh --audit

# 3. Fix issues, install
make install

# 4. Verify
dotfiles doctor

# 5. Save baseline
dotfiles doctor --baseline
```

### Daily Development
```bash
# Check health
dotfiles doctor

# After optimization
dotfiles doctor --baseline

# Verify improvement
dotfiles doctor
```

### Server Deployment
```bash
# Use server profile (relaxed)
dotfiles doctor --profile server --audit

# Fix critical issues
dotfiles doctor --profile server

# Save server baseline
dotfiles doctor --profile server --baseline
```

### CI/CD
```bash
# Pull request (strict)
dotfiles doctor --profile ci

# Main branch (save baseline)
dotfiles doctor --baseline
```

---

## Troubleshooting

### Command not found: dotfiles
```bash
# Reload shell
exec zsh

# Or use full path
~/.dotfiles/bin/dotfiles doctor
```

### Unknown profile
```bash
# Check available profiles
dotfiles doctor --help

# Valid profiles: default, laptop, server, ci, development
```

### Baseline not found
```bash
# Create baseline first
dotfiles doctor --baseline
```

### Too strict/lenient
```bash
# Use different profile
dotfiles doctor --profile server    # More lenient
dotfiles doctor --profile ci         # More strict
```

---

## Files

- `scripts/doctor.sh` - Main health check script
- `bin/dotfiles` - CLI wrapper
- `metrics/startup.json` - Baseline metrics (generated)
- `docs/HEALTH_CHECK.md` - Full documentation
- `docs/PROFILES_AND_METRICS.md` - Profiles & metrics guide
- `.github/workflows/shell-ci.yml` - CI pipeline

---

## CI Integration

### Jobs
1. **self-check** - Validate doctor.sh itself
2. **shellcheck** - Lint all scripts
3. **syntax-validation** - Check syntax
4. **startup-performance** - Measure & compare to baseline
5. **health-check** - Run doctor with profiles
6. **security-scan** - Check permissions

### Regression Detection
- Restores baseline from cache
- Fails if regression > 50ms
- Saves new baseline on main

---

## Documentation

- **[HEALTH_CHECK.md](HEALTH_CHECK.md)** - Complete health check guide
- **[PROFILES_AND_METRICS.md](PROFILES_AND_METRICS.md)** - Profiles, metrics, audit mode, self-check
- **[ENHANCEMENTS_SUMMARY.md](ENHANCEMENTS_SUMMARY.md)** - Enhancement implementation details
- **[QUICK_REFERENCE.md](QUICK_REFERENCE.md)** - This quick reference

---

## Support

For issues or questions:
1. Check documentation above
2. Run `dotfiles doctor --help`
3. Review logs in CI
4. Check [TROUBLESHOOTING.md](../TROUBLESHOOTING.md)
