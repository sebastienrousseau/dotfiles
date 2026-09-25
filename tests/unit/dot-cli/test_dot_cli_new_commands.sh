#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2016,SC2034
# Behavioural tests for the restructured dot CLI commands (Waves 1-4):
# hidden aliases (verify, scorecard/score, snapshot, heal, update), the
# dot_require_platform guard, doctor -> doctor-unified.sh, sync --pull /
# --check, env, profile and keys sign-check.
#
# Every command runs through bin/dot. bin/dot, lib/dot/, scripts/dot/ and
# scripts/diagnostics/doctor-unified.sh are copied into a sandbox source
# tree, and the leaf scripts they hand off to (scripts/diagnostics/*.sh,
# scripts/ops/*.sh) are replaced there by stubs that record how they were
# called — so routing is observed without applying, healing or snapshotting
# anything. `profile set` rewrites the sandbox copy of .chezmoidata.toml,
# never the real one. HOME and XDG_* point into the sandbox; mise is a stub.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

REAL_BASH="${BASH:-$(command -v bash)}"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/dot-cli-new.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

SANDBOX_HOME="$WORK/home"
SRC="$WORK/src"
STUBS="$WORK/stubs"
CALLS="$WORK/calls"
OUT="$WORK/out"
ERR="$WORK/err"
mkdir -p "$SANDBOX_HOME/.config" "$SANDBOX_HOME/.cache" "$SANDBOX_HOME/.local/share" \
  "$SANDBOX_HOME/.local/state" "$SRC/bin" "$SRC/lib" "$SRC/scripts/diagnostics" \
  "$SRC/scripts/ops" "$SRC/defaults" "$STUBS"

echo "Testing restructured CLI commands..."

# --- Sandbox source tree: the real routers, stubbed leaf scripts ------------
cp "$REPO_ROOT/bin/dot" "$SRC/bin/dot"
cp -R "$REPO_ROOT/lib/dot" "$SRC/lib/dot"
cp -R "$REPO_ROOT/scripts/dot" "$SRC/scripts/dot"
cp "$REPO_ROOT/scripts/diagnostics/doctor-unified.sh" "$SRC/scripts/diagnostics/doctor-unified.sh"
cp "$REPO_ROOT/.chezmoiroot" "$SRC/.chezmoiroot"
cp "$REPO_ROOT/defaults/.chezmoidata.toml" "$SRC/defaults/.chezmoidata.toml"

for leaf in scripts/diagnostics/verify.sh scripts/diagnostics/scorecard.sh \
  scripts/diagnostics/snapshot.sh scripts/diagnostics/doctor.sh \
  scripts/diagnostics/health.sh scripts/ops/heal.sh scripts/ops/chezmoi-apply.sh \
  scripts/ops/chezmoi-update.sh scripts/ops/chezmoi-diff.sh; do
  cat >"$SRC/$leaf" <<EOF
#!/usr/bin/env bash
printf 'ran %s %s\n' "$leaf" "\$*"
exit "\${STUB_RC:-0}"
EOF
done

# bash on PATH is the interpreter running this suite (not /bin/bash 3.2).
ln -s "$REAL_BASH" "$STUBS/bash"
# mise: `ls --json` reports one tool; everything else is recorded.
cat >"$STUBS/mise" <<EOF
#!$REAL_BASH
printf 'mise %s\n' "\$*" >>"$CALLS"
case "\$1 \${2:-}" in
  "ls --json") printf '{"node":[{"version":"22.1.0","requested_version":"22","source":{"path":"/cfg/mise.toml"}}]}\n' ;;
  "ls ") printf 'node 22.1.0 /cfg/mise.toml 22\n' ;;
esac
exit 0
EOF
chmod +x "$STUBS/mise"

