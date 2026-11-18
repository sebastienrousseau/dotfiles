#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# Dotfiles Scorecard
# Usage: dot doctor score show [--json|-j]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../lib/dot/ui.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../../lib/dot/ui.sh"
# shellcheck source=../../lib/dot/log.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../../lib/dot/log.sh"
export DOT_COMMAND="scorecard"

ui_init
set +x

if ! command -v python3 >/dev/null 2>&1; then
  ui_err "python3" "required for scorecard"
  exit 1
fi

JSON_OUTPUT=false
if [[ "${1:-}" == "--json" || "${1:-}" == "-j" ]]; then
  JSON_OUTPUT=true
fi

extract_json() {
  # strip any leading noise before the JSON payload
  awk 'BEGIN{p=0} /^[[:space:]]*[{]/{p=1} p{print}'
}

# collect_json <script> — the script's --json document. A probe's exit code
# reports its verdict (health.sh exits 1 when a check fails), not whether the
# JSON is usable, so it is ignored here; an empty document is caught below.
collect_json() {
  env -u SHELLOPTS bash "$SCRIPT_DIR/$1" --json 2>/dev/null | extract_json || true
}

# field <json> <key>: KEY's value in the JSON document, 0 when absent.
field() {
  python3 -c 'import json,sys; j=json.loads(sys.stdin.read()); print(j.get(sys.argv[1],0))' "$2" <<<"$1"
}

# verdict <label> <bad> <message>: an ok row, or the warning when BAD is 1.
verdict() {
  if [[ "$2" == 1 ]]; then ui_warn "$1" "$3"; else ui_ok "$1" "100/100"; fi
}

# health_verdict: failures are a failed result row (stdout, ui_fail).
health_verdict() {
  if [[ "$health_failures" -gt 0 ]]; then
    ui_err "Health" "Failures detected (run 'dot doctor fix')"
  elif [[ "$health_warnings" -gt 0 ]]; then
    ui_warn "Health" "Warnings detected (run 'dot doctor fix')"
  else
    ui_ok "Health" "All checks passing"
  fi
}

print_json() {
  cat <<JSON
{
  "health": {"score": $health_score, "warnings": $health_warnings, "failures": $health_failures},
  "security": {"score": $security_score},
  "performance": {"score": $perf_score, "mean_ms": $perf_mean, "target_ms": $perf_target},
  "drift": {"count": $drift_count}
}
JSON
}

print_report() {
  ui_dot_banner "Diagnostics"
  ui_header "Dotfiles Scorecard"

  ui_section "Scores"
  ui_kv "Health" "${health_score}/100"
  ui_kv "Security" "${security_score}/100"
  ui_kv "Performance" "${perf_score}/100 (avg ${perf_mean}ms, target ${perf_target}ms)"
  ui_kv "Drift" "${drift_count} file(s)"

  verdict "Security" "$security_low" "Run 'dot security score show' to reach 100/100"
  verdict "Performance" "$perf_low" "Tune startup to reach 100/100"
  health_verdict

  ui_section "Tips"
  ui_info "Fix" "dot doctor fix"
  ui_info "Profile" "dot doctor perf show --profile"
  ui_info "Security" "dot security score show"
  ui_info "Drift" "dot doctor drift show"
}

# count_drift: files chezmoi would change; 0 without chezmoi.
count_drift() {
  if command -v chezmoi >/dev/null 2>&1; then
    # --exclude=always: always-run scripts are pending by design, not drift.
    chezmoi status --exclude=always 2>/dev/null | wc -l | tr -d ' '
  else
    echo 0
  fi
}

record_scores() {
  dot_log info "scorecard_complete" "health=$health_score" "security=$security_score" "perf=$perf_score"
  dot_metric "scorecard_health" "$health_score" "percent"
  dot_metric "scorecard_security" "$security_score" "percent"
  dot_metric "scorecard_perf" "$perf_score" "percent"
}

health_json=$(collect_json health.sh)
security_json=$(collect_json security-score.sh)
perf_json=$(collect_json perf.sh)

if [[ -z "$health_json" || -z "$security_json" || -z "$perf_json" ]]; then
  ui_err "scorecard" "failed to collect JSON metrics"
  exit 1
fi

health_score=$(field "$health_json" score)
health_warnings=$(field "$health_json" warnings)
health_failures=$(field "$health_json" failures)
security_score=$(field "$security_json" score)
perf_score=$(field "$perf_json" score)
perf_mean=$(field "$perf_json" mean_ms)
perf_target=$(field "$perf_json" target_ms)
security_low=$((security_score < 100 ? 1 : 0))
perf_low=$((perf_score < 100 ? 1 : 0))

drift_count=$(count_drift)
record_scores

if $JSON_OUTPUT; then
  print_json
  exit 0
fi

print_report
# Not perfect on security or performance: exit 1.
exit "$((security_low | perf_low))"
