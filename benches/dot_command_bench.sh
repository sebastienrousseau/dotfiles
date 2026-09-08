#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
#
# dot_command_bench.sh — per-command benchmark sweep for the `dot` CLI.
#
# Complements the two performance gates that already exist:
#
#   tools/ci/dot-cli-startup-bench.sh   one command (`dot version`), asserted
#                                       against a per-OS budget.
#   benches/bench.sh          interactive shell startup, asserted
#                                       against calibrated thresholds.
#
# This script is the breadth half: it times EVERY routed subcommand rather
# than one representative, so a regression in a single command's cold start
# cannot hide behind an aggregate.
#
# Recorded, not asserted
# ----------------------
# Nothing here fails a build on a timing. That is deliberate, and it is the
# same lesson 73b788f0 recorded when the zsh gate was recalibrated for the
# fourth time: on this hardware a single command's wall clock is not
# measurable to better than roughly ±25% between sessions, and a gate that
# fails on when it happens to run teaches people to ignore it. The existing
# calibrated thresholds stay where they are and keep their own scripts; these
# numbers are a recorded trend line. `--budget-ms` exists for a caller that
# wants an explicit ceiling, and is off by default.
#
# Usage:
#   benches/dot_command_bench.sh                 # help sweep
#   benches/dot_command_bench.sh --full          # + read-only runs
#   benches/dot_command_bench.sh --list-ids      # ids, one per line
#   benches/dot_command_bench.sh --output b.json
#   benches/dot_command_bench.sh --runs 5 --budget-ms 2000
#
# Every id printed by --list-ids is referenceable from the Benchmark column of
# docs/reference/FEATURE-MATRIX.md, and scripts/qa/check-feature-matrix.sh
# fails when the matrix names an id this script does not produce.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
DOT_BIN="$REPO_ROOT/bin/dot"

MODE="help"
OUTPUT=""
RUNS="${DOT_BENCH_RUNS:-3}"
BUDGET_MS="${DOT_BENCH_BUDGET_MS:-0}"
LIST_ONLY=0

usage() {
  sed -n '5,40p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --full)
      MODE="full"
      shift
      ;;
    --help-only)
      MODE="help"
      shift
      ;;
    --list-ids)
      LIST_ONLY=1
      MODE="full"
      shift
      ;;
    --output | -o)
      OUTPUT="${2:-}"
      shift 2
      ;;
    --runs)
      RUNS="${2:-3}"
      shift 2
      ;;
    --budget-ms)
      BUDGET_MS="${2:-0}"
      shift 2
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown option: %s\n\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

# ---------------------------------------------------------------------------
# Case tables
# ---------------------------------------------------------------------------

# Every command the dispatcher can route, straight out of bin/dot's route
# table, minus the flag aliases (`dot --help --help` is not a case worth
# timing). One `help:<command>` case each — the cold-start cost a user pays
# on every invocation of that command.
bench_help_ids() {
  awk '/^_dot_command_routes\(\)/,/^EOF$/' "$DOT_BIN" |
    awk -F'|' '/^[a-z][a-z0-9-]*\|[a-z]+$/ { print $1 }' |
    sort -u
}

