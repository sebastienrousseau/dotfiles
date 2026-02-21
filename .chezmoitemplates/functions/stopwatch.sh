# shellcheck shell=bash
# stopwatch: Function for a stopwatch
# Platform: Uses GNU date (gdate on macOS, date on Linux)
stopwatch() {
  local date_cmd="date"
  # Use gdate on macOS if available (GNU coreutils)
  if [[ "$(uname -s)" == "Darwin" ]]; then
    if command -v gdate >/dev/null 2>&1; then
      date_cmd="gdate"
    else
      echo "[ERROR] GNU date (gdate) required. Install with: brew install coreutils" >&2
      return 1
    fi
  fi

  local date1
  date1=$($date_cmd +%s)
  while true; do
    local elapsed=$(($(date +%s) - date1))
    local hours=$((elapsed / 3600))
    local minutes=$(((elapsed % 3600) / 60))
    local seconds=$((elapsed % 60))
    printf "\r%02d:%02d:%02d" "$hours" "$minutes" "$seconds"
    sleep 0.1
  done
}
