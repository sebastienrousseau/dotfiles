#!/usr/bin/env bash
# Dotfiles Scorecard
# Usage: dot scorecard [--json]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../dot/lib/ui.sh
source "$SCRIPT_DIR/../dot/lib/ui.sh"

ui_init

if ! command -v python3 >/dev/null 2>&1; then
  ui_err "python3" "required for scorecard"
  exit 1
fi

JSON_OUTPUT=false
if [[ "${1:-}" == "--json" ]]; then
  JSON_OUTPUT=true
fi

health_json=$(bash "$SCRIPT_DIR/health.sh" --json)
security_json=$(bash "$SCRIPT_DIR/security-score.sh" --json)
perf_json=$(bash "$SCRIPT_DIR/perf.sh" --json)

health_score=$(python3 -c 'import json,sys; j=json.loads(sys.stdin.read()); print(j.get("score",0))' <<<"$health_json")
health_warnings=$(python3 -c 'import json,sys; j=json.loads(sys.stdin.read()); print(j.get("warnings",0))' <<<"$health_json")
health_failures=$(python3 -c 'import json,sys; j=json.loads(sys.stdin.read()); print(j.get("failures",0))' <<<"$health_json")
security_score=$(python3 -c 'import json,sys; j=json.loads(sys.stdin.read()); print(j.get("score",0))' <<<"$security_json")
perf_score=$(python3 -c 'import json,sys; j=json.loads(sys.stdin.read()); print(j.get("score",0))' <<<"$perf_json")
perf_mean=$(python3 -c 'import json,sys; j=json.loads(sys.stdin.read()); print(j.get("mean_ms",0))' <<<"$perf_json")
perf_target=$(python3 -c 'import json,sys; j=json.loads(sys.stdin.read()); print(j.get("target_ms",0))' <<<"$perf_json")

# Drift count
if command -v chezmoi >/dev/null 2>&1; then
  drift_count=$(chezmoi status 2>/dev/null | wc -l | tr -d ' ')
else
  drift_count=0
fi

if $JSON_OUTPUT; then
  cat <<JSON
{
  "health": {"score": $health_score, "warnings": $health_warnings, "failures": $health_failures},
  "security": {"score": $security_score},
  "performance": {"score": $perf_score, "mean_ms": $perf_mean, "target_ms": $perf_target},
  "drift": {"count": $drift_count}
}
JSON
  exit 0
fi

ui_header "Dotfiles Scorecard"

ui_section "Scores"
ui_kv "Health" "${health_score}/100"
ui_kv "Security" "${security_score}/100"
ui_kv "Performance" "${perf_score}/100 (avg ${perf_mean}ms, target ${perf_target}ms)"
ui_kv "Drift" "${drift_count} file(s)"

if [[ "$security_score" -lt 100 ]]; then
  ui_warn "Security" "Run 'dot security-score' to reach 100/100"
else
  ui_ok "Security" "100/100"
fi

if [[ "$perf_score" -lt 100 ]]; then
  ui_warn "Performance" "Tune startup to reach 100/100"
else
  ui_ok "Performance" "100/100"
fi

if [[ "$health_failures" -gt 0 ]]; then
  ui_err "Health" "Failures detected (run 'dot health --fix')"
elif [[ "$health_warnings" -gt 0 ]]; then
  ui_warn "Health" "Warnings detected (run 'dot health --fix')"
else
  ui_ok "Health" "All checks passing"
fi

ui_section "Tips"
ui_info "Fix" "dot health --fix"
ui_info "Profile" "dot perf --profile"
ui_info "Security" "dot security-score"
ui_info "Drift" "dot drift"

exit_code=0
if [[ "$security_score" -lt 100 ]]; then
  exit_code=1
fi
if [[ "$perf_score" -lt 100 ]]; then
  exit_code=1
fi
exit "$exit_code"