# Read-only invocations: the command doing its real work, not just rendering
# help. Every entry has been verified to leave a sandboxed HOME intact —
# nothing here writes outside $HOME, opens a network connection, or prompts.
# Format: <id>|<argv>
bench_run_cases() {
  cat <<'EOF'
version|version
version-flag|--version
help|help
help-noargs|
help-flag|--help
help-all|help all
help-topic|help doctor
help-unknown|help zzz-no-such-topic
help-intercept|edit --help
search|search theme
search-usage|search
search-nomatch|search zzz-no-such-command
unknown-command|zzz-not-a-command
version-nologo|version
user-command|zzz-user-command-probe
cd|cd
status|status
diff|diff
sync-check|sync --check
apply-dry-run|apply --dry-run
update|update
add|add
add-usage|add
edit|edit
commit|commit
doctor|doctor
doctor-score|doctor --score
doctor-smoke|doctor --smoke
doctor-drift|doctor --drift
heal|heal
heal-dry-run|heal --dry-run
health|health
health-json|health -j
security-score|security-score
security-score-json|security-score -j
score|score
score-json|score --json
perf|perf -j -r 1
conflicts|conflicts
locks|locks
snapshot|snapshot
attest|attest
attest-json|attest --json
drift|drift
drift-json|drift --json
history|history
benchmark|benchmark
restore-list|restore --list
restore-usage|restore
rollback-status|rollback status
load-bench|load-bench
chaos|chaos --dry-run
teleport-usage|teleport
secret-audit|secret-audit
metrics|metrics
smoke-test|smoke-test
intelligence|intelligence
ai-tools|ai tools
ai-doctor|ai doctor
ai-cost|ai cost
ai-run-usage|ai run
ai-ask-usage|ai ask
ai-delegate-usage|ai delegate
ai-query-usage|ai-query
cl-usage|cl
env-list|env list
env-emit|env emit --compact
profile-show|profile show
tools|tools
tools-docs|tools docs
new-usage|new
packages|packages
aliases-list|aliases list
aliases-search|aliases search git
aliases-why|aliases why ll
aliases-stats|aliases stats
aliases-tiers|aliases tiers
aliases-cheatsheet|aliases cheatsheet --output -
alias-check|alias-check
log-rotate|log-rotate
theme|theme
theme-list|theme list
theme-current|theme current
encrypt-check|encrypt-check
telemetry|telemetry
policy|policy
cache-refresh|cache-refresh
docs|docs
learn|learn
keys|keys
keys-sign-check|keys sign-check
mcp|mcp
mcp-doctor|mcp doctor
mcp-doctor-json|mcp doctor --json
mcp-registry|mcp registry
mcp-registry-json|mcp registry --json
mode|mode
mode-list|mode list
mode-current|mode current
mode-show|mode show audit
mode-run|mode run plan true
mode-doctor|mode doctor
agent|agent
agent-card|agent card
agent-card-json|agent card --json
agent-log|agent log
agent-checkpoint-list|agent checkpoint list
agent-delegate-usage|agent delegate
agent-a2a-card|agent a2a-card
agent-a2a-card-json|agent a2a-card --json
agent-a2a-card-validate|agent a2a-card --validate
agent-conformance|agent conformance
agent-conformance-json|agent conformance --json
agents-list|agents list
agents-check|agents check
fleet|fleet
fleet-json|fleet --json
fleet-status|fleet status
fleet-status-json|fleet status --json
fleet-drift|fleet drift
fleet-drift-history|fleet drift history
fleet-drift-predict|fleet drift predict
fleet-events|fleet events
fleet-namespace|fleet namespace
fleet-enforce|fleet enforce
fleet-apply-dry-run|fleet apply --dry-run
fleet-apply-nohosts|fleet apply --dry-run
registry-url|registry url
registry-list|registry list
registry-search|registry search rust
registry-info|registry info fm-bench-mod
registry-install-dry-run|registry install fm-bench-mod --dry-run
registry-installed|registry installed
patterns-list|patterns list
patterns-view|patterns view fm-bench-pattern
completion-bash|completion bash
completion-zsh|completion zsh
completion-fish|completion fish
completion-nu|completion nu
completion-usage|completion
init-dry-run|init alice --dry-run
init-usage|init
manual-text-offline|manual text --offline
manual-help|manual --help
secrets-provider|secrets provider
secrets-list|secrets list
secrets-set-usage|secrets set
secrets-get-missing|secrets get FM_NO_SUCH_KEY
secrets-load-empty|secrets load fm-no-such-bucket
secrets-edit-nokey|secrets edit
secrets-create-nokey|secrets-create
ssh-key-missing|ssh-key
ssh-cert-usage|ssh-cert
ssh-cert-status|ssh-cert status
EOF
}

bench_all_ids() {
  {
    bench_help_ids | sed 's/^/help:/'
    if [[ "$MODE" == "full" ]]; then
      bench_run_cases | awk -F'|' 'NF >= 1 && $1 != "" { print "run:" $1 }'
    fi
  } | sort -u
}

if [[ "$LIST_ONLY" -eq 1 ]]; then
  bench_all_ids
  exit 0
fi

# ---------------------------------------------------------------------------
# Sandbox
#
# Same safety model as the FEATURE-MATRIX regression suite: a throwaway HOME,
# XDG dirs inside it, and PATH-front stubs for every host-mutating binary. A
# benchmark that rewrote the developer's dotfiles would be a bad trade for a
# timing.
# ---------------------------------------------------------------------------

BENCH_SANDBOX="$(mktemp -d -t dot-bench.XXXXXX)"
cleanup() { rm -rf "$BENCH_SANDBOX"; }
trap cleanup EXIT

mkdir -p \
  "$BENCH_SANDBOX/.config" "$BENCH_SANDBOX/.local/share" \
  "$BENCH_SANDBOX/.local/state" "$BENCH_SANDBOX/.cache" \
  "$BENCH_SANDBOX/bin" "$BENCH_SANDBOX/work"
