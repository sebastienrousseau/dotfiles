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

sed -E \
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
  -e 's/[0-9]+ tests? passed/<n> tests passed/g' \
  -e $'s/\x1b\[[0-9;]*m//g'
