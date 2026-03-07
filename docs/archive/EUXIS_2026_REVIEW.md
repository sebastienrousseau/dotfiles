# Euxis 2026 Architecture & Product Review

This review translates the current dotfiles CLI stack into an Apple-tier product strategy:
high power, near-zero cognitive load, and cross-platform parity (macOS, Linux, WSL).

## Current state (what is already strong)

- Unified entrypoint (`dot`) with modular command routing.
- Good safety baseline (strict mode, governance, preflight checks).
- Broad CI coverage with strong shell quality gates.
- WSL support already exists but is distributed across scripts.

## Gaps to close for Apple-tier quality

### Performance and responsiveness

- `dot doctor` scans broad filesystem paths and can feel slow on large homes.
- Platform detection logic is duplicated across scripts.
- Source directory resolution repeats file system probes in hot paths.

### UX and cognitive load

- Cross-platform behavior is implicit, not surfaced as a simple product contract.
- Users still need to understand host/guest boundaries (especially WSL).
- Onboarding signal is fragmented across docs and command help.

### Product parity

- No single abstraction layer for path conversion and host-native opening.
- No first-class “platform parity” diagnostics in one section.

## Implemented in this branch

### 1) Platform abstraction layer

Added `scripts/dot/lib/platform.sh` with:

- `dot_platform_id`
- `dot_host_os`
- `dot_is_wsl`
- `dot_path_to_unix`
- `dot_path_to_native`
- `dot_open_path`

This centralizes platform semantics and removes per-script drift.

### 2) Hot-path optimization in shared utils

Updated `scripts/dot/lib/utils.sh`:

- sources `platform.sh`
- adds process-local source dir cache (`_DOT_SOURCE_DIR_CACHE`)
- avoids repeated filesystem checks in repeated command flows

### 3) Faster, clearer diagnostics

Updated `scripts/diagnostics/doctor.sh`:

- new **Platform** section (runtime + host + WSL bridge/fallback checks)
- warns when running in `/mnt/*` under WSL (high IO latency path)
- scoped symlink scan to standard roots only (`~/.config`, `~/.local`, `~/.ssh`)
- adds explicit `dot` command resolution check

### 4) Onboarding clarity

Updated `README.md`:

- added “60-second onboarding” with a clear success state

### 5) Test coverage for new abstraction

Added `scripts/tests/unit/test_dot_lib_platform.sh`:

- existence + syntax + function presence + return contract checks

## File-by-file next refactors (high ROI)

1. `scripts/dot/commands/tools.sh`
- Split `cmd_aliases` into submodule file.
- Replace repeated `command -v` checks with cached capability map.

2. `dot_config/zsh/dot_zshrc.tmpl`
- Add startup budget guard (record startup time; warn >400ms).
- Move optional integrations behind capability checks generated once/session.

3. `scripts/ops/health-check.sh`
- Import `platform.sh`, unify WSL/macOS/Linux branch logic.
- Emit machine-readable JSON summary for UI frontends.

4. `scripts/diagnostics/perf.sh`
- Add percentile reporting (P50/P95 over 10 runs).
- Add regression threshold with actionable remediation hints.

## Product roadmap (prioritized)

### P0 (1-2 weeks)

- Platform abstraction adoption across all dot commands.
- Bounded diagnostic scans everywhere (`find` scope + timeout).
- “Single-screen health” command output format harmonization.

### P1 (2-4 weeks)

- Local state model for predictive UX (`~/.local/state/dotfiles/session.json`).
- Adaptive hints (“next best action”) based on detected failures.
- Non-blocking diagnostics execution with staged rendering.

### P2 (4-8 weeks)

- Optional Rust helper binary for path/process abstraction and fast JSON output.
- WASM-compatible policy engine for deterministic config validation.
- Cross-device state sync model (privacy-first, local-first defaults).

## Apple-tier UX bar (acceptance criteria)

- First successful install + health check in under 90 seconds.
- `dot doctor` completes in under 700ms on warmed cache.
- No user-facing distinction between macOS/Linux/WSL for core commands.
- All failures return one-line remediation with direct command to fix.
