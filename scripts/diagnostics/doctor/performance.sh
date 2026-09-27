#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck shell=bash
# Performance section of dot doctor: cache freshness, uncached inits,
# zcompdump, PATH length, shell coverage, zsh hooks, perf baseline.
# Sourced by scripts/diagnostics/doctor.sh; uses its helpers and globals.

# _doctor_cache_stale <tool> <bin>: true when any shell's _cached_eval init
# cache for <tool> is missing or older than the tool's binary.
_doctor_cache_stale() {
  local tool="$1" bin="$2" sh cache
  for sh in zsh bash fish; do
    cache="$cache_base/$sh/$tool-init.$sh"
    if [[ ! -f "$cache" || "$bin" -nt "$cache" ]]; then
      return 0
    fi
  done
  return 1
}

# _doctor_has_init_cache <tool>: true when some shell has an init cache.
_doctor_has_init_cache() {
  local sh
  for sh in zsh bash fish; do
    if [[ -f "$cache_base/$sh/$1-init.$sh" ]]; then
      return 0
    fi
  done
  return 1
}

# _doctor_init_referenced <tool>: true when shell config evals or sources the
# tool's init (`<tool> env|init|hook`, `<tool>.sh`, or a lazy-load stub).
# A tool nothing initialises adds no startup cost.
_doctor_init_referenced() {
  grep -rIlqE "\\b$1([[:space:]]+(env|init|hook)|\\.sh|_lazy_load_$1|_dot_lazy[[:space:]]+$1)" \
    "$HOME/.config/zsh" "$HOME/.config/fish" "$HOME/.config/shell" 2>/dev/null
}

# _doctor_lazy_stubbed <tool>: fnm/nvm/sdkman loaded through a lazy shell
# stub need no init cache.
_doctor_lazy_stubbed() {
  case "$1" in
    fnm | nvm | sdkman)
      grep -rIlqE "_lazy_load_$1|_dot_lazy[[:space:]]+$1" "$HOME/.config/zsh" "$HOME/.config/fish" 2>/dev/null
      ;;
    *) return 1 ;;
  esac
}

# --- Performance ---
# 1. Shell cache freshness for tools the project already wraps in _cached_eval.
# Stale caches force runtime regeneration on next shell start.
_doctor_perf_cache_freshness() {
  local tool bin
  stale_caches=0
  stale_tools=""
  for tool in mise starship zoxide atuin fzf direnv; do
    bin="$(command -v "$tool" 2>/dev/null || true)"
    [[ -n "$bin" ]] || continue
    _doctor_cache_stale "$tool" "$bin" || continue
    stale_caches=$((stale_caches + 1))
    stale_tools="${stale_tools:+$stale_tools, }$tool"
  done
  if [[ $stale_caches -eq 0 ]]; then
    caches_fresh="fresh"
    _ok "shell caches" "fresh"
  else
    caches_fresh="stale"
    _warn "shell caches" "stale ($stale_tools) — run dot prewarm"
  fi
}

# 2. Slow-init tools that are present but NOT wrapped in _cached_eval.
# Each of these runs uncached on every shell start; common offenders eat
# 100-500ms apiece on a populated dev machine.
#
# Only flag tools that actually emit shell init via `<tool> init <shell>`
# (or equivalent) and would benefit from caching that output. Plain CLIs
# like gh/cargo/pnpm/yarn don't have init eval; their completions are
# cached separately under $ZSH_COMPLETIONS_DIR.
_doctor_perf_uncached_inits() {
  local tool unwrapped=""
  for tool in nvm fnm pyenv rbenv jenv asdf sdkman conda kubectl helm thefuck broot mcfly direnv; do
    command -v "$tool" >/dev/null 2>&1 || continue
    _doctor_init_referenced "$tool" || continue
    _doctor_lazy_stubbed "$tool" && continue
    _doctor_has_init_cache "$tool" && continue
    unwrapped="${unwrapped:+$unwrapped, }$tool"
  done
  if [[ -z "$unwrapped" ]]; then
    _ok "uncached slow-init tools" "none detected"
  else
    _warn "uncached slow-init tools" "$unwrapped — consider wrapping in _cached_eval"
  fi
}

