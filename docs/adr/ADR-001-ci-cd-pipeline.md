# ADR-001: Multi-stage CI/CD Pipeline Design

**Status**: Accepted
**Date**: 2026-02-09
**Authors**: @sebastienrousseau

## Context

The dotfiles repository requires a CI/CD pipeline that:
- Validates changes across multiple platforms (Linux, macOS)
- Runs security scans to detect secrets and vulnerabilities
- Tests shell scripts, Lua configurations, and Nix expressions
- Maintains fast feedback loops for developers
- Minimizes GitHub Actions costs (runner minutes)

Traditional approaches run all checks on every commit, leading to:
- Wasted compute on unrelated changes (e.g., running Lua linting when only docs change)
- High costs from macOS runners ($0.08/min vs $0.008/min for Linux)
- Long feedback times from sequential job execution

## Decision

Implement a **5-stage progressive CI pipeline** with path-based filtering:

### Stage 1: Change Detection
Use `dorny/paths-filter` to detect which file categories changed:
- `shell`: *.sh, scripts/**, install/**
- `lua`: dot_config/nvim/**, *.lua
- `nix`: nix/**, *.nix
- `config`: dot_*/**, .chezmoitemplates/**

### Stage 2: Lint (Parallel, Conditional)
- **lint-shell**: Only runs if shell files changed
- **lint-lua**: Only runs if Lua files changed
- Run in parallel to minimize wall-clock time

### Stage 3: Security (Always on PRs)
- **secrets-scan**: Gitleaks on every PR (critical)
- **link-check**: Only on schedule (expensive)

### Stage 4: Test (Conditional Matrix)
- Linux-only for PRs (cheapest)
- Full matrix (Linux + macOS) on schedule/manual trigger
- Docker container tests for installation validation

### Stage 5: Quality (Schedule/Manual Only)
- Idempotency verification
- Performance benchmarks
- Nix flake checks

### Cost Optimization Strategies

1. **Path filters**: Skip jobs when files don't match
2. **Concurrency groups**: Cancel in-progress runs on new pushes
3. **Conditional matrices**: Expensive OS testing only on schedule
4. **Aggressive caching**: Tools, dependencies, databases

## Consequences

### Positive
- ~50% reduction in GitHub Actions minutes
- Fast feedback for most changes (1-3 minutes)
- Comprehensive testing still available via schedule/manual
- Clear separation of concerns between stages

### Negative
- Complexity in workflow configuration
- Some bugs might only surface in scheduled runs
- Path filter maintenance required as repo structure evolves

### Neutral
- Developers can trigger full CI manually with `workflow_dispatch`
- Breaking changes to CI require testing across all stages

## Implementation

```yaml
# Key patterns used
on:
  push:
    paths:
      - '**.sh'  # Only trigger on shell changes

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  changes:
    outputs:
      shell: ${{ steps.filter.outputs.shell }}

  lint-shell:
    needs: changes
    if: needs.changes.outputs.shell == 'true'
```

## References

- [GitHub Actions Path Filtering](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions#onpushpull_requestpull_request_targetpathspaths-ignore)
- [dorny/paths-filter](https://github.com/dorny/paths-filter)