ln -sfn "$REPO_ROOT" "$BENCH_SANDBOX/.dotfiles"

for stub in chezmoi sudo osascript defaults gsettings systemctl; do
  printf '#!/usr/bin/env bash\nexit 0\n' >"$BENCH_SANDBOX/bin/$stub"
  chmod +x "$BENCH_SANDBOX/bin/$stub"
done
printf '#!/usr/bin/env bash\nexit 1\n' >"$BENCH_SANDBOX/bin/gum"
chmod +x "$BENCH_SANDBOX/bin/gum"

# Fixtures the read-only cases read, so they measure the populated path
# rather than an early "nothing here" return.
mkdir -p "$BENCH_SANDBOX/.config/ai/patterns" "$BENCH_SANDBOX/.cache/dotfiles/ai"
printf '# fm bench pattern\n' >"$BENCH_SANDBOX/.config/ai/patterns/fm-bench-pattern.md"
printf 'claude\t1\t0.0.0-bench\n' >"$BENCH_SANDBOX/.cache/dotfiles/ai/status.tsv"
printf ': 1700000000:0;ll\n: 1700000001:0;git status\n' >"$BENCH_SANDBOX/.zsh_history"

# A file:// registry so the registry cases never touch the network.
mkdir -p "$BENCH_SANDBOX/work/registry/module"
printf 'bench payload\n' >"$BENCH_SANDBOX/work/registry/module/dot_bench"
(cd "$BENCH_SANDBOX/work/registry" && tar -czf module.tgz module)
_bench_sha="$(shasum -a 256 "$BENCH_SANDBOX/work/registry/module.tgz" 2>/dev/null |
  cut -d' ' -f1)"
[[ -n "$_bench_sha" ]] ||
  _bench_sha="$(sha256sum "$BENCH_SANDBOX/work/registry/module.tgz" | cut -d' ' -f1)"
cat >"$BENCH_SANDBOX/work/registry/index.json" <<JSON
{"version":1,"updated":"2026-01-01T00:00:00Z","modules":[
 {"name":"fm-bench-mod","description":"bench fixture","repo":"https://example.com/x",
  "tags":["bench"],"maintainer":"b@example.com","version":"1.0.0",
  "archive_url":"file://$BENCH_SANDBOX/work/registry/module.tgz","sha256":"$_bench_sha"}]}
JSON

# An offline manual page for the manual case.
mkdir -p "$BENCH_SANDBOX/.local/share/dotfiles/manual"
printf 'bench manual\n' >"$BENCH_SANDBOX/.local/share/dotfiles/manual/dotfiles.txt"

# A fleet hosts file for the apply dry-run case.
mkdir -p "$BENCH_SANDBOX/.config/dotfiles"
cat >"$BENCH_SANDBOX/.config/dotfiles/fleet.toml" <<'TOML'
[hosts.bench]
ssh = "user@bench.local"
profile = "workstation"
TOML

export HOME="$BENCH_SANDBOX"
export XDG_CONFIG_HOME="$BENCH_SANDBOX/.config"
export XDG_DATA_HOME="$BENCH_SANDBOX/.local/share"
export XDG_STATE_HOME="$BENCH_SANDBOX/.local/state"
export XDG_CACHE_HOME="$BENCH_SANDBOX/.cache"
export CHEZMOI_SOURCE_DIR="$REPO_ROOT"
export PATH="$BENCH_SANDBOX/bin:$PATH"
export NO_COLOR=1 DOTFILES_SHOW_LOGO=0 DOTFILES_NO_TUI=1 DOTFILES_NONINTERACTIVE=1
export EDITOR=true PAGER=cat
export DOTFILES_REGISTRY_URL="file://$BENCH_SANDBOX/work/registry/index.json"
export DOTFILES_AI_STATUS_TTL=99999
export GIT_CONFIG_GLOBAL="$BENCH_SANDBOX/.gitconfig"
: >"$BENCH_SANDBOX/.gitconfig"
cd "$BENCH_SANDBOX/work"

# ---------------------------------------------------------------------------
# Timing
# ---------------------------------------------------------------------------

HAVE_HYPERFINE=0
if command -v hyperfine >/dev/null 2>&1; then
  HAVE_HYPERFINE=1
fi
HAVE_JQ=0
if command -v jq >/dev/null 2>&1; then
  HAVE_JQ=1
fi