# dot <args…> — run the sandbox bin/dot with a clean environment. Stdout
# and stderr are captured; the exit status is returned.
dot() {
  : >"$CALLS"
  command env -i HOME="$SANDBOX_HOME" PATH="$STUBS:/usr/bin:/bin" \
    XDG_CONFIG_HOME="$SANDBOX_HOME/.config" XDG_CACHE_HOME="$SANDBOX_HOME/.cache" \
    XDG_DATA_HOME="$SANDBOX_HOME/.local/share" XDG_STATE_HOME="$SANDBOX_HOME/.local/state" \
    GIT_CONFIG_NOSYSTEM=1 NO_COLOR=1 TERM=dumb DOTFILES_SHOW_LOGO=0 LANG=C \
    STUB_RC="${STUB_RC:-0}" \
    "$REAL_BASH" "$SRC/bin/dot" "$@" </dev/null >"$OUT" 2>"$ERR"
}
out() { cat "$OUT" "$ERR"; }
refute_contains() { # <needle> <actual> <msg>
  if [[ "$2" != *"$1"* ]]; then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: $3"
  else
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: $3"
    printf '%b\n' "    Unexpected: '$1' in '$2'"
  fi
}

# --- Existing commands still route (hidden aliases) -------------------------

test_start "dot_cli_routes_verify_handler"
# `dot verify` was withdrawn from the public route table (HARD_AUDIT C3), but
# the diagnostics module still owns the handler; drive it directly.
command env -i HOME="$SANDBOX_HOME" PATH="$STUBS:/usr/bin:/bin" NO_COLOR=1 \
  DOTFILES_SHOW_LOGO=0 "$REAL_BASH" "$SRC/scripts/dot/commands/diagnostics.sh" verify -s \
  </dev/null >"$OUT" 2>"$ERR"
assert_equals "0" "$?" "diagnostics verify exits 0"
assert_contains "ran scripts/diagnostics/verify.sh -s" "$(out)" "verify hands off to verify.sh with its flags"

test_start "dot_cli_routes_scorecard_and_score"
dot scorecard --json
assert_equals "0" "$?" "dot scorecard exits 0"
assert_contains "ran scripts/diagnostics/scorecard.sh --json" "$(out)" "scorecard runs scorecard.sh"
dot score -q
assert_contains "ran scripts/diagnostics/scorecard.sh -q" "$(out)" "score is an alias of scorecard"
STUB_RC=3 dot score
assert_equals "3" "$?" "the scorecard exit status is dot's exit status"

test_start "dot_cli_routes_snapshot"
dot snapshot -b
assert_equals "0" "$?" "dot snapshot exits 0"
assert_contains "ran scripts/diagnostics/snapshot.sh -b" "$(out)" "snapshot runs snapshot.sh"

test_start "dot_cli_routes_heal"
dot heal --dry-run
assert_equals "0" "$?" "dot heal exits 0"
assert_contains "ran scripts/ops/heal.sh --dry-run" "$(out)" "heal runs heal.sh"

test_start "dot_cli_routes_update_alias"
dot update
assert_equals "0" "$?" "dot update exits 0"
assert_contains "ran scripts/ops/chezmoi-update.sh" "$(out)" "update pulls through chezmoi-update.sh"

# --- Wave 1: dot_require_platform -------------------------------------------

test_start "dot_require_platform_allows_and_refuses"
cat >"$STUBS/uname" <<EOF
#!$REAL_BASH
echo "\$FAKE_UNAME"
EOF
chmod +x "$STUBS/uname"
require() { # <fake uname> <platforms…>
  local fake="$1"
  shift
  command env -i PATH="$STUBS:/usr/bin:/bin" FAKE_UNAME="$fake" _DOT_IS_WSL=1 \
    "$REAL_BASH" -c 'source "$1"; shift; dot_require_platform "$@"; echo allowed' \
    _ "$REPO_ROOT/lib/dot/platform.sh" "$@" >"$OUT" 2>"$ERR"
}
require Linux linux wsl
assert_equals "0" "$?" "Linux satisfies 'linux wsl'"
assert_contains "allowed" "$(out)" "the caller continues after the guard"
require Darwin macos
assert_equals "0" "$?" "Darwin satisfies 'macos'"
require Darwin linux wsl
assert_equals "2" "$?" "Darwin is refused for 'linux wsl' with exit 2"
assert_contains "requires linux wsl (detected: macos)" "$(out)" "the refusal names the requirement and the host"
refute_contains "allowed" "$(out)" "the caller does not continue after a refusal"
rm -f "$STUBS/uname"

# --- Wave 2: doctor dispatches through doctor-unified.sh --------------------

