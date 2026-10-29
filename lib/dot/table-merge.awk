# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
#
# table-merge.awk: merge route fragments into the command table (P2.1).
#
#   awk -f lib/dot/table-merge.awk lib/dot/data/groups.txt plugins/*/commands.txt
#
# The fragments are lib/dot/data/groups.txt (the grp records) and each
# plugin's commands.txt, given in domain order. The table they make is the
# one tools/ci/cli_command_table.py writes to lib/dot/data/commands.txt,
# record for record (its merge() is this merge in Python):
#
#   grp, then every dom/obj/cmd in the order read, then the run records
#   (the first of each invocation), then a leg record for each legacy route
#   a cmd or run record names (the first spelling that runs it; a route
#   that starts with @ is a plugin entry, not a legacy route), then flag and
#   arg, then alias, then hook.
#
# Comments and blank lines are dropped. POSIX awk: no gawk extensions, so it
# runs on macOS's awk too.

BEGIN { FS = "|"; nb = ng = nr = nc = na = nh = 0 }

/^#/ || /^$/ { next }

$1 == "grp" { grp[++ng] = $0; next }
$1 == "dom" || $1 == "obj" || $1 == "cmd" { body[++nb] = $0; next }
$1 == "run" {
  if (!($2 in ran)) { ran[$2] = 1; run[++nr] = $0 }
  next
}
$1 == "flag" || $1 == "arg" { comp[++nc] = $0; next }
$1 == "alias" { alias[++na] = $0; next }
$1 == "hook" { hook[++nh] = $0; next }

# leg_of ROW: print a leg record for ROW's legacy route, the first time.
function leg_of(row,   f) {
  split(row, f, "|")
  if ((f[1] == "cmd" || f[1] == "run") && f[3] != "" && substr(f[3], 1, 1) != "@" && !(f[3] in legs)) {
    legs[f[3]] = 1
    print "leg|" f[3] "|" f[2] "||"
  }
}

END {
  for (i = 1; i <= ng; i++) print grp[i]
  for (i = 1; i <= nb; i++) print body[i]
  for (i = 1; i <= nr; i++) print run[i]
  for (i = 1; i <= nb; i++) leg_of(body[i])
  for (i = 1; i <= nr; i++) leg_of(run[i])
  for (i = 1; i <= nc; i++) print comp[i]
  for (i = 1; i <= na; i++) print alias[i]
  for (i = 1; i <= nh; i++) print hook[i]
}
