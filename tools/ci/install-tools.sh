#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
#
# Install CI tooling — but only what is actually missing, and never hang.
#
# Every CI job that needed shellcheck/shfmt/ripgrep/jq ran an unconditional
# `apt-get update && apt-get install`. `apt-get update` is the slowest and
# least reliable step in those jobs, and it is pure overhead whenever the
# runner image already ships the tool.
#
# On 2026-08-19 the Azure mirror stalled and `apt-get update` sat for over
# five minutes, which killed `Lint / Shell` twice — a job whose actual lint
# work takes ~30 seconds against a 5-minute budget. Four re-runs were needed
# to land a green main.
#
# So: look before installing, bound every network call so a hung mirror
# cannot eat the whole job budget, and retry instead of failing on the first
# blip.
#
# Usage: tools/ci/install-tools.sh shellcheck ripgrep:rg shfmt
#
# Each argument is a package name, optionally followed by ":" and the binary
# it provides when the two differ. That distinction is load-bearing, not
# decoration: `apt-get install ripgrep` puts `rg` on PATH, and `golang-go`
# puts `go` there, so a presence check against the package name would never
# match and every run would reinstall a tool that was already there —
# quietly restoring the exact cost this script exists to remove.
set -euo pipefail

if [[ $# -eq 0 ]]; then
  echo "usage: $0 <tool>..." >&2
  exit 2
fi

missing=()
missing_count=0
for spec in "$@"; do
  pkg="${spec%%:*}"
  bin="${spec#*:}"
  [[ "$bin" == "$spec" ]] && bin="$pkg"
  if command -v "$bin" >/dev/null 2>&1; then
    printf 'present: %s (%s)\n' "$pkg" "$(command -v "$bin")"
  else
    missing+=("$pkg")
    missing_count=$((missing_count + 1))
  fi
done

if [[ "$missing_count" -eq 0 ]]; then
  printf 'All requested tools already present, skipping apt entirely.\n'
  exit 0
fi

printf 'Installing missing tools: %s\n' "${missing[*]}"

# `timeout` bounds each call: a mirror that stops responding costs seconds,
# not the job's entire budget. Without it, apt waits on its own much longer
# timeouts and the job is killed mid-install with no useful diagnostic.
#
# The bounds are chosen so all three attempts fit inside the smallest job
# budget that calls this (10 minutes): 3 * (60 + 120) = 9 minutes. A retry
# ceiling the job timeout can cut short would report "cancelled" — the very
# symptom this replaces — instead of a readable error.
apt_install_missing() {
  sudo timeout 60 apt-get update -qq &&
    sudo timeout 120 apt-get install -y -qq --no-install-recommends "${missing[@]}"
}

for attempt in 1 2 3; do
  if apt_install_missing; then
    printf 'Installed: %s\n' "${missing[*]}"
    exit 0
  fi
  printf '::warning::apt attempt %s/3 failed for: %s\n' "$attempt" "${missing[*]}"
  sleep $((attempt * 5))
done

printf '::error::Failed to install after 3 attempts: %s\n' "${missing[*]}"
exit 1
