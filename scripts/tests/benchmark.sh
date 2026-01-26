#!/usr/bin/env bash

# standard-benchmarks.sh
# Measures shell startup time (total and per-component).
# Optional threshold enforcement via DOTFILES_BENCH_MAX_MS.

set -euo pipefail

log_info() { echo -e "\n[INFO] $*"; }

MAX_MS="${DOTFILES_BENCH_MAX_MS:-}"

# ── Section 1: Total startup benchmark ──────────────────────────
log_info "=== Total Startup Benchmark ==="

if command -v hyperfine >/dev/null; then
  log_info "Running benchmark with hyperfine..."
  tmp_json="$(mktemp)"
  hyperfine --warmup 3 --min-runs 10 --export-json "$tmp_json" "zsh -i -c exit"

  if [[ -n "$MAX_MS" ]] && command -v python3 >/dev/null; then
    python3 - "$tmp_json" "$MAX_MS" <<'PY'
import json, sys
path, max_ms = sys.argv[1], float(sys.argv[2])
with open(path, "r", encoding="utf-8") as f:
    data = json.load(f)
mean_s = data["results"][0]["mean"]
mean_ms = mean_s * 1000.0
print(f"[INFO] Mean startup: {mean_ms:.1f} ms (limit: {max_ms:.1f} ms)")
if mean_ms > max_ms:
    print(f"[FAIL] Startup time exceeded limit: {mean_ms:.1f} ms > {max_ms:.1f} ms")
    sys.exit(1)
PY
  fi
  rm -f "$tmp_json"
else
  log_info "Hyperfine not found. Using simple loop..."
  echo "Running 10 iterations of 'zsh -i -c exit'..."
  for _ in {1..10}; do
    time zsh -i -c exit
  done
fi

# ── Section 2: Component-level profiling ────────────────────────
log_info "=== Component-Level Profile ==="
log_info "Profiling individual zshrc components via zsh/zprof..."

# Use zsh's built-in zprof module if available
if command -v zsh >/dev/null; then
  zsh -c '
    zmodload zsh/zprof 2>/dev/null
    # Source the real zshrc (DOTFILES_SOURCED guard is reset in a fresh shell)
    [[ -f "$HOME/.zshrc" ]] && source "$HOME/.zshrc"
    zprof
  ' 2>/dev/null | head -40

  echo ""
  log_info "Component timing (manual measurement):"

  # Measure key init commands individually
  _bench_component() {
    local label="$1"; shift
    local start end elapsed
    if command -v perl >/dev/null 2>&1; then
      start=$(perl -MTime::HiRes=time -e "printf \"%.0f\n\", time * 1000")
      zsh -c "$*" >/dev/null 2>&1 || true
      end=$(perl -MTime::HiRes=time -e "printf \"%.0f\n\", time * 1000")
    else
      start=$(($(date +%s) * 1000))
      zsh -c "$*" >/dev/null 2>&1 || true
      end=$(($(date +%s) * 1000))
    fi
    elapsed=$((end - start))
    printf "  %-30s %4d ms\n" "$label" "$elapsed"
  }

  _bench_component "bare zsh (baseline)" "exit"
  _bench_component "zinit + plugins"     "source \"\${XDG_DATA_HOME:-\$HOME/.local/share}/zinit/zinit.git/zinit.zsh\" 2>/dev/null; exit"
  _bench_component "compinit"            "autoload -Uz compinit && compinit -C; exit"
  _bench_component "starship init"       "command -v starship >/dev/null && eval \"\$(starship init zsh)\"; exit"
  _bench_component "atuin init"          "command -v atuin >/dev/null && eval \"\$(atuin init zsh)\"; exit"
  _bench_component "zoxide init"         "command -v zoxide >/dev/null && eval \"\$(zoxide init zsh)\"; exit"
  _bench_component "fnm env"             "command -v fnm >/dev/null && eval \"\$(fnm env --use-on-cd)\"; exit"
  _bench_component "fzf completions"     "[[ -f /opt/homebrew/opt/fzf/shell/completion.zsh ]] && source /opt/homebrew/opt/fzf/shell/completion.zsh; exit"

  echo ""
  log_info "Component profiling complete."
else
  echo "[WARN] zsh not found, skipping component profiling."
fi
