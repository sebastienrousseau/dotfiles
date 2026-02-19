# shellcheck shell=bash
# stopwatch: Function for a stopwatch
stopwatch() {
  date1=$(gdate +%s)
  while true; do
    echo -ne "$(gdate -u --date @$(($(date +%s) - date1)) +%H:%M:%S || true)\r"
    sleep 0.1
  done
}
