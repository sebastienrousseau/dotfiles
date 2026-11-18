#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091
# defaults/run_onchange_2[4-7]-build-*.sh.tmpl skip with exit 0 when no Go
# toolchain is on PATH, and chezmoi then records the rendered script as run.
# The rendered script must change once Go is installed, or chezmoi never
# runs it again and the binary is never built. Likewise the cockpit's
# DOTFILES_AI opt-in, which the script reads from the environment.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

if ! command -v chezmoi >/dev/null 2>&1; then
  echo "SKIP: chezmoi not installed"
  echo "RESULTS:0:0:0"
  exit 0
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
SRC="$WORK/src"
mkdir -p "$SRC/.chezmoitemplates" "$SRC/dot_local/share" "$WORK/cz" "$WORK/nogo" "$WORK/withgo"
cp "$REPO_ROOT/defaults/.chezmoitemplates/go-build-command" "$SRC/.chezmoitemplates/"
cp "$REPO_ROOT"/defaults/run_onchange_2[4-7]-build-*.sh.tmpl "$SRC/"
for app in dot-ui dot-ai-tui dot-mcp dot-policy; do
  cp -R "$REPO_ROOT/defaults/dot_local/share/$app" "$SRC/dot_local/share/"
done
printf '[data]\ndotfiles_version = "7.7.7"\n' >"$WORK/cz/chezmoi.toml"

# A PATH with the tools the templates need but no go, and one with a go stub.
for tool in chezmoi bash; do
  ln -s "$(command -v "$tool")" "$WORK/nogo/$tool"
done
printf '#!/bin/sh\nexit 0\n' >"$WORK/withgo/go"
chmod +x "$WORK/withgo/go"

# render <template> <PATH> [VAR=value...]: the template rendered by chezmoi.
render() {
  local tmpl="$1" path="$2"
  shift 2
  env -i HOME="$WORK/cz" PATH="$path" "$@" "$WORK/nogo/chezmoi" --config "$WORK/cz/chezmoi.toml" \
    --source "$SRC" --persistent-state "$WORK/cz/state" execute-template <"$SRC/$tmpl"
}

for tmpl in run_onchange_24-build-dot-ui.sh.tmpl run_onchange_25-build-dot-ai-tui.sh.tmpl \
  run_onchange_26-build-dot-mcp.sh.tmpl run_onchange_27-build-dot-policy.sh.tmpl; do
  test_start "${tmpl%%.sh.tmpl}_reruns_once_go_is_installed"
  without="$(render "$tmpl" "$WORK/nogo")"
  with="$(render "$tmpl" "$WORK/withgo:$WORK/nogo")"
  assert_not_empty "$without" "renders without go"
  assert_not_equals "$without" "$with" "installing go changes the rendered script"
done

test_start "dot_ai_tui_reruns_when_opted_in"
off="$(render run_onchange_25-build-dot-ai-tui.sh.tmpl "$WORK/withgo:$WORK/nogo")"
on="$(render run_onchange_25-build-dot-ai-tui.sh.tmpl "$WORK/withgo:$WORK/nogo" DOTFILES_AI=1)"
assert_not_equals "$off" "$on" "setting DOTFILES_AI=1 changes the rendered script"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
