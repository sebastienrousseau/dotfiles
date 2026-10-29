#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091
# Route fragments (P2.1): each plugin's plugins/<domain>/commands.txt and
# lib/dot/data/groups.txt merge, through lib/dot/table-merge.awk, into
# exactly the command table bin/dot reads (lib/dot/data/commands.txt), and
# the generator's Python merge() agrees. Planted fragments pin each merge
# rule: bucket order (hook records last), the first run record of an
# invocation, and leg records only for legacy routes.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

MERGE="$REPO_ROOT/lib/dot/table-merge.awk"
TABLE="$REPO_ROOT/lib/dot/data/commands.txt"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/dot-merge.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

# fragments: the shipped fragment set, groups first, then domain order.
fragments() {
  printf '%s\n' "$REPO_ROOT/lib/dot/data/groups.txt"
  find "$REPO_ROOT/plugins" -mindepth 2 -maxdepth 2 -name commands.txt | LC_ALL=C sort
}

test_start "every_plugin_has_a_fragment"
for manifest in "$REPO_ROOT"/plugins/*/dot-plugin.toml; do
  assert_file_exists "${manifest%/*}/commands.txt" "$(basename "${manifest%/*}") ships its route fragment"
done

test_start "the_fragments_merge_to_the_table"
grep -v '^#' "$TABLE" >"$WORK/table"
fragments | tr '\n' '\0' | xargs -0 awk -f "$MERGE" >"$WORK/merged"
assert_equals "" "$(diff "$WORK/table" "$WORK/merged")" "awk merge of the shipped fragments is the table"

# gawk accepts extensions a macOS awk would reject; --posix turns them off.
if awk --version 2>/dev/null | grep -q 'GNU Awk'; then
  test_start "the_merge_is_posix_awk"
  fragments | tr '\n' '\0' | xargs -0 awk --posix -f "$MERGE" >"$WORK/posix"
  assert_equals "" "$(diff "$WORK/table" "$WORK/posix")" "gawk --posix merges the same table"
fi

test_start "the_generator_merge_agrees"
rc=0
python3 - "$REPO_ROOT" >"$WORK/py" 2>&1 <<'PY' || rc=$?
import pathlib, sys
root = pathlib.Path(sys.argv[1])
sys.path.insert(0, str(root / "tools" / "ci"))
import cli_command_table as t
texts = [(root / t.GROUPS).read_text()]
texts += [(root / "plugins" / d / t.FRAGMENT).read_text() for d in sorted(t.load(root))]
sys.exit(0 if t.merge(texts) == t.records((root / t.TABLE).read_text()) else 1)
PY
assert_equals "0" "$rc" "merge() of the fragments is the table ($(tail -1 "$WORK/py"))"

# ── merge rules, on planted fragments ────────────────────────────────────
cat >"$WORK/a.txt" <<'EOF'
# a comment, dropped

dom|alpha|status|@alpha|first
cmd|alpha status|@alpha status|read|built by the entry
cmd|alpha old|oldroute|read|a legacy route
run|alpha old --x|oldroute||
flag|alpha status|--json|||as JSON
hook|on-apply|alpha|libexec/hooks/a.sh|alpha's hook, read before its alias
alias|al|shortcut|alpha status|
EOF
cat >"$WORK/b.txt" <<'EOF'
dom|beta|list||second
cmd|beta list|oldroute|read|the same legacy route, later
run|alpha old --x|@alpha old --x||
arg|beta list|one two||
hook|on-apply|beta|libexec/hooks/b.sh|beta's hook
EOF
printf 'grp|g|Group|alpha beta|\n' >"$WORK/g.txt"
awk -f "$MERGE" "$WORK/g.txt" "$WORK/a.txt" "$WORK/b.txt" >"$WORK/rules"

test_start "merge_orders_the_buckets"
assert_equals "grp dom cmd cmd dom cmd run leg flag arg alias hook hook" \
  "$(cut -d'|' -f1 "$WORK/rules" | tr '\n' ' ' | sed 's/ $//')" \
  "grp, dom/obj/cmd in fragment order, run, leg, flag/arg, alias, hook"

test_start "merge_keeps_hooks_in_domain_order"
assert_equals "alpha beta" "$(grep '^hook|' "$WORK/rules" | cut -d'|' -f3 | tr '\n' ' ' | sed 's/ $//')" \
  "each plugin's hooks, in the order the fragments are read"

test_start "merge_keeps_the_first_run_of_an_invocation"
assert_equals "run|alpha old --x|oldroute||" "$(grep '^run|' "$WORK/rules")" "the later fragment's run is dropped"

test_start "merge_derives_one_leg_per_legacy_route"
assert_equals "leg|oldroute|alpha old||" "$(grep '^leg|' "$WORK/rules")" \
  "the first spelling that runs a legacy route; @ routes are entries, not legacy"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
