#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091
# Regression: GitHub closed the SSH session while the pre-push audit ran
# (about nine minutes), so `git push` died with SIGPIPE (exit 141) after
# the hook passed and nothing reached the remote. ~/.ssh/config is not
# managed, so git itself must ask ssh for keepalives.
# Regression for: v0.2.538 tag push
# Why: a long pre-push hook must not silently cancel the push.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"

_ka_tmp="$(mktemp -d -t dotfiles-sshka.XXXXXX)"
trap 'rm -rf "$_ka_tmp"' EXIT
export HOME="$_ka_tmp/home"
export XDG_CONFIG_HOME="$HOME/.config"
export GIT_CONFIG_NOSYSTEM=1
unset GIT_CONFIG_GLOBAL GIT_SSH GIT_SSH_COMMAND
mkdir -p "$HOME" "$_ka_tmp/bin"

_ka_chezmoi="$(command -v chezmoi 2>/dev/null || true)"
if [[ -z "$_ka_chezmoi" ]]; then
  echo "  (skip) chezmoi not available"
  echo "RESULTS:0:0:0"
  exit 0
fi

printf '{}\n' >"$_ka_tmp/chezmoi.json"
"$_ka_chezmoi" --config "$_ka_tmp/chezmoi.json" --source "$REPO_ROOT/defaults" \
  --destination "$HOME" --cache "$_ka_tmp/cache" \
  --persistent-state "$_ka_tmp/state.boltdb" \
  execute-template <"$REPO_ROOT/defaults/dot_gitconfig.tmpl" >"$HOME/.gitconfig" 2>"$_ka_tmp/render.err"

# A stand-in ssh records the arguments git passes and refuses to connect.
cat >"$_ka_tmp/bin/ssh" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$@" >"${KA_ARGS:?}"
exit 255
SH
chmod +x "$_ka_tmp/bin/ssh"

test_start "git_asks_ssh_for_keepalives"
KA_ARGS="$_ka_tmp/args" PATH="$_ka_tmp/bin:$PATH" \
  git ls-remote git@github.com:example/example.git >/dev/null 2>&1
args="$(tr '\n' ' ' <"$_ka_tmp/args" 2>/dev/null)"
assert_contains "ServerAliveInterval=30" "$args" "git runs ssh with a keepalive"

test_summary
