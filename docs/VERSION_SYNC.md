# Version Synchronization System

The version synchronization system ensures that all version references across the repository remain consistent with the version specified in `package.json`.

## Overview

### Problem Statement
Large repositories often have version numbers scattered across multiple files:
- README badges
- Documentation headers
- Feature version stamps
- Configuration files

Manually keeping these synchronized is error-prone and time-consuming.

### Solution Architecture
This system provides automated version synchronization through:
1. **CI/CD Workflow** (`.github/workflows/sync-versions.yml`) - Automated synchronization on version changes
2. **Local Script** (`scripts/version-sync.sh`) - Manual synchronization and verification
3. **Verification System** - Ensures all references remain consistent

## Components

### 1. GitHub Actions Workflow

**Location**: `.github/workflows/sync-versions.yml`

**Triggers**:
- Push to `master` branch when `package.json` changes
- Pull requests affecting `package.json`
- Manual dispatch with optional target version

**Process**:
1. **Detect Changes** - Compares current vs previous `package.json` version
2. **Sync Versions** - Updates all markdown files with version references
3. **Verify Consistency** - Ensures all references match target version
4. **Commit & Push** - Automatically commits changes (except on PRs)

**Features**:
- Backup creation before changes
- Comprehensive change reporting
- PR comment integration
- Artifact preservation for rollback

### 2. Local Synchronization Script

**Location**: `scripts/version-sync.sh`

**Usage**:
```bash
# Sync to current package.json version
./scripts/version-sync.sh

# Sync to specific version
./scripts/version-sync.sh 1.2.3

# Preview changes without applying
./scripts/version-sync.sh --dry-run

# Verify current consistency
./scripts/version-sync.sh --verify
```

**Options**:
- `--dry-run` - Preview changes without applying
- `--verify` - Check version consistency only
- `--backup` / `--no-backup` - Control backup creation
- `--force` - Force sync even if no changes detected

### 3. Version Patterns

The system recognizes and updates these patterns:

#### README.md
```markdown
[![Version](https://img.shields.io/badge/Version-v0.2.485-blue?style=for-the-badge)]
```

#### Documentation Files
```markdown
**Version**: v0.2.485
**Dotfiles Version**: v0.2.485
Version: v0.2.485
version 0.2.485
```

## Integration Points

### CI/CD Pipeline Integration

The workflow integrates with the existing CI pipeline:

```yaml
# Existing CI workflow can depend on version sync
needs: [sync-versions, lint-shell, test-linux]
```

### Git Hooks Integration

For local development, add to `.git/hooks/pre-commit`:

```bash
#!/bin/bash
# Check version consistency before commits
./scripts/version-sync.sh --verify || {
    echo "Version inconsistency detected. Run: ./scripts/version-sync.sh"
    exit 1
}
```

### Package.json Integration

Version changes in `package.json` automatically trigger synchronization:

```json
{
  "name": "@sebastienrousseau/dotfiles",
  "version": "0.2.485",  // Changes here trigger sync
  "scripts": {
    "version-sync": "./scripts/version-sync.sh",
    "version-verify": "./scripts/version-sync.sh --verify"
  }
}
```

## Workflow Examples

### Scenario 1: Version Bump
```bash
# Developer updates package.json version
npm version patch

# Push to master
git push origin master

# GitHub Actions automatically:
# 1. Detects version change
# 2. Updates all markdown files
# 3. Commits and pushes changes
# 4. Verifies consistency
```

### Scenario 2: PR Review
```bash
# PR with package.json changes
# GitHub Actions automatically:
# 1. Checks version consistency
# 2. Reports any mismatches
# 3. Comments on PR with sync status
# 4. Provides diff preview
```

### Scenario 3: Manual Sync
```bash
# Local development
./scripts/version-sync.sh --dry-run  # Preview changes
./scripts/version-sync.sh            # Apply changes
./scripts/version-sync.sh --verify   # Confirm consistency
```

## File Detection Logic

### Automatic Discovery
The system automatically discovers files containing version references:
```bash
rg -l "v?[0-9]+\.[0-9]+\.[0-9]+" --type md
```

### Known Files
These files are always included even if they don't currently contain versions:
- `README.md`
- `docs/FEATURES.md`
- Any file matching version patterns

