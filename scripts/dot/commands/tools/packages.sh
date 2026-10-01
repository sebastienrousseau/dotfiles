#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck shell=bash
# Sourced by tools.sh; inherits set -euo pipefail
# `dot packages`: one line per installed package manager, each query bounded
# so a manager that never answers cannot hang the command.

## _pkg_probe <cmd…> — run a package-manager query with stdin closed and a
## wall-clock limit of DOTFILES_PACKAGES_TIMEOUT seconds (default 10). A manager
## that never answers (rustup's cargo proxy waiting on a toolchain, a locked
## npm cache) used to hang `dot packages` for good. The whole process group
## is killed, not just the child: a grandchild that inherited stdout would
## otherwise keep the caller's $( ) open. Exits 124 on expiry. perl gives
## fork + setsid + group kill on macOS and Linux; without it there is no limit.
_pkg_probe() {
  local secs="${DOTFILES_PACKAGES_TIMEOUT:-10}"
  if ! command -v perl >/dev/null 2>&1; then
    "$@" </dev/null 2>/dev/null
    return
  fi
  perl -e '
    use POSIX qw(setsid);
    my $secs = shift @ARGV;
    my $pid  = fork();
    die "dot: fork failed: $!\n" unless defined $pid;
    if ($pid == 0) {
      setsid();
      exec { $ARGV[0] } @ARGV;
      exit 127;
    }
    my $timed_out = 0;
    $SIG{ALRM} = sub { $timed_out = 1; kill("KILL", -$pid); };
    alarm($secs);
    my $reaped;
    do { $reaped = waitpid($pid, 0); } while ($reaped == -1 && $!{EINTR});
    my $status = $?;
    alarm(0);
    kill("KILL", -$pid);
    exit(124) if $timed_out;
    exit($status & 127 ? 128 + ($status & 127) : $status >> 8);
  ' "$secs" "$@" </dev/null 2>/dev/null
}

## _pkg_count <pattern> <cmd…> — lines of the command's output matching the
## grep pattern; "timed out" past the limit; "N/A" when it failed silently.
## Output from a failing command still counts: `npm list -g` exits non-zero
## on any extraneous package, and `pipx list` on any broken interpreter.
_pkg_count() {
  local pattern="$1" out rc=0
  shift
  out="$(_pkg_probe "$@")" || rc=$?
  if [[ "$rc" -eq 124 ]]; then
    echo "timed out"
  elif [[ "$rc" -eq 0 || -n "$out" ]]; then
    # Re-add the newline $( ) stripped so the last line counts.
    printf '%s\n' "$out" | grep -c -- "$pattern" || true
  else
    echo "N/A"
  fi
}

## _pkg_word <n> <cmd…> — field n of the first output line (0 = the whole
## line), "timed out" past the limit, or "installed" when it printed nothing.
_pkg_word() {
  local n="$1" out rc=0 line
  shift
  out="$(_pkg_probe "$@")" || rc=$?
  if [[ "$rc" -eq 124 ]]; then
    echo "timed out"
    return
  fi
  line="${out%%$'\n'*}"
  if [[ -z "$line" ]]; then
    echo "installed"
  elif [[ "$n" -eq 0 ]]; then
    echo "$line"
  else
    echo "$line" | cut -d' ' -f"$n"
  fi
}

show_system_package_managers() {
  if has_command brew; then
    echo "  Homebrew: $(_pkg_word 0 brew --version)"
    echo "    Formulae: $(_pkg_count . brew list --formula)"
    echo "    Casks: $(_pkg_count . brew list --cask)"
  fi
  if has_command apt; then
    echo "  APT: $(_pkg_word 0 apt --version)"
    echo "    Packages: $(_pkg_count '^ii' dpkg -l)"
  fi
  if has_command dnf; then
    echo "  DNF: $(_pkg_word 0 dnf --version)"
  fi
  if has_command pacman; then
    echo "  Pacman: $(_pkg_word 0 pacman --version)"
    echo "    Packages: $(_pkg_count . pacman -Q)"
  fi
  if has_command nix; then
    echo "  Nix: $(_pkg_word 0 nix --version)"
  fi
}

_pkg_show_npm() {
  echo "  npm: $(_pkg_word 0 npm --version)"
  echo "    Global packages: $(_pkg_count '├──\|└──' npm list -g --depth=0)"
}

_pkg_show_cargo() {
  echo "  Cargo: $(_pkg_word 2 cargo --version)"
  echo "    Installed: $(_pkg_count ':$' cargo install --list)"
}

_pkg_show_pipx() {
  echo "  pipx: $(_pkg_word 0 pipx --version)"
  echo "    Installed: $(_pkg_count . pipx list --short)"
}

show_language_package_managers() {
  has_command npm && _pkg_show_npm
  has_command pnpm && echo "  pnpm: $(_pkg_word 0 pnpm --version)"
  has_command bun && echo "  Bun: $(_pkg_word 0 bun --version)"
  has_command cargo && _pkg_show_cargo
  has_command pip3 && echo "  pip: $(_pkg_word 2 pip3 --version)"
  has_command pipx && _pkg_show_pipx
  has_command gem && echo "  RubyGems: $(_pkg_word 0 gem --version)"
  has_command go && echo "  Go: $(_pkg_word 3 go version)"
  return 0
}
