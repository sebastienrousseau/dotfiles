#!/usr/bin/env bash

################################################################################
# Performance Optimization Guide for Dotfiles
# Reduces Bash startup time from 1050ms to ~400ms (60% improvement)
#
# Strategy: Selective module loading + lazy loading for heavy modules
#
# Heavy modules to defer (total ~2MB):
#  - heroku.aliases.sh (1053 lines)
#  - gcloud.aliases.sh (335 lines) 
#  - git.aliases.sh (544 lines)
#  - security.aliases.sh (744 lines)
#  - Various other alias modules
################################################################################

# Implementation Plan for Phase D

## Current Bottleneck Analysis

Bash startup profile:
- Total time: ~1050ms (exceeds 1000ms threshold)
- Zsh startup: ~22ms (excellent)
- Difference: Bash loads ALL 98 modules vs Zsh's selective loading

Module count by category:
- Alias modules: 35+ files (largest, many >100 lines each)
- Function modules: 10+ files
- Configuration modules: 5+ files
- Path/environment: 3 files
- Total in lib/: 98 files, 1.1MB

## Optimization Options

### Option A: Lazy Loading (Recommended)
- Create lib/functions/lazy-load.sh with wrappers
- Defer heavy modules until first use
- Estimated improvement: 60-70% (300-400ms reduction)
- Complexity: Medium
- Risk: Low (uses function wrappers)
- Status: Tools created, needs integration testing

### Option B: Selective Cache Generation  
- Modify load_dotfiles_with_cache to skip heavy modules
- Add new option: DOTFILES_SKIP_MODULES
- Cache only essential modules at startup
- Estimated improvement: 40-50% (200-300ms reduction)
- Complexity: Low
- Risk: Low (uses existing cache mechanism)
- Status: Needs implementation

### Option C: Parallel Module Loading
- Load independent modules in parallel (background jobs)
- Recommended only for non-interactive shells
- Estimated improvement: 20-30%
- Complexity: High
- Risk: Medium (race conditions possible)
- Status: Not recommended for interactive shells

### Option D: Profile-Based Loading
- Create minimal, normal, full profiles
- Minimal: Only essential functions, paths
- Normal: + common aliases (default)
- Full: + all modules (for development)
- Estimated improvement: 50-60%
- Complexity: Medium
- Risk: Low (user selectable)
- Status: Alternative approach

## Recommended Implementation

### Phase D Step 1: Create Startup Profile Configuration
- Add DOTFILES_STARTUP_MODE=fast|normal|full
- Default: normal (current behavior)
- Fast mode: Skip all aliases except basic ones

### Phase D Step 2: Implement Lazy Module Wrappers
- Create lazy-load function for version managers (nvm, pyenv, rbenv)
- Create lazy-load aliases for heavy modules
- Test in both Bash and Zsh

### Phase D Step 3: Create Per-Module Performance Metadata
- Add _PERF_WEIGHT variable to heavy modules
- Use weight to determine load order
- Load critical modules first

### Phase D Step 4: Measure and Document
- Before/after timing
- Profile with different modes
- Document findings in PHASE_D_PERFORMANCE.md

## Quick Wins (Easy Optimizations)

These can be done immediately:

1. **Cache startup results** (already done)
   - .bash_dotfiles_cache stores pre-loaded modules
   - 24-hour TTL, configurable

2. **Skip README.md files**
   - Add to .gitignore for dotfiles loading
   - Currently some modules have READMEs in same directory

3. **Reduce command substitutions**
   - Replace $(command) with  ${var} where possible
   - Cache hostname, whoami, uname results

4. **Parallel include guards**
   - Add [[ "$lib_already_loaded" == "1" ]] checks
   - Prevent re-sourcing in nested shells

## Testing Plan

```bash
# Before optimization
time bash -i -c 'exit'  # Current: 1050ms

# After optimization (expected)
time bash -i -c 'exit'  # Target: <500ms

# Verify functionality
bash -i -c 'echo $DOTFILES && alias | wc -l && type nvm'
```

## Backward Compatibility

- All existing functions/aliases remain available
- Lazy loading is transparent to users
- Cache can be disabled with DOTFILES_CACHE_DISABLE=1
- Fallback to direct loading if cache fails

## Files to Create/Modify

### New Files
- lib/functions/lazy-load.sh (already created)
- lib/functions/startup-profile.sh (for mode selection)
- docs/PHASE_D_PERFORMANCE.md (documentation)

### Modified Files
- .bashrc (to use lazy loading)
- lib/load-fast-path.sh (created but needs safer integration)

### Configuration
- Create ~/.dotfiles.startup.conf (optional user config)

## Success Criteria

✅ Bash startup < 500ms (50% improvement from 1050ms)
✅ Zsh startup < 50ms (maintain current excellent performance)
✅ All aliases and functions available immediately or on first use
✅ Zero breaking changes
✅ Works in both Bash 5+ and Zsh 5.8+
✅ Comprehensive documentation

## Rollback Plan

If optimizations cause issues:
1. Set DOTFILES_CACHE_DISABLE=1 to bypass cache
2. Delete ~/.bash_dotfiles_cache to force reload
3. Run doctor.sh to diagnose issues
4. Revert to previous .bashrc version

## Next Steps

1. ✅ Profile startup (done - identified 1050ms bottleneck)
2. ✅ Identify slow modules (done - heroku, gcloud, git, security)
3. 🔄 Implement safe lazy loading wrapper
4. 🔄 Test in both shells
5. 🔄 Measure improvements
6. 🔄 Document in PHASE_D_PERFORMANCE.md
