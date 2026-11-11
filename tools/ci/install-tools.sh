#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
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
#
# When apt cannot install a tool, ripgrep and shfmt come from a pinned
# GitHub release instead, checked against its SHA-256 before anything is
# installed. On 2026-11-11 security.ubuntu.com stopped resolving on the
# runners for hours; both packages are served from that pocket, so every
# shell-lint job failed and #1405 could not merge. Only those two have pins,
# only for Linux x86_64: any other tool keeps the apt error.
#
# Sourcing the script defines its functions and runs nothing (the tests do).
set -euo pipefail

INSTALL_TOOLS_BIN_DIR="${INSTALL_TOOLS_BIN_DIR:-/usr/local/bin}"
missing=()
missing_bins=()

# collect_missing SPEC...: fill missing (packages) and missing_bins (the
# binaries they provide) with the tools not already on PATH.
collect_missing() {
  local spec pkg bin
  for spec in "$@"; do
    pkg="${spec%%:*}"
    bin="${spec#*:}"
    [[ "$bin" == "$spec" ]] && bin="$pkg"
    if command -v "$bin" >/dev/null 2>&1; then
      printf 'present: %s (%s)\n' "$pkg" "$(command -v "$bin")"
    else
      missing+=("$pkg")
      missing_bins+=("$bin")
    fi
  done
}

# `timeout` bounds each call: a mirror that stops responding costs seconds,
# not the job's entire budget. Without it, apt waits on its own much longer
# timeouts and the job is killed mid-install with no useful diagnostic.
#
# The bounds are chosen so all three attempts fit inside the smallest job
# budget that calls this (10 minutes): 3 * (60 + 120) = 9 minutes. A retry
# ceiling the job timeout can cut short would report "cancelled" — the very
# symptom this replaces — instead of a readable error.
apt_install_missing() {
  # `apt-get update` exits non-zero when ANY configured repository fails to
  # fetch — including third-party ones the runner image ships that have
  # nothing to do with what we install. On 2026-09-09 the Google Chrome repo
  # was unreachable and took down ten jobs across a PR: apt itself reported
  # "Some index files failed to download. They have been ignored, or old ones
  # used instead", so it had a usable index and the packages we want come from
  # Ubuntu's own repos, but the `&&` vetoed the install anyway.
  #
  # So refresh on a best-effort basis and let the *install* decide success.
  # A genuinely missing package still fails here, loudly, which is the signal
  # worth acting on.
  sudo timeout 60 apt-get update -qq || true
  sudo timeout 120 apt-get install -y -qq --no-install-recommends "${missing[@]}"
}

# fallback_spec PKG: print "URL SHA256 BINARY" for PKG's pinned release, or
# fail when PKG has none on this platform. Bump a pin together with its sum.
fallback_spec() {
  local url sum bin
  [[ "$(uname -s)-$(uname -m)" == "Linux-x86_64" ]] || return 1
  case "$1" in
    ripgrep)
      url="https://github.com/BurntSushi/ripgrep/releases/download/15.2.0/ripgrep-15.2.0-x86_64-unknown-linux-musl.tar.gz"
      sum="33e15bcf1624b25cdd2a55813a47a2f95dbe126268203e76aa6a585d1e7b149c" # pragma: allowlist secret
      bin=rg
      ;;
    shfmt)
      url="https://github.com/mvdan/sh/releases/download/v3.13.1/shfmt_v3.13.1_linux_amd64"
      sum="fb096c5d1ac6beabbdbaa2874d025badb03ee07929f0c9ff67563ce8c75398b1" # pragma: allowlist secret
      bin=shfmt
      ;;
    *) return 1 ;;
  esac
  printf '%s %s %s\n' "$url" "$sum" "$bin"
}

# sha256_ok SUM FILE: FILE's SHA-256 is SUM.
sha256_ok() {
  local tool=(sha256sum)
  command -v sha256sum >/dev/null 2>&1 || tool=(shasum -a 256)
  printf '%s  %s\n' "$1" "$2" | "${tool[@]}" -c - >/dev/null 2>&1
}

# install_pinned URL SUM BINARY: download URL, refuse it unless its SHA-256
# is SUM, and install BINARY (the file itself, or found in a .tar.gz) into
# $INSTALL_TOOLS_BIN_DIR.
install_pinned() {
  local url="$1" sum="$2" bin="$3" tmp src
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/install-tools.XXXXXX")"
  curl -fsSL --retry 2 --max-time 120 -o "$tmp/download" "$url" || return 1
  if ! sha256_ok "$sum" "$tmp/download"; then
    printf '::error::SHA-256 mismatch for %s; not installed\n' "$url" >&2
    return 1
  fi
  src="$tmp/download"
  if [[ "$url" == *.tar.gz ]]; then
    tar -xzf "$src" -C "$tmp"
    src="$(find "$tmp" -type f -name "$bin" | head -n 1)"
    [[ -n "$src" ]] || return 1
  fi
  sudo install -m 0755 "$src" "$INSTALL_TOOLS_BIN_DIR/$bin"
}

# install_fallbacks: install each tool still missing from its pinned
# release; fail, installing no further, at the first without a pin.
install_fallbacks() {
  local i url sum bin
  for i in "${!missing[@]}"; do
    command -v "${missing_bins[$i]}" >/dev/null 2>&1 && continue
    read -r url sum bin <<<"$(fallback_spec "${missing[$i]}")" || return 1
    [[ -n "$url" ]] || return 1
    install_pinned "$url" "$sum" "$bin" || return 1
    printf 'Installed %s from its pinned release: %s\n' "${missing[$i]}" "$url"
  done
}

main() {
  if [[ $# -eq 0 ]]; then
    echo "usage: $0 <tool>..." >&2
    return 2
  fi
  collect_missing "$@"
  if [[ "${#missing[@]}" -eq 0 ]]; then
    printf 'All requested tools already present, skipping apt entirely.\n'
    return 0
  fi
  printf 'Installing missing tools: %s\n' "${missing[*]}"
  local attempt
  for attempt in 1 2 3; do
    if apt_install_missing; then
      printf 'Installed: %s\n' "${missing[*]}"
      return 0
    fi
    printf '::warning::apt attempt %s/3 failed for: %s\n' "$attempt" "${missing[*]}"
    install_fallbacks && return 0
    sleep $((attempt * 5))
  done
  printf '::error::Failed to install after 3 attempts: %s\n' "${missing[*]}"
  return 1
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
