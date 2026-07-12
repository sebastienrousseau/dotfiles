#!/usr/bin/env bash
set -euo pipefail

# Scheduled corralctl sync of sebastienrousseau repos into ~/Code.
# Invoked by the launchd agent com.sebastienrousseau.corralctl (daily 00:00).
# Logs every run; posts a macOS notification only when a run has failures.

export PATH="/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"

OWNER="sebastienrousseau"
LOG="$HOME/Library/Logs/corralctl.log"

ts() { date '+%Y-%m-%d %H:%M:%S'; }

{
  echo "===== corralctl sync started $(ts) ====="
  set +e
  out="$(corralctl "$OWNER" -c 8 2>&1)"
  code=$?
  set -e
  printf '%s\n' "$out"
  errors="$(printf '%s\n' "$out" | grep -c '✗ \[ERROR\]' || true)"
  synced="$(printf '%s\n' "$out" | grep -c '✓ \[SYNC\]' || true)"
  echo "----- finished $(ts): exit=$code synced=$synced errors=$errors -----"
} >>"$LOG" 2>&1

# Notify only on failure (non-zero exit or any per-repo error).
if [[ "$code" -ne 0 || "${errors:-0}" -gt 0 ]]; then
  /usr/bin/osascript -e "display notification \"${errors} error(s), exit ${code}. See ${LOG}\" with title \"corralctl sync failed\" sound name \"Basso\"" || true
fi

# Self-trim: cap the log at ~1 MB by keeping the last 2000 lines.
if [[ -f "$LOG" && "$(wc -c <"$LOG")" -gt 1048576 ]]; then
  tail -n 2000 "$LOG" >"$LOG.tmp" && mv "$LOG.tmp" "$LOG"
fi

exit 0