### Exclusions
Files that are intentionally excluded:
- `CHANGELOG.md` - May contain historical versions
- `package.json` - Source of truth
- `docs/COMPLIANCE.md` - Includes external compliance spec versions
- `docs/FONTS.md` - Includes upstream font release versions
- `docs/LEGACY_ROADMAP.md` - Keeps historical release markers
- `docs/PLAN.md` - Captures multi-release planning references
- `docs/VERSION_SYNC.md` - Documentation examples and usage
- `docs/WALKTHROUGH.md` - Contains environment-specific tag examples
- `docs/WSL2_NIX_TROUBLESHOOTING.md` - Contains IP addresses and version-like values
- Binary files
- Test fixtures

## Error Handling

### Common Issues

#### Version Mismatch
```
❌ Found inconsistent release in docs/FEATURES.md: vX.Y.Z (expected: vA.B.C)
```
**Solution**: Run `./scripts/version-sync.sh` to fix

#### Missing Dependencies
```
❌ jq is required but not installed
```
**Solution**: Install dependencies (`jq`, `rg`)

#### Permission Issues
```
❌ Permission denied writing to README.md
```
**Solution**: Check file permissions and Git status

### Recovery Procedures

#### Rollback Changes
```bash
# Restore from backup
cp .version-sync-backup/README.md.*.backup README.md

# Or restore from Git
git checkout HEAD~1 -- README.md
```

#### Force Resync
```bash
./scripts/version-sync.sh --force
```

## Monitoring & Maintenance

### Health Checks
```bash
# Daily verification (add to cron)
./scripts/version-sync.sh --verify || echo "Version drift detected"
```

### Metrics Tracking
The GitHub Actions workflow provides metrics:
- Files scanned
- Files updated
- Verification status
- Processing time

### Backup Strategy
- Local backups in `.version-sync-backup/`
- GitHub Actions artifacts (30-day retention)
- Git history for rollback

## Security Considerations

### Token Permissions
```yaml
permissions:
  contents: write      # Required for commits
  pull-requests: write # Required for PR comments
```

### Validation
- Version format validation (`x.y.z` pattern)
- File path validation (no directory traversal)
- Change verification before commit

### Audit Trail
- All changes logged in Git history
- GitHub Actions run history
- Backup preservation

## Performance Optimization

### Caching Strategy
- Git operations use shallow fetch when possible
- Pattern compilation cached
- File discovery optimized with `ripgrep`

### Parallel Processing
- File processing is sequential but optimized
- Git operations batched
- Verification runs concurrently with updates

### Resource Usage
- Typical run time: 30-60 seconds
- Memory usage: <100MB
- Network usage: Minimal (only Git operations)

## Future Enhancements

### Planned Features
1. **Smart Version Detection** - Semantic version awareness
2. **Template Support** - Custom version patterns
3. **Multi-Format Support** - YAML, JSON, TOML files
4. **Rollback Automation** - One-command rollback
5. **Integration Testing** - End-to-end workflow tests

### Extension Points
- Custom pattern definitions
- File-specific update rules
- Pre/post-sync hooks
- External validation services

## Troubleshooting

### Debug Mode
```bash
# Enable verbose output
DEBUG=1 ./scripts/version-sync.sh --dry-run
```

### Common Solutions
| Issue | Solution |
|-------|----------|
| Script not executable | `chmod +x scripts/version-sync.sh` |
| Missing tools | `apt install jq ripgrep` (Ubuntu) |
| Permission denied | Check Git status and file permissions |
| Workflow not triggering | Verify `package.json` changes are in push |
| Changes not committed | Check branch protection rules |

### Log Analysis
```bash
# View GitHub Actions logs
gh run list --workflow=sync-versions.yml
gh run view <run-id> --log
```

## Contributing

### Testing Changes
```bash
# Test local changes
./scripts/version-sync.sh --dry-run

# Test workflow changes (requires GitHub CLI)
gh workflow run sync-versions.yml --ref feature-branch
```

### Adding New Patterns
1. Update pattern regex in script
2. Add test cases
3. Update documentation
4. Submit PR with examples

---

**Last Updated**: 2026-02-15
**Version**: v0.2.485
**Maintainer**: Principal Automation Engineer
**Status**: Production Ready ✅
