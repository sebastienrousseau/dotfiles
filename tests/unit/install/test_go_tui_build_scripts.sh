#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091
# defaults/run_onchange_24-build-dot-ui.sh.tmpl and
# run_onchange_25-build-dot-ai-tui.sh.tmpl, rendered with chezmoi against a
# copy of their sources: a change to any Go source file (or go.mod/go.sum)
# must change the rendered script, which is what makes chezmoi rerun it; the
# dot-ui build injects the framework version; and the cockpit build honours
# DOTFILES_AI=0 as off.
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
mkdir -p "$SRC/.chezmoitemplates" "$SRC/dot_local/share" "$WORK/cz"
cp "$REPO_ROOT/defaults/.chezmoitemplates/go-build-command" "$SRC/.chezmoitemplates/"
cp "$REPO_ROOT"/defaults/run_onchange_2[45]-build-*.sh.tmpl "$SRC/"
for app in dot-ui dot-ai-tui; do
  mkdir -p "$SRC/dot_local/share/$app"
  cp "$REPO_ROOT/defaults/dot_local/share/$app"/*.go "$REPO_ROOT/defaults/dot_local/share/$app"/go.* \
    "$SRC/dot_local/share/$app/"
done
# The build scripts read dotfiles_version, which .chezmoidata.toml supplies.
printf '[data]\ndotfiles_version = "7.7.7"\n' >"$WORK/cz/chezmoi.toml"

# render <template>: the template rendered by chezmoi against $SRC.
render() {
  env -i HOME="$WORK/cz" PATH="$PATH" chezmoi --config "$WORK/cz/chezmoi.toml" \
    --source "$SRC" --persistent-state "$WORK/cz/state" \
    execute-template <"$SRC/$1"
}

# changes_on_edit <template> <file>: "yes" when appending to the source
# file changes the rendered template.
changes_on_edit() {
  local before after
  before="$(render "$1")"
  printf '\n// edited\n' >>"$SRC/$2"
  after="$(render "$1")"
  if [[ "$before" != "$after" ]]; then echo yes; else echo no; fi
}

UI=run_onchange_24-build-dot-ui.sh.tmpl
test_start "dot_ui_rebuilds_on_any_go_source_change"
for f in pick.go table.go sanitise.go main.go go.mod go.sum; do
  assert_equals "yes" "$(changes_on_edit "$UI" "dot_local/share/dot-ui/$f")" "$f retriggers the build"
done

TUI=run_onchange_25-build-dot-ai-tui.sh.tmpl
render "$TUI" >"$WORK/tui.sh"
mkdir -p "$WORK/stubs"
# go stub: records the build and writes the -o output.
cat >"$WORK/stubs/go" <<'STUB'
#!/usr/bin/env bash
echo "go $*" >>"$HOME/go.calls"
while [[ $# -gt 0 ]]; do
  [[ "$1" == -o ]] && { : >"$2"; break; }
  shift
done
STUB
chmod +x "$WORK/stubs/go"

# tui <name> [VAR=value...]: run the rendered cockpit script in a fresh
# HOME with the source deployed; sets OUT and H.
tui() {
  H="$WORK/$1"
  shift
  mkdir -p "$H/.local/share/dot-ai-tui"
  : >"$H/.local/share/dot-ai-tui/main.go"
  OUT="$(env -i ${BASH_ENV:+BASH_ENV="$BASH_ENV"} ${PS4:+PS4="$PS4"} \
    HOME="$H" PATH="$WORK/stubs:/usr/bin:/bin" "$@" bash "$WORK/tui.sh" 2>&1)"
}

# The dot-ui build sets main.version to dotfiles_version, so `dot-ui
# --version` reports the framework version (it reported 0.2.512 from a
# string in the source); a version bump changes the script, so it reruns.
test_start "dot_ui_build_injects_the_framework_version"
render "$UI" >"$WORK/ui.sh"
printf '[data]\ndotfiles_version = "7.7.8"\n' >"$WORK/cz/chezmoi.toml"
assert_equals "yes" "$([[ "$(render "$UI")" == "$(cat "$WORK/ui.sh")" ]] && echo no || echo yes)" "a version bump changes the rendered script"
printf '[data]\ndotfiles_version = "7.7.7"\n' >"$WORK/cz/chezmoi.toml"
H="$WORK/ui-home"
mkdir -p "$H/.local/share/dot-ui"
: >"$H/.local/share/dot-ui/main.go"
env -i ${BASH_ENV:+BASH_ENV="$BASH_ENV"} ${PS4:+PS4="$PS4"} \
  HOME="$H" PATH="$WORK/stubs:/usr/bin:/bin" bash "$WORK/ui.sh" >/dev/null 2>&1
assert_contains "-ldflags -X main.version=7.7.7" "$(cat "$H/go.calls" 2>/dev/null)" "go build sets main.version"

test_start "dot_ai_tui_build_is_off_with_DOTFILES_AI_0"
tui off0 DOTFILES_AI=0
assert_contains "opt-in" "$OUT" "DOTFILES_AI=0 skips the build"
assert_file_not_exists "$H/go.calls" "go is not run"

test_start "dot_ai_tui_build_is_off_when_unset"
tui unset
assert_file_not_exists "$H/go.calls" "go is not run"

test_start "dot_ai_tui_builds_with_DOTFILES_AI_1"
tui on DOTFILES_AI=1
assert_file_exists "$H/.local/bin/dot-ai-tui" "the cockpit is built"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
