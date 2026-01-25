#!/usr/bin/env bash
set -euo pipefail

# Simple terminal pipes screensaver
# Inspired by pipes.sh but kept minimal for portability

cols=$(tput cols 2>/dev/null || echo 80)
rows=$(tput lines 2>/dev/null || echo 24)

cleanup() {
  tput cnorm 2>/dev/null || true
  stty echo 2>/dev/null || true
  clear
}

trap cleanup EXIT INT TERM

tput civis 2>/dev/null || true
stty -echo 2>/dev/null || true
clear

symbols=("|" "-" "+" "┘" "└" "┐" "┌")
colors=(31 32 33 34 35 36 37)

while true; do
  x=$((RANDOM % cols + 1))
  y=$((RANDOM % rows + 1))
  sym=${symbols[$((RANDOM % ${#symbols[@]}))]}
  color=${colors[$((RANDOM % ${#colors[@]}))]}
  printf "\033[%s;%sH\033[%sm%s\033[0m" "$y" "$x" "$color" "$sym"
  sleep 0.01
  if [[ "$y" -ge "$rows" ]]; then
    clear
  fi
  if [[ "$x" -ge "$cols" ]]; then
    clear
  fi
  if [[ "$RANDOM" -gt 32000 ]]; then
    clear
  fi
  # slow down slightly
  sleep 0.01
  # allow keypress to exit
  if read -r -t 0.001; then
    break
  fi
done
