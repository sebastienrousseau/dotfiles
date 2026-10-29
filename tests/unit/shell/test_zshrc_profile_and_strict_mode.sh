#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2016
# The zshrc template's profile and alias strict mode. DOTFILES_PROFILE comes
# from chezmoi data unless the session already set one (it used to be
# exported unconditionally, so `DOTFILES_PROFILE=server zsh` was ignored),
# and alias strict mode follows aliases.policy.strict_mode, where
# .chezmoidata.toml defines it (it used to read a top-level key nothing
# sets). Each case renders the real template with chezmoi and runs the
# rendered lines in bash.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

TEMPLATE="$REPO_ROOT/defaults/dot_config/zsh/dot_zshrc.tmpl"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/dot-zshrc-profile.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

if ! command -v chezmoi >/dev/null 2>&1; then
  echo "  chezmoi unavailable: skipped"
  echo "RESULTS:0:0:0"
  exit 0
fi

# render CONFIG: the template rendered with this chezmoi config ([data]).
render() {
  printf '%s\n' "$1" >"$WORK/chezmoi.toml"
  chezmoi --source "$REPO_ROOT/defaults" --config "$WORK/chezmoi.toml" \
    --destination "$WORK/home" execute-template <"$TEMPLATE" 2>/dev/null
}

# value VAR CONFIG [VAR=value...]: VAR after the rendered profile and
# strict-mode lines run in bash, with the given session environment.
value() {
  local var="$1" config="$2"
  shift 2
  render "$config" | grep -E '^(: \$\{DOTFILES_(PROFILE|ALIAS_STRICT_MODE):=|export DOTFILES_PROFILE)' >"$WORK/lines.sh"
  env -i ${BASH_ENV:+BASH_ENV="$BASH_ENV"} ${PS4:+PS4="$PS4"} "$@" \
    bash -c 'source "$1"; eval "printf %s \"\${$2:-}\""' _ "$WORK/lines.sh" "$var"
}

test_start "the_profile_comes_from_chezmoi_data"
assert_equals "server" "$(value DOTFILES_PROFILE '[data]
profile = "server"')" "profile = server in chezmoi.toml"

test_start "a_session_profile_is_kept"
assert_equals "minimal" "$(value DOTFILES_PROFILE '[data]
profile = "server"' DOTFILES_PROFILE=minimal)" "DOTFILES_PROFILE=minimal set before the shell wins"

test_start "strict_mode_follows_aliases_policy"
assert_equals "1" "$(value DOTFILES_ALIAS_STRICT_MODE '[data.aliases.policy]
strict_mode = true')" "aliases.policy.strict_mode = true turns it on"
assert_equals "0" "$(value DOTFILES_ALIAS_STRICT_MODE '[data]
profile = "laptop"')" "the shipped default (false) leaves it off"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