_now_ms() {
  if [[ -n "${EPOCHREALTIME:-}" ]]; then
    awk -v t="$EPOCHREALTIME" 'BEGIN{printf "%d\n", t*1000}'
  elif date +%s%N 2>/dev/null | grep -qE '^[0-9]+$'; then
    echo $(($(date +%s%N) / 1000000))
  else
    python3 -c 'import time; print(int(time.time()*1000))'
  fi
}

# Median wall clock in ms for one argv. hyperfine when available (it does the
# warmup and the statistics properly); otherwise a portable median-of-N loop,
# so the sweep still produces numbers on a runner without it.
measure_ms() {
  local argv="$1"
  if [[ "$HAVE_HYPERFINE" -eq 1 && "$HAVE_JQ" -eq 1 ]]; then
    local json
    json="$(umask 077 && mktemp)"
    if hyperfine --style none -N -i --warmup 1 --runs "$RUNS" \
      --export-json "$json" \
      -- "bash $DOT_BIN $argv" >/dev/null 2>&1; then
      jq -r '.results[0].median * 1000 | floor' "$json" 2>/dev/null || echo -1
    else
      echo -1
    fi
    rm -f "$json"
    return 0
  fi

  local samples=() i start end
  for ((i = 0; i < RUNS; i++)); do
    start="$(_now_ms)"
    # shellcheck disable=SC2086
    bash "$DOT_BIN" $argv >/dev/null 2>&1 </dev/null || true
    end="$(_now_ms)"
    samples+=("$((end - start))")
  done
  printf '%s\n' "${samples[@]}" | sort -n | awk -v n="$RUNS" 'NR==int(n/2)+1{print;exit}'
}

# ---------------------------------------------------------------------------
# Sweep
# ---------------------------------------------------------------------------

results_file="$(umask 077 && mktemp)"
over_budget=0
case_count=0

record() {
  local id="$1" argv="$2" ms="$3"
  case_count=$((case_count + 1))
  printf '{"id":"%s","argv":"%s","median_ms":%s}\n' "$id" "$argv" "$ms" \
    >>"$results_file"
  if [[ "$BUDGET_MS" -gt 0 && "$ms" -gt "$BUDGET_MS" ]]; then
    printf '  %-46s %6sms  (> %sms)\n' "$id" "$ms" "$BUDGET_MS" >&2
    over_budget=$((over_budget + 1))
  else
    printf '  %-46s %6sms\n' "$id" "$ms"
  fi
}

printf 'dot per-command benchmark sweep\n'
printf '  dispatcher : %s\n' "$DOT_BIN"
printf '  timer      : %s\n' \
  "$([[ "$HAVE_HYPERFINE" -eq 1 && "$HAVE_JQ" -eq 1 ]] && echo hyperfine || echo "portable median-of-$RUNS")"
printf '  mode       : %s\n' "$MODE"
printf '  runs       : %s\n\n' "$RUNS"

printf 'help cold-start (every routed command)\n'
while IFS= read -r cmd; do
  [[ -n "$cmd" ]] || continue
  record "help:$cmd" "$cmd --help" "$(measure_ms "$cmd --help")"
done < <(bench_help_ids)

if [[ "$MODE" == "full" ]]; then
  printf '\nread-only invocations\n'
  while IFS='|' read -r id argv; do
    [[ -n "$id" ]] || continue
    record "run:$id" "$argv" "$(measure_ms "$argv")"
  done < <(bench_run_cases)
fi

# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------

if [[ -n "$OUTPUT" ]]; then
  {
    printf '{\n'
    printf '  "generated_at": "%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf '  "tool": "%s",\n' \
      "$([[ "$HAVE_HYPERFINE" -eq 1 && "$HAVE_JQ" -eq 1 ]] && echo hyperfine || echo portable)"
    printf '  "runs": %s,\n' "$RUNS"
    printf '  "mode": "%s",\n' "$MODE"
    printf '  "cases": [\n'
    awk 'NR > 1 { printf ",\n" } { printf "    %s", $0 } END { printf "\n" }' \
      "$results_file"
    printf '  ]\n}\n'
  } >"$OUTPUT"
  printf '\nWrote %s (%s cases)\n' "$OUTPUT" "$case_count"
fi

rm -f "$results_file"

printf '\n%s cases benchmarked.\n' "$case_count"

# Timings are recorded, not asserted, unless the caller asked for a ceiling.
if [[ "$BUDGET_MS" -gt 0 && "$over_budget" -gt 0 ]]; then
  printf '::error::%s case(s) exceeded the %sms budget\n' "$over_budget" "$BUDGET_MS" >&2
  exit 1
fi
exit 0