# 3. Zsh completion dump health. compinit is usually the single biggest
# cost on a zsh startup; a stale or uncompiled .zcompdump compounds it.
_doctor_perf_zcompdump() {
  if command -v zsh >/dev/null 2>&1; then
    zcompdump="${HOME}/.zcompdump"
    if [[ -f "$zcompdump" ]]; then
      dump_mtime=$(stat -c %Y "$zcompdump" 2>/dev/null || stat -f %m "$zcompdump" 2>/dev/null || echo 0)
      age_days=$((($(date +%s) - dump_mtime) / 86400))
      if ((age_days > 7)); then
        _warn ".zcompdump" "${age_days}d old — refresh: rm ~/.zcompdump* && zsh -ic exit"
      else
        _ok ".zcompdump" "fresh (${age_days}d)"
      fi
      if [[ ! -f "${zcompdump}.zwc" ]]; then
        _warn ".zcompdump.zwc" "missing — completion init slower than necessary"
      fi
    fi
  fi
}

# 4. PATH length. Each entry is searched on every command resolution.
# A mise-managed 2026 dev machine routinely adds 60-90 entries (one per
# installed tool version + per-shim path), so the warn/fail thresholds
# reflect that baseline rather than a lean default (~40).
#
# The OK ceiling was 75, which contradicted the 60-90 baseline stated right
# above it and warned on every healthy mise machine. Worse, the implied remedy
# was backwards: those per-tool entries are what let a command resolve to the
# real binary instead of falling through to a mise shim. Measured 2026-08-20,
# 20 invocations of ripgrep --version:
#
#     via shim            2741ms   (137ms per call)
#     direct install dir    62ms   (3.1ms per call)
#
# ~44x. "Pruning" those entries to satisfy a length check would trade
# microseconds of PATH scan for ~134ms on every single tool invocation. The
# ceiling now matches the documented baseline; >90 still warns, because past
# that the entries are worth auditing for tools you no longer use.
#
# The thresholds apply to the entries that are NOT mise tool directories:
# those are by design (see above), so a machine with many mise tools is not
# "long". A PATH of 88 entries, 68 of them mise installs, used to warn. The
# message still reports the total, then the mise share. Duplicates are
# pure waste, so any warn regardless of length.
_doctor_perf_path_length() {
  path_count=$(printf '%s' "${PATH:-}" | tr ':' '\n' | grep -c . || true)
  path_unique=$(printf '%s' "${PATH:-}" | tr ':' '\n' | grep . | sort -u | grep -c . || true)
  path_mise=$(printf '%s' "${PATH:-}" | tr ':' '\n' | grep . | sort -u | grep -c '/mise/installs/' || true)
  path_other=$((path_unique - path_mise))
  path_dups=$((path_count - path_unique))
  path_detail="$path_count entries"
  [[ "$path_mise" -gt 0 ]] && path_detail="$path_detail ($path_mise mise tool dirs, $path_other other)"
  if [[ "$path_other" -gt 120 ]]; then
    _fail "PATH length" "$path_detail — likely slowing every command"
  elif [[ "$path_other" -gt 90 ]]; then
    _warn "PATH length" "$path_detail — consider pruning"
  elif [[ "$path_dups" -gt 0 ]]; then
    _warn "PATH length" "$path_detail — $path_dups duplicate(s)"
  else
    _ok "PATH length" "$path_detail"
  fi
}

# 5. Shell coverage. Surface installed shells that the project's caching
# infrastructure doesn't currently maintain caches for.
_doctor_perf_shell_coverage() {
  shells_unmanaged=""
  for sh in nu pwsh; do
    command -v "$sh" >/dev/null 2>&1 || continue
    case "$sh" in
      nu)
        [[ -f "$HOME/.config/nushell/cached_eval.nu" ]] && continue
        ;;
      pwsh)
        pwsh -NoLogo -NoProfile -NonInteractive -Command 'exit 0' >/dev/null 2>&1 || continue
        pwsh_profile="$HOME/.config/powershell/Microsoft.PowerShell_profile.ps1"
        [[ -f "$pwsh_profile" ]] && grep -q 'Get-DotfilesCachedInit' "$pwsh_profile" && continue
        ;;
    esac
    shells_unmanaged="${shells_unmanaged:+$shells_unmanaged, }$sh"
  done
  if [[ -z "$shells_unmanaged" ]]; then
    _ok "shell coverage" "all installed shells have _cached_eval support"
  else
    _warn "shell coverage" "$shells_unmanaged installed — no _cached_eval helper"
  fi
}

