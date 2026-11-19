#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091
# defaults/private_dot_netrc.tmpl, rendered by chezmoi: ~/.netrc is
# plaintext that every same-user process (AI agents included) can read, so
# a GitHub token never lands in it (the gh credential helper covers git),
# while GitLab and Hugging Face tokens render from plain data, from
# 1Password (op stubbed here) or not at all.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

if ! command -v chezmoi >/dev/null 2>&1; then
  echo "SKIP: chezmoi not installed"
  echo "RESULTS:0:0:0"
  exit 0
fi

TEMPLATE="$REPO_ROOT/defaults/private_dot_netrc.tmpl"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/cz" "$WORK/bin" "$WORK/src"

# op stub: `op signin --raw` prints a session, `op … read … <ref>` prints a
# token derived from the reference; every call is logged.
cat >"$WORK/bin/op" <<'STUB'
#!/bin/sh
echo "op $*" >>"$HOME/op.log"
case " $* " in
  *" signin "*) echo session ;;
  *" read "*) for a in "$@"; do ref="$a"; done; printf 'op:%s' "$ref" ;;
  *) echo '[]' ;;
esac
STUB
chmod +x "$WORK/bin/op"

# render <config-toml>: the template rendered with that chezmoi config.
render() {
  printf '%s\n' "$1" >"$WORK/cz/chezmoi.toml"
  rm -f "$WORK/cz/op.log"
  env -i HOME="$WORK/cz" PATH="$WORK/bin:$PATH" chezmoi --config "$WORK/cz/chezmoi.toml" \
    --source "$WORK/src" --persistent-state "$WORK/cz/state" \
    execute-template <"$TEMPLATE"
}

ALL='[data]
github_token = "gh1"
gitlab_token = "gl1"
huggingface_token = "hf1"'

test_start "netrc_never_holds_a_github_token"
out="$(render "$ALL")"
assert_false '[[ "$out" == *github* ]]' "no github.com or api.github.com entry"
assert_false '[[ "$out" == *gh1* ]]' "the GitHub token is not written"

test_start "netrc_keeps_gitlab_and_huggingface_from_data"
assert_contains $'machine gitlab.com\nlogin' "$out" "GitLab entry"
assert_contains "password gl1" "$out" "GitLab token"
assert_contains $'machine huggingface.co\nlogin' "$out" "Hugging Face entry"
assert_contains "password hf1" "$out" "Hugging Face token"

test_start "netrc_is_empty_without_tokens"
assert_equals "" "$(render '[data]')" "no data, no entries"
assert_equals "" "$(render $'[data]\ngithub_token = "gh1"')" "a GitHub token alone renders nothing"

test_start "netrc_reads_a_token_from_1password"
out="$(render $'[data.netrc.onepassword]\n"huggingface.co" = "op://Private/HF/token"')"
assert_contains $'machine huggingface.co\nlogin' "$out" "Hugging Face entry from 1Password"
assert_contains "password op:op://Private/HF/token" "$out" "token is the op read result"
assert_false '[[ "$out" == *gitlab* ]]' "no GitLab entry without a GitLab source"

test_start "netrc_plain_data_wins_and_op_is_not_called"
render $'[data]\nhuggingface_token = "hf2"\n[data.netrc.onepassword]\n"huggingface.co" = "op://x"' >"$WORK/out"
assert_file_contains "$WORK/out" "password hf2" "plain data is used"
assert_file_not_exists "$WORK/cz/op.log" "op is not run"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
