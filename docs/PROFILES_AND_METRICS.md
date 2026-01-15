# Machine Profiles & Baseline Metrics

## Quick Reference

```bash
# Standard check
dotfiles doctor

# Server profile (relaxed thresholds)
dotfiles doctor --profile server

# CI profile (strict thresholds)
dotfiles doctor --profile ci

# Audit mode (report only, never fail)
dotfiles doctor --audit

# Save baseline metrics
dotfiles doctor --baseline
```

---

## Machine Profiles

Profiles adjust performance thresholds based on your environment.

### Available Profiles

| Profile | Excellent | Good | Acceptable | Blocker | Use Case |
|---------|-----------|------|------------|---------|----------|
| **default** | 150ms | 250ms | 500ms | 1000ms | Standard desktop |
| **laptop** | 150ms | 250ms | 500ms | 1000ms | Same as default |
| **server** | 300ms | 500ms | 1000ms | 2000ms | Relaxed for servers |
| **ci** | 100ms | 200ms | 400ms | 800ms | Strict for CI/CD |
| **development** | 200ms | 300ms | 600ms | 1200ms | Dev environments |

### Setting Default Profile

```bash
# Environment variable
export DOTFILES_DOCTOR_PROFILE=server

# Add to ~/.zshrc or ~/.bashrc
echo 'export DOTFILES_DOCTOR_PROFILE=server' >> ~/.zshrc
```

### When to Use Each Profile

**default/laptop**
- Personal workstations
- Daily driver machines
- Fast startup expected

**server**
- Production servers
- Remote machines
- Slower hardware acceptable

**ci**
- Continuous integration
- Automated testing
- Strict performance requirements
- Catches regressions early

**development**
- Dev containers
- Experimental setups
- Can tolerate some overhead

---

## Baseline Metrics

Track startup time over time and detect regressions.

### How It Works

1. **Save baseline**: Captures current startup times
2. **Compare**: Future checks compare against baseline
3. **Report**: Shows delta (+18ms regression, -5ms improvement)

### Saving Baseline

```bash
# Save current performance as baseline
dotfiles doctor --baseline

# Output:
# Saving baseline metrics...
# ✓ Baseline saved to: ~/.dotfiles/metrics/startup.json
#   Zsh: 107ms
#   Bash: 95ms
```

### Baseline File Format

Location: `~/.dotfiles/metrics/startup.json`

```json
{
  "timestamp": "2026-01-15T10:30:00Z",
  "profile": "default",
  "hostname": "rousseau-mbp-m1",
  "os": "Darwin",
  "arch": "arm64",
  "startup_times": {
    "zsh_ms": 107,
    "bash_ms": 95
  }
}
```

### Viewing Comparison

```bash
dotfiles doctor

# Output includes:
# ✓ Zsh startup: 125ms (baseline: 107ms, +18ms regression) (good)
# ✓ Bash startup: 90ms (baseline: 95ms, -5ms improvement) (excellent)
```

### When to Update Baseline

- After major optimizations
- When changing machines
- After upgrading OS/tools
- Periodically (monthly)

### CI Integration

CI automatically:
- Restores baseline from cache
- Compares current vs baseline
- Fails if regression > 50ms
- Saves new baseline on main branch

---

## Audit Mode

Perfect for new machine setup - reports issues without failing.

### Use Cases

**✅ When to Use Audit Mode:**
- First time setup on new machine
- Installing dotfiles in unfamiliar environment
- Exploratory checks on shared servers
- Documentation/reporting purposes
- CI initial validation

**❌ When NOT to Use:**
- Local development (use strict mode)
- CI on main branch (use regular mode)
- After dotfiles are established

### How It Works

```bash
# Regular mode - exits 1 on errors
dotfiles doctor
# Exit code: 1 (if errors found)

# Audit mode - always exits 0
dotfiles doctor --audit
# Exit code: 0 (even with issues)
```

### Output Difference

**Regular Mode:**
```
✓ Zsh startup: 107ms (excellent)
✗ Multiple compinit calls in .zshrc (2 times)
⚠ No mise activate (or not using mise)

Status: Issues found that need attention
```
Exit: 1

**Audit Mode:**
```
✓ Zsh startup: 107ms (excellent)
⚠ [AUDIT] Multiple compinit calls in .zshrc (2 times)
⚠ No mise activate (or not using mise)

ℹ  Audit mode: All issues reported as warnings
Status: Audit complete
```
Exit: 0

