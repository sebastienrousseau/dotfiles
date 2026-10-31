#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2016
# The plugin SDK (lib/dot/sdk.sh): bin/dot hands a plugin its own lib/dot
# as DOT_SDK whatever the environment holds, a plugin loads the SDK through
# it, and loading the SDK exports its own directory as DOT_SDK.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

# Whether `dot theme list` itself succeeds depends on the host's theme data;
# what matters is where the plugin loaded the SDK from. Without the
# override it fails with "/nonexistent/sdk.sh: No such file or directory".
test_start "dispatch_gives_a_plugin_the_host_sdk"
err="$(DOT_SDK=/nonexistent DOTFILES_NONINTERACTIVE=1 bash "$REPO_ROOT/bin/dot" theme list 2>&1 >/dev/null)" || true
assert_equals "no" "$([[ "$err" == *"sdk.sh: No such file"* ]] && echo yes || echo no)" "a plugin loads the SDK with a stray DOT_SDK in the environment"
assert_equals "no" "$([[ "$err" == *"/nonexistent/"* ]] && echo yes || echo no)" "and never loads from it"

test_start "loading_the_sdk_exports_its_own_directory"
out="$(DOT_SDK=/elsewhere bash -c 'set -euo pipefail; source "$1/lib/dot/sdk.sh"; printf "%s\n" "$DOT_SDK"' _ "$REPO_ROOT")"
assert_equals "$REPO_ROOT/lib/dot" "$out" "DOT_SDK names the SDK that loaded"

test_start "the_sdk_brings_the_helpers_plugins_use"
out="$(bash -c 'set -euo pipefail; source "$1/lib/dot/sdk.sh"
  for f in resolve_source_dir run_script require_source_dir resolve_chezmoi_source_dir has_command \
    validate_name die warn info dotfiles_version dot_ui_command_banner ui_ok; do
    declare -F "$f" >/dev/null || echo "missing $f"
  done
  declare -F check_cmd >/dev/null && echo "host helper check_cmd leaked into the SDK"
  echo done' _ "$REPO_ROOT")"
assert_equals "done" "$out" "the SDK defines what plugins call and none of the host-only helpers"

test_start "summaries_prefer_the_plugins_own_command"
out="$(bash -c 'source "$1/lib/dot/sdk.sh"; DOT_DOMAIN=config dot_command_summary status; dot_command_summary status' _ "$REPO_ROOT")"
assert_equals $'Pending changes and last apply\nRun a dotfiles command.' "$out" \
  "with DOT_DOMAIN=config, status is config status; without a domain it is not a command"

# The source-tree resolvers, from a copy of the SDK outside any checkout so
# the location probe finds nothing and the fallbacks decide.
WORK="$(mktemp -d "${TMPDIR:-/tmp}/dot-sdk.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/sdk" "$WORK/home/.dotfiles" "$WORK/tree/defaults"
for f in sdk.sh ui.sh platform.sh preflight.sh data; do ln -s "$REPO_ROOT/lib/dot/$f" "$WORK/sdk/$f"; done
printf '{\n  "version": "1.2.3"\n}\n' >"$WORK/tree/package.json"

# in_sdk SNIPPET [VAR=value...]: SNIPPET's output with the detached SDK loaded.
in_sdk() {
  local snippet="$1"
  shift
  env -i ${BASH_ENV:+BASH_ENV="$BASH_ENV"} ${PS4:+PS4="$PS4"} PATH="$PATH" HOME="$WORK/home" "$@" \
    bash -c 'source "$1/sdk.sh"; '"$snippet" _ "$WORK/sdk" 2>/dev/null
}

test_start "a_missing_chezmoi_source_dir_is_skipped"
assert_equals "$WORK/home/.dotfiles" "$(in_sdk resolve_source_dir CHEZMOI_SOURCE_DIR="$WORK/gone")" \
  "a CHEZMOI_SOURCE_DIR that does not exist falls through to ~/.dotfiles"

test_start "a_stale_cached_source_dir_is_not_returned"
assert_equals "$WORK/tree" "$(in_sdk "_DOT_SOURCE_DIR_CACHE='$WORK/gone'; resolve_source_dir" CHEZMOI_SOURCE_DIR="$WORK/tree")" \
  "a cached directory that has gone is resolved again"

test_start "chezmoiroot_naming_a_missing_subdir_is_ignored"
printf 'nosuch\n' >"$WORK/tree/.chezmoiroot"
assert_equals "$WORK/tree" "$(in_sdk resolve_chezmoi_source_dir CHEZMOI_SOURCE_DIR="$WORK/tree")" \
  "the source root stays the tree when .chezmoiroot names no directory"
printf 'defaults\n' >"$WORK/tree/.chezmoiroot"
assert_equals "$WORK/tree/defaults" "$(in_sdk resolve_chezmoi_source_dir CHEZMOI_SOURCE_DIR="$WORK/tree")" \
  "and descends into the one it names"

test_start "package_json_wins_over_DOTFILES_VERSION"
assert_equals "1.2.3" "$(in_sdk dotfiles_version CHEZMOI_SOURCE_DIR="$WORK/tree" DOTFILES_VERSION=9.9.9)" \
  "the tree's package.json version is used when it has one"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
