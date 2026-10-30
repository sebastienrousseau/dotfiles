---
render_with_liquid: false
---

# Version Synchronization System

The version synchronization system ensures that all live version references
remain consistent with `dotfiles_version` in
`defaults/.chezmoidata.toml`. That manifest is the only hand-edited source;
`package.json`, CLI metadata, discovery cards, and current documentation are
generated release surfaces.

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

1. **CI/CD Workflow** (`.github/workflows/sync-versions.yml`) - Verification on `main` and PRs, automated synchronization on `feat/v*` branches
2. **Local Script** (`scripts/version-sync.sh`) - Manual synchronization and verification
3. **Verification System** - Ensures all references remain consistent

## Components

### 1. GitHub Actions Workflow

**Location**: `.github/workflows/sync-versions.yml`

**Triggers**:

- Push to `main` or a `feat/v*` branch that touches any markdown file, `package.json`, `defaults/.chezmoidata.toml`, `install.sh`, `scripts/version-sync.sh`, `scripts/verify-release-versions`, `scripts/release-preflight` or this document
- Pull requests to `main` touching the same paths
- Manual dispatch with optional target version

**Jobs**:

| Event | Job | What it does |
|---|---|---|
| Pull request | `verify` | `./scripts/version-sync.sh --verify`; fails on any mismatch. |
| Push to `main` (or dispatch on `main`) | `verify-protected` | The same check. It never commits to `main`. |
| Push to `feat/v*` (or dispatch on any other ref) | `sync` | Reads the target version (the dispatch input, else `dotfiles_version` from `defaults/.chezmoidata.toml`), runs `./scripts/version-sync.sh`, and if anything changed commits it, SSH-signed with `ACTIONS_BOT_SIGNING_KEY` and DCO-signed-off, as `chore: sync version references to vX.Y.Z`, then pushes to that branch. |

The workflow posts no PR comments and uploads no artifacts; the
script's summary and any mismatches are in the job log.

### 2. Local Synchronization Script

**Location**: `scripts/version-sync.sh`

**Usage**:

```bash
# Sync to the canonical dotfiles_version
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
[![Version](https://img.shields.io/badge/Version-v0.2.501-blue?style=for-the-badge)]
```

#### Documentation Files

```markdown
**Version**: v0.2.503
**Dotfiles Version**: v0.2.503
Version: v0.2.503
version 0.2.485
```

## Integration Points

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

### Canonical Manifest Integration

Change the version explicitly through the synchronizer; it updates the
canonical manifest and regenerates `package.json` in the same operation:

```bash
./scripts/version-sync.sh 0.2.522
./scripts/release-preflight --require-untagged
```

## Workflow Examples

### Scenario 1: Version Bump

```bash
# Developer updates the canonical manifest and all generated surfaces
./scripts/version-sync.sh 0.2.522

# On a feat/v* branch, GitHub Actions then:
# 1. Re-runs the sync against the canonical version
# 2. Commits and pushes any remaining changes to the branch
#
# On main (and on the PR), it only verifies and fails on a mismatch.
```

### Scenario 2: PR Review

```bash
# PR with version-surface changes
# GitHub Actions automatically:
# 1. Runs ./scripts/version-sync.sh --verify
# 2. Fails the check and logs each mismatch
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

These files are always included even if they don't currently contain versions
(the non-markdown and hidden-directory surfaces the `rg --type md` scan cannot
reach):

- `README.md`
- `docs/reference/FEATURES.md`
- `docs/COPYRIGHT`
- `scripts/git-hooks/pre-commit-audit.sh`
- `defaults/.chezmoitemplates/README.md`, `functions/README.md` and `aliases/README.md`

`package.json` is not scanned; the script sets its `version` field directly.

The discovery cards (`.well-known/agent-card.json`,
`.well-known/mcp/server-card.json`, `defaults/dot_config/dotfiles/agent-card.json`)
get their top-level `version`, and each plugin manifest
(`plugins/*/dot-plugin.toml`) its `version =` line, never an alias's
`until`. The Go binaries (`dot-ui`, `dot-mcp`) keep no version in their
source: the build injects `dotfiles_version` with
`-ldflags "-X main.version=..."`, so `--version` and the MCP handshake report
the framework version without a sync.

### Exclusions

The authoritative list is the `EXCLUDE_FILES` array at the top of
`scripts/version-sync.sh`, each entry with a comment saying why. It
covers history (`CHANGELOG.md`, `docs/archive/*`, `docs/articles/*`,
`ROADMAP.md`), every file under `docs/operations/` (this document
included), third-party and per-release version tables (for example
`docs/reference/FONTS.md`, `docs/security/COMPLIANCE.md`,
`docs/security/VERIFY_RELEASE.md`, `pkg/VERIFY.md`) and files deployed
into `$HOME` that quote other projects' versions (`defaults/Code/*`).
Only markdown files are scanned, so binaries and non-markdown fixtures
never match.

## Error Handling

### Common Issues

#### Version Mismatch

```text
❌ Found inconsistent release in docs/reference/FEATURES.md: vX.Y.Z (expected: vA.B.C)
```

**Solution**: Run `./scripts/version-sync.sh` to fix

#### Optional Dependencies

Neither tool is required: without `rg` the script finds markdown files
with `find` and `grep`, and without `jq` it rewrites the `package.json`
version with `sed`. CI installs both.

#### Permission Issues

```text
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

### Run Summary

Each sync ends with a summary in the log: target version, files
updated, whether a backup was made, and the verification result.

### Backup Strategy

- Local backups in `.version-sync-backup/` (replaced on every run)
- Git history for rollback

## Security Considerations

### Token Permissions

```yaml
permissions:
  contents: read       # top level, and for both verify jobs
# sync job only:
#   contents: write    # commit + push the version-bump diff
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

The script has no debug flag of its own; trace it with bash:

```bash
bash -x ./scripts/version-sync.sh --dry-run
```

### Common Solutions

| Issue | Solution |
|-------|----------|
| Script not executable | `chmod +x scripts/version-sync.sh` |
| Slow file discovery | `apt install ripgrep` (Ubuntu); `jq` is optional too |
| Permission denied | Check Git status and file permissions |
| Workflow not triggering | Check the push touches one of the trigger paths above |
| Changes not committed | Commits are made only on `feat/v*` pushes and non-`main` dispatches, never on `main` or PRs |

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
**Version**: v0.2.503
**Maintainer**: Principal Automation Engineer
**Status**: Production Ready ✅
