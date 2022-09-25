#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.450) - Function for countdown.

# countdown: Function for countdown
countdown() {

  if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
    echo "usage:
	countdown [SECONDS]
	countdown"
    exit 0
  fi
  if [ -z "$1" ]; then
    read -rp "Enter a number of seconds to countdown from: " seconds
  else
    seconds=$1
  fi
  x=60
  for ((c = 1; c <= seconds; c++)); do
    sleep 1
    seconds_remaining=$((seconds - c))
    echo -ne "\033[2k\rCountdown: $seconds_remaining seconds"
  done
  echo -ne "\033[2k\r"
  echo "Countdown finished on $(date)"
}

alias cntd='countdown' # Alias for countdown
alias ctd='countdown' # Alias for countdown
