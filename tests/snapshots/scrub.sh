#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# =============================================================================
# scrub.sh — replace machine- and time-specific content in dot-CLI output
# with stable placeholders so golden-file snapshot tests don't break on
# every machine.
#
# Stdin: raw command output.
# Stdout: stable, snapshot-ready text.
#
# Closes part of #881.
# =============================================================================

set -euo pipefail

mode="${1:-generic}"

# Strip colour first. Otherwise an ANSI fragment such as `34mseb` can be
# mistaken for a duration before the escape sequence is removed.
sed -E \
  -e $'s/\x1b\[[0-9;]*m//g' \
  -e 's/[[:space:]]+$//' \
  -e 's/v[0-9]+\.[0-9]+\.[0-9]+([a-z0-9.-]+)?/v0.0.0/g' \
  -e 's@/Users/[^/[:space:]]+@/Users/<user>@g' \
  -e 's@/home/[^/[:space:]]+@/home/<user>@g' \
  -e 's/[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z?/<ts>/g' \
  -e 's/Uptime:[[:space:]]+[0-9]+:[0-9]+/Uptime:    <uptime>/g' \
  -e 's/Uptime:[[:space:]]+[0-9]+:[0-9]+:[0-9]+/Uptime:    <uptime>/g' \
  -e 's/[0-9]{1,5}(\.[0-9]+)?[[:space:]]?(ms|µs|us)/<dur>/g' \
  -e 's/[0-9]{1,4}\.[0-9]+[[:space:]]?(GiB|MiB|KiB|GB|MB|KB)/<size>/g' \
  -e 's/[0-9]{1,4}\.[0-9]+[[:space:]]s([^[:alnum:]]|$)/<dur>\1/g' \
  -e 's/(commit|sha)[[:space:]]*[a-f0-9]{7,40}/\1 <sha>/Ig' \
  -e 's/[a-f0-9]{40}/<sha40>/g' \
  -e 's/[0-9]+ tests? passed/<n> tests passed/g' |
  awk -v mode="$mode" '
    mode == "version" && /Version[[:space:]]+\.dotfiles [0-9]+\.[0-9]+\.[0-9]+/ {
      sub(/\.dotfiles [0-9]+\.[0-9]+\.[0-9]+/, ".dotfiles <version>")
    }
    mode == "version" && /Source[[:space:]]+/ {
      sub(/Source[[:space:]]+.*/, "Source                              <source>")
    }

    # Doctor sections enumerate installed tools and host facts. Preserve the
    # section contract, but reduce each machine-dependent inventory to one row.
    mode == "doctor" && /^== / {
      if (doctor_section_seen) print ""
      print
      doctor_section_seen = 1
      in_doctor_section = 1
      doctor_row_emitted = 0
      next
    }
    mode == "doctor" && in_doctor_section {
      if (NF && !doctor_row_emitted) {
        print "  <checks>"
        doctor_row_emitted = 1
      }
      next
    }

    mode == "health" && /^▸ / {
      health_section_pending = 1
      print
      next
    }
    mode == "health" && health_section_pending && /^─/ {
      print
      print "* <check> <state>"
      health_section_pending = 0
      next
    }
    mode == "health" && /SSH key perms \(/ { next }
    mode == "health" && /^  Tip:/ { next }
    mode == "health" && /^  (Total checks|Passed|Warnings|Failures):/ {
      sub(/[0-9]+$/, "<n>"); print; next
    }
    mode == "health" && /^  Health Score:/ { print "  Health Score: <score>"; next }
    mode == "health" && /^[^ ]/ && /[[:space:]]+(OK|WARNING|FAILED|FAIL)([[:space:]]|$)/ {
      next
    }
    mode == "health" && /^  [^ ]/ && /(Excellent|Good|improvements|attention|Critical)/ {
      print "  <health summary>"
      next
    }

    mode == "perf" && /^== Per-shell startup/ { print; print "  <shell measurements>"; in_shells = 1; next }
    mode == "perf" && in_shells && /^== / { in_shells = 0 }
    mode == "perf" && in_shells { next }
    mode == "perf" && /^  .    Performance/ {
      print "  *    Performance                         <dynamic>"
      next
    }

    { print }
  ' |
  awk '
    NF { while (pending_blanks > 0) { print ""; pending_blanks-- } print; next }
    { pending_blanks++ }
  '
