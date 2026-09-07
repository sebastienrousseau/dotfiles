#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
#
# Behaviour tests for scripts/diagnostics/a2a-conformance.sh. The
# script honours $REPO_ROOT, so every case builds a throwaway agent-card
# tree and asserts the exact issue it should raise: a healthy tree, each
# missing document, the specVersion / skills / authentication / signing
# / capabilities / protocol checks, the internal-card and legacy-doc
# cross-checks, name consistency, the default-profile lookup, card
# signing, both output modes and the --strict exit code.
#
# AUTO-GENERATED: false (hand-written)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

# Hand children a copy of the real stderr so their xtrace still reaches
# the coverage runner even though the probes capture output with 2>&1.
exec 21>&2
export BASH_XTRACEFD=21

A2A="$REPO_ROOT/scripts/diagnostics/a2a-conformance.sh"
BASH_BIN="$(command -v bash)"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

if ! command -v jq >/dev/null 2>&1; then
  echo "SKIP: jq is required for these fixtures"
  echo "RESULTS:0:0:0"
  exit 0
fi

# _fixture <name> — a conformant agent-card tree; prints its root.
_fixture() {
  local root="$DOTFILES_COV_TMPDIR/$1"
  mkdir -p "$root/.well-known" "$root/defaults/dot_config/dotfiles"
  cat >"$root/.well-known/agent-card.json" <<'JSON'
{
  "name": "dotfiles",
  "specVersion": "0.3",
  "protocols": ["a2a"],
  "skills": [{"id": "doctor"}],
  "authentication": {"schemes": ["none"]},
  "signing": {"method": "ssh-ed25519"},
  "capabilities": {"streaming": false}
}
JSON
  cat >"$root/.well-known/agent.json" <<'JSON'
{"name": "dotfiles", "protocols": ["a2a"], "a2aCard": "/.well-known/agent-card.json"}
JSON
  cat >"$root/defaults/dot_config/dotfiles/agent-card.json" <<'JSON'
{
  "name": "dotfiles",
  "specVersion": "0.3",
  "protocols": ["a2a"],
  "defaultProfile": "ask",
  "security": {"cardSigning": {"required": true}}
}
JSON
  cat >"$root/defaults/dot_config/dotfiles/agent-profiles.json" <<'JSON'
{"profiles": {"ask": {"description": "read-only"}}}
JSON
  printf '%s\n' "$root"
}

_conform() { # <root> [args…]
  REPO_ROOT="$1" "$BASH_BIN" "$A2A" "${@:2}" 2>&1
}

# _issues <root> — the issue strings from --json output, one per line.
_issues() {
  _conform "$1" --json | jq -r '.issues[]'
}

test_start "a2a_healthy_tree_reports_healthy_in_both_modes"
_root="$(_fixture healthy)"
_out="$(_conform "$_root" --json)"
_rc=$?
assert_equals 0 "$_rc" "healthy tree exits 0"
assert_equals "healthy" "$(printf '%s' "$_out" | jq -r '.status')" "status is healthy"
assert_equals "0.3" "$(printf '%s' "$_out" | jq -r '.specVersion')" "spec version reported"
assert_equals "0" "$(printf '%s' "$_out" | jq -r '.issues | length')" "no issues"
assert_equals "false" "$(printf '%s' "$_out" | jq -r '.strict')" "strict flag defaults to false"
_out="$(_conform "$_root")"
assert_contains "A2A v0.3 Conformance" "$_out" "human-readable header printed"
assert_contains "healthy" "$_out" "human-readable status printed"

test_start "a2a_strict_flag_is_reported_and_kept_green_when_healthy"
_out="$(_conform "$_root" --strict --json)"
_rc=$?
assert_equals 0 "$_rc" "strict on a healthy tree exits 0"
assert_equals "true" "$(printf '%s' "$_out" | jq -r '.strict')" "strict flag recorded"
_out="$(_conform "$_root" -s -j)"
assert_equals "true" "$(printf '%s' "$_out" | jq -r '.strict')" "short flags are equivalent"

test_start "a2a_ignores_unknown_arguments"
_out="$(_conform "$_root" --json --whatever extra)"
assert_equals "healthy" "$(printf '%s' "$_out" | jq -r '.status')" "unknown args do not change the verdict"

test_start "a2a_reports_each_missing_document"
_root="$(_fixture missing)"
rm -f "$_root/.well-known/agent-card.json" \
  "$_root/.well-known/agent.json" \
  "$_root/defaults/dot_config/dotfiles/agent-card.json" \
  "$_root/defaults/dot_config/dotfiles/agent-profiles.json"
_out="$(_conform "$_root" --json)"
assert_equals "issues" "$(printf '%s' "$_out" | jq -r '.status')" "status flips to issues"
_list="$(printf '%s' "$_out" | jq -r '.issues[]')"
assert_contains "missing:.well-known/agent-card.json" "$_list" "primary card reported"
assert_contains "missing:.well-known/agent.json" "$_list" "legacy doc reported"
assert_contains "missing:agent-card.json" "$_list" "internal card reported"
assert_contains "missing:agent-profiles.json" "$_list" "profiles reported"

test_start "a2a_human_output_lists_the_issues"
_out="$(_conform "$_root")"
assert_contains "Issue" "$_out" "issues are rendered in human mode"
assert_contains "missing:agent-profiles.json" "$_out" "the specific issue is shown"