# 6. Zsh hook count. Heavy precmd/preexec functions compound per-prompt.
# Probe an interactive zsh with a hard timeout so a broken zshrc doesn't
# stall doctor; skip cleanly if the probe fails.
_doctor_perf_zsh_hooks() {
  if command -v zsh >/dev/null 2>&1 && command -v timeout >/dev/null 2>&1; then
    # Fire every hook once first, as the first prompt and first command do:
    # the deferred-init hooks deregister themselves after one run, so counting
    # at startup reported one-shot work (zinit, compinit, carapace, layer
    # loading) as per-prompt cost. What remains is what runs on every prompt.
    # shellcheck disable=SC2016 # expanded by the probed zsh
    hook_counts=$(timeout 5 zsh -i -c 'local -a _p _e; _p=($precmd_functions); _e=($preexec_functions)
    for f in $_p; do (( $+functions[$f] )) && $f >/dev/null 2>&1; done
    for f in $_e; do (( $+functions[$f] )) && $f true >/dev/null 2>&1; done
    echo "$#precmd_functions $#preexec_functions"' 2>/dev/null | tail -1 || echo "")
    if [[ -n "$hook_counts" ]]; then
      read -r precmd_n preexec_n <<<"$hook_counts"
      if [[ "${precmd_n:-0}" -le 5 && "${preexec_n:-0}" -le 5 ]]; then
        _ok "zsh hooks" "precmd=$precmd_n preexec=$preexec_n"
      else
        _warn "zsh hooks" "precmd=$precmd_n preexec=$preexec_n — heavy per-prompt work"
      fi
    fi
  fi
}

# Startup latency against benches/bench.sh thresholds (needs hyperfine).
_doctor_perf_startup_latency() {
  if command -v hyperfine >/dev/null 2>&1; then
    if bash "$SCRIPT_DIR/../../benches/bench.sh" 2>/dev/null; then
      _ok "startup latency" "within target thresholds"
    else
      # Only suggest prewarm when it could actually help. The caches were
      # already reported fresh above in the common case, and telling someone to
      # re-run a no-op sends them in a circle — as it did on 2026-08-20, where
      # prewarm changed nothing because nothing was cold.
      if [[ "${caches_fresh:-unknown}" == "fresh" ]]; then
        _warn "startup latency" "threshold exceeded (caches already fresh — profile with 'dot benchmark')"
      else
        _warn "startup latency" "threshold exceeded (run dot prewarm)"
      fi
    fi
  else
    _warn "hyperfine" "missing (benchmark skipped)"
  fi
}

# 7. Baseline check + top-3 slowest tools from EVALCACHE_TIMING.
# Closes part of #863. Reads the same baseline file `dot perf` writes,
# and the same eval-timings.jsonl _cached_eval populates. Skipped
# silently when either file is absent (first-run state).
_doctor_perf_baseline() {
  baseline_file="$cache_base/dotfiles/perf-baseline.json"
  if [[ -s "$baseline_file" ]] && command -v python3 >/dev/null 2>&1; then
    baseline_age_days=$(python3 -c '
import json, sys, datetime
try:
    d = json.load(open(sys.argv[1]))
    rec = d.get("recorded_at", "")
    if not rec: print(-1); sys.exit(0)
    rec = rec.replace("Z", "+00:00")
    age = (datetime.datetime.now(datetime.timezone.utc) - datetime.datetime.fromisoformat(rec)).days
    print(age)
except Exception:
    print(-1)
' "$baseline_file" 2>/dev/null)
    if [[ "$baseline_age_days" -ge 0 ]]; then
      _ok "perf baseline" "recorded ${baseline_age_days}d ago — run \`dot perf\` to compare"
    fi
  fi

  timings_file="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/eval-timings.jsonl"
  if [[ -s "$timings_file" ]] && command -v python3 >/dev/null 2>&1; then
    top_tools=$(python3 -c '
import json, sys
from collections import defaultdict
samples = defaultdict(list)
try:
    for line in open(sys.argv[1]):
        try:
            ev = json.loads(line)
            ms = int(ev.get("ms", 0) or 0)
            samples[ev.get("label", "?")].append(ms)
        except Exception:
            pass
    rows = sorted(samples.items(), key=lambda kv: sum(kv[1]) // max(len(kv[1]), 1), reverse=True)[:3]
    print(", ".join(f"{lbl}({sum(v)//max(len(v),1)}ms)" for lbl, v in rows))
except Exception:
    pass
' "$timings_file" 2>/dev/null)
    if [[ -n "$top_tools" ]]; then
      _ok "perf top-tools" "$top_tools"
    fi
  fi
}

_doctor_performance() {
  _section "Performance"

  cache_base="${XDG_CACHE_HOME:-$HOME/.cache}"

  _doctor_perf_cache_freshness
  _doctor_perf_uncached_inits
  _doctor_perf_zcompdump
  _doctor_perf_path_length
  _doctor_perf_shell_coverage
  _doctor_perf_zsh_hooks
  _doctor_perf_startup_latency
  _doctor_perf_baseline
}