test_start "dot_cli_doctor_dispatches_unified"
dot doctor
assert_equals "0" "$?" "dot doctor exits 0"
assert_contains "ran scripts/diagnostics/doctor.sh" "$(out)" "a bare doctor runs doctor.sh"
dot doctor --score -j
assert_contains "ran scripts/diagnostics/scorecard.sh -j" "$(out)" "doctor --score is mapped by doctor-unified.sh"
dot doctor -H
assert_contains "ran scripts/ops/heal.sh" "$(out)" "doctor -H heals"
dot doctor --audit
assert_contains "ran scripts/diagnostics/health.sh" "$(out)" "doctor --audit runs the health dashboard"

# --- Wave 3: sync with flags ------------------------------------------------

test_start "dot_cli_sync_applies"
dot sync --verbose
assert_equals "0" "$?" "dot sync exits 0"
assert_contains "ran scripts/ops/chezmoi-apply.sh --verbose" "$(out)" "sync applies and forwards its flags"

test_start "dot_cli_sync_pull_flag"
dot sync --pull
assert_equals "0" "$?" "dot sync --pull exits 0"
assert_contains "ran scripts/ops/chezmoi-update.sh" "$(out)" "sync --pull fetches through chezmoi-update.sh"
refute_contains "chezmoi-apply.sh" "$(out)" "sync --pull does not hand --pull to chezmoi apply"
refute_contains "--pull" "$(out)" "the --pull flag is consumed, not forwarded"

test_start "dot_cli_sync_check_flag"
dot sync --check --exclude=scripts
assert_equals "0" "$?" "dot sync --check exits 0"
assert_contains "ran scripts/ops/chezmoi-diff.sh --exclude=scripts" "$(out)" "sync --check previews through chezmoi-diff.sh"
refute_contains "chezmoi-apply.sh" "$(out)" "sync --check applies nothing"

# --- Wave 3: env ------------------------------------------------------------

test_start "dot_cli_env_lists_mise_tools"
dot env
assert_equals "0" "$?" "dot env exits 0"
assert_contains "node" "$(out)" "the managed tool is listed"
assert_contains "22.1.0" "$(out)" "its version is listed"

test_start "dot_cli_env_use_forwards_to_mise"
dot env use node@22
assert_equals "0" "$?" "dot env use exits 0"
assert_file_contains "$CALLS" "mise use node@22" "env use pins through mise"
dot env install --yes aqua:nushell/nushell@0.114.1 npm:@openai/codex@latest
assert_equals "0" "$?" "backend-prefixed specs are accepted"
assert_file_contains "$CALLS" "mise install --yes aqua:nushell/nushell@0.114.1 npm:@openai/codex@latest" \
  "env install forwards flags and specs to mise"

test_start "dot_cli_env_rejects_unsafe_tool_names"
dot env install 'node;touch pwned'
assert_not_equals "0" "$?" "an unsafe tool name is refused"
refute_contains "mise install" "$(cat "$CALLS")" "mise is never called with the unsafe name"

# --- Wave 4: profile --------------------------------------------------------

test_start "dot_cli_profile_show"
dot profile
assert_equals "0" "$?" "dot profile exits 0"
assert_contains "laptop" "$(out)" "the active profile is shown"
assert_contains "alias_wrapper" "$(out)" "feature flags are listed"

test_start "dot_cli_profile_set"
dot profile set work
assert_equals "0" "$?" "dot profile set exits 0"
dot profile show
assert_contains "work" "$(out)" "the new profile is persisted and shown"
refute_contains "laptop" "$(out)" "the old profile is replaced"
dot profile bogus
assert_not_equals "0" "$?" "an unknown profile subcommand fails"

# --- Wave 4: keys sign-check ------------------------------------------------

test_start "dot_cli_keys_sign_check"
dot keys sign-check
assert_equals "0" "$?" "sign-check exits 0 with no key"
assert_contains "No signing key configured" "$(out)" "a missing signing key is reported"
mkdir -p "$SANDBOX_HOME/.ssh"
printf '[user]\n\tsigningkey = ~/.ssh/signing.pub\n[gpg]\n\tformat = ssh\n' >"$SANDBOX_HOME/.gitconfig"
dot keys sign-check
assert_contains "SSH key file not found" "$(out)" "an absent SSH key file is reported"
: >"$SANDBOX_HOME/.ssh/signing.pub"
dot keys sign-check
assert_contains "SSH key file exists: $SANDBOX_HOME/.ssh/signing.pub" "$(out)" "a present SSH key is found with ~ expanded"

echo ""
echo "Restructured CLI command tests completed."
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
