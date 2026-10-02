#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck shell=bash
# Sourced by commands that query other tools; inherits set -euo pipefail.
#
# dot_probe <seconds> <command…> — run a query of another tool (a version,
# a list) with stdin closed, stderr dropped and a wall-clock limit. Some
# tools never answer: rustup's proxies (cargo, rustc) wait on a toolchain
# when HOME has none, and hung `dot packages` and `dot snapshot` for good.
# The whole process group is killed on expiry, not just the child: a
# grandchild that inherited stdout would otherwise keep the caller's $( )
# open. Exits 124 on expiry, else the command's status. perl gives fork +
# setsid + group kill on macOS and Linux; without it there is no limit.

[[ "${_DOT_PROBE_LOADED:-0}" == "1" ]] && return 0
_DOT_PROBE_LOADED=1

dot_probe() {
  local secs="$1"
  shift
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