### CI Usage

```yaml
# First run: audit mode (don't fail)
- name: Initial health check
  run: dotfiles doctor --audit

# Second run: strict mode (fail on errors)
- name: Strict validation
  if: matrix.profile == 'ci'
  run: dotfiles doctor --profile ci
```

---

## Self-Check

The doctor script validates itself in CI.

### What's Checked

1. **Syntax validation**: `bash -n scripts/doctor.sh`
2. **ShellCheck**: Lints for best practices
3. **Hardcoded paths**: Ensures no `/Users/` or `/home/` references
4. **Executable permission**: Verifies script is executable

### Local Self-Check

```bash
# Validate syntax
bash -n ~/.dotfiles/scripts/doctor.sh

# Run ShellCheck
shellcheck ~/.dotfiles/scripts/doctor.sh

# Check for hardcoded paths
grep -E "/Users/|/home/" ~/.dotfiles/scripts/doctor.sh | grep -v HOME
```

### CI Self-Check Job

Runs before all other jobs to ensure the checker itself is valid:

```yaml
jobs:
  self-check:
    name: Self-Check Doctor Script
    runs-on: ubuntu-latest
    steps:
      - Syntax validation
      - ShellCheck
      - Hardcoded path detection
      - Permission verification
```

---

## Complete Workflow Examples

### New Machine Setup

```bash
# 1. Clone dotfiles
git clone <repo> ~/.dotfiles

# 2. Audit check (report only)
cd ~/.dotfiles && ./scripts/doctor.sh --audit

# 3. Review issues, install dotfiles
make install

# 4. Re-check with strict mode
dotfiles doctor

# 5. Save baseline
dotfiles doctor --baseline
```

### CI/CD Pipeline

```bash
# Pull request checks
dotfiles doctor --profile ci --audit      # Initial
dotfiles doctor --profile ci              # Strict

# Main branch (save baseline)
dotfiles doctor --baseline                # Save metrics
```

### Server Deployment

```bash
# Production server (relaxed)
dotfiles doctor --profile server --audit  # First check
dotfiles doctor --profile server          # Verify

# Save server-specific baseline
dotfiles doctor --profile server --baseline
```

### Development Workflow

```bash
# Before committing changes
dotfiles doctor

# After making optimizations
dotfiles doctor --baseline               # Update baseline

# Check regression
dotfiles doctor                          # Compare to baseline
```

---

## Troubleshooting

### "Profile not found"
```bash
dotfiles doctor --profile invalid
# Error: Unknown profile 'invalid'
# Available profiles: default laptop server ci development
```
Use one of the listed profiles.

### "Baseline not found"
First run won't have a baseline. Create one:
```bash
dotfiles doctor --baseline
```

### "Metrics directory missing"
Directory is created automatically, but you can create manually:
```bash
mkdir -p ~/.dotfiles/metrics
```

### Regression Detection in CI

If CI fails with regression:
1. Check the diff in GitHub Actions logs
2. Investigate what changed
3. Optimize or update baseline if intentional:
   ```bash
   dotfiles doctor --baseline
   git add metrics/startup.json
   git commit -m "Update baseline after optimization"
   ```

---

## Best Practices

1. **Save baseline after optimizations**: `dotfiles doctor --baseline`
2. **Use strict profile in CI**: `--profile ci`
3. **Use audit mode on new machines**: `--audit`
4. **Review baseline monthly**: Ensure it's still relevant
5. **Commit baseline to repo**: Track performance over time
6. **Use server profile for servers**: Avoid false positives

---

## Reference

### All Options

```bash
dotfiles doctor --help

Options:
    --profile PROFILE    Performance profile (default, laptop, server, ci, development)
    --audit             Report only, never fail
    --baseline          Save current metrics as baseline
    --help, -h          Show help message

Environment Variables:
    DOTFILES_DOCTOR_PROFILE    Set default profile
```

### Exit Codes

- `0` - Success or warnings only (or audit mode)
- `1` - Errors found (except in audit mode)

### Files

- `~/.dotfiles/metrics/startup.json` - Baseline metrics
- `~/.dotfiles/scripts/doctor.sh` - Health check script
- `~/.dotfiles/bin/dotfiles` - CLI wrapper
