# shellcheck shell=bash
# 🅿🆂 🅰🅻🅸🅰🆂🅴🆂
if command -v 'ps' >/dev/null; then

  # Display the uid, pid, parent pid, recent CPU usage, process start
  # time, controlling tty, elapsed CPU usage, and the associated command
  alias pid='ps -f'

  # Display all processes.
  alias ps='ps -ef'

  # List all processes.
  alias psa='ps aux'
fi