test_start "a2a_strict_mode_fails_when_issues_exist"
_out="$(_conform "$_root" --strict)"
_rc=$?
assert_equals 1 "$_rc" "strict + issues exits 1"
_out="$(_conform "$_root")"
_rc=$?
assert_equals 0 "$_rc" "without --strict the same tree exits 0"

test_start "a2a_flags_a_wrong_spec_version_and_a2a_ready_protocol"
_root="$(_fixture badspec)"
_card="$_root/.well-known/agent-card.json"
jq '.specVersion = "0.2" | .protocols = ["a2a-ready"]' "$_card" >"$_card.tmp" && mv "$_card.tmp" "$_card"
_list="$(_issues "$_root")"
assert_contains "specVersion:expected 0.3, got 0.2" "$_list" "spec version mismatch named with both values"
assert_contains "protocols:should use 'a2a' not 'a2a-ready'" "$_list" "legacy protocol name rejected"
assert_contains "protocols:missing 'a2a'" "$_list" "missing canonical protocol reported"

test_start "a2a_flags_missing_card_sections"
_root="$(_fixture sections)"
_card="$_root/.well-known/agent-card.json"
jq 'del(.skills, .authentication, .signing, .capabilities)' "$_card" >"$_card.tmp" && mv "$_card.tmp" "$_card"
_list="$(_issues "$_root")"
assert_contains "skills:missing or not array" "$_list" "skills section required"
assert_contains "skills:empty array" "$_list" "empty skills reported"
assert_contains "authentication:missing" "$_list" "authentication required"
assert_contains "signing:missing method" "$_list" "signing method required"
assert_contains "capabilities:missing" "$_list" "capabilities required"

test_start "a2a_flags_an_empty_skills_array"
_root="$(_fixture emptyskills)"
_card="$_root/.well-known/agent-card.json"
jq '.skills = []' "$_card" >"$_card.tmp" && mv "$_card.tmp" "$_card"
_list="$(_issues "$_root")"
assert_contains "skills:empty array" "$_list" "an empty array is still an issue"
assert_output_not_contains "skills:missing or not array" printf '%s' "$_list"

test_start "a2a_cross_checks_the_internal_card"
_root="$(_fixture internal)"
_ic="$_root/defaults/dot_config/dotfiles/agent-card.json"
jq '.specVersion = "0.2" | .protocols = ["a2a-ready"] | del(.security)' "$_ic" >"$_ic.tmp" && mv "$_ic.tmp" "$_ic"
_list="$(_issues "$_root")"
assert_contains "internal-card:specVersion expected 0.3" "$_list" "internal spec version checked"
assert_contains "internal-card:should use 'a2a' not 'a2a-ready'" "$_list" "internal protocol checked"
assert_contains "internal-card:missing cardSigning in security" "$_list" "card signing required"

test_start "a2a_cross_checks_the_legacy_document"
_root="$(_fixture legacy)"
_ld="$_root/.well-known/agent.json"
jq 'del(.a2aCard) | .protocols = ["a2a-ready"]' "$_ld" >"$_ld.tmp" && mv "$_ld.tmp" "$_ld"
_list="$(_issues "$_root")"
assert_contains "legacy:missing a2aCard pointer" "$_list" "pointer to the new card required"
assert_contains "legacy:should use 'a2a' not 'a2a-ready'" "$_list" "legacy protocol name rejected"

test_start "a2a_requires_consistent_names_across_the_three_documents"
_root="$(_fixture names)"
_ic="$_root/defaults/dot_config/dotfiles/agent-card.json"
_ld="$_root/.well-known/agent.json"
jq '.name = "other"' "$_ic" >"$_ic.tmp" && mv "$_ic.tmp" "$_ic"
jq '.name = "different"' "$_ld" >"$_ld.tmp" && mv "$_ld.tmp" "$_ld"
_list="$(_issues "$_root")"
assert_contains "name:mismatch between a2a-card and internal card" "$_list" "internal-card name checked"
assert_contains "name:mismatch between a2a-card and legacy doc" "$_list" "legacy name checked"

test_start "a2a_requires_the_default_profile_to_exist"
_root="$(_fixture profile)"
_ap="$_root/defaults/dot_config/dotfiles/agent-profiles.json"
jq '.profiles = {"other": {}}' "$_ap" >"$_ap.tmp" && mv "$_ap.tmp" "$_ap"
_list="$(_issues "$_root")"
assert_contains "default-profile:missing in agent-profiles.json" "$_list" "unknown default profile reported"

test_start "a2a_requires_jq"
_root="$(_fixture nojq)"
_bare="$DOTFILES_COV_TMPDIR/bare-a2a"
mkdir -p "$_bare"
for _t in bash cat printf echo sed tr uname dirname basename tput; do
  _p="$(command -v "$_t" 2>/dev/null || true)"
  [[ -n "$_p" ]] && ln -sf "$_p" "$_bare/$_t"
done
_out="$(REPO_ROOT="$_root" PATH="$_bare" "$BASH_BIN" "$A2A" --json 2>&1)"
_rc=$?
assert_equals 1 "$_rc" "missing jq exits 1"
assert_contains "jq is required" "$_out" "prerequisite named"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
