#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091
# Function layer vs alias layer: same functions in zsh and bash.
#
# Renders the extra-function layer (51) and the alias layers (90, 91) with
# chezmoi, then sources them in the order each shell's rc uses: zsh loads
# 90 at startup and 91, 51 later; bash loads 51 before 90 and 91. A name
# both layers define (`extract`, `backup`, `goto`) must resolve to the
# alias-file version in both shells, and loading every function group
# must not replace it.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

echo "Testing function layer precedence..."

if ! command -v zsh >/dev/null 2>&1 || ! command -v chezmoi >/dev/null 2>&1; then
  echo "SKIP: zsh and chezmoi are both required"
  echo "RESULTS:0:0:0"
  exit 0
fi

SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT
CHEZMOI_BIN="$(command -v chezmoi)"
: >"$SANDBOX/chezmoi.toml"
mkdir -p "$SANDBOX/render-home" "$SANDBOX/home" "$SANDBOX/work"

render() {
  env -i HOME="$SANDBOX/render-home" PATH="$PATH" \
    "$CHEZMOI_BIN" --config "$SANDBOX/chezmoi.toml" --source "$REPO_ROOT/defaults" \
    --persistent-state "$SANDBOX/state.boltdb" execute-template \
    <"$REPO_ROOT/defaults/dot_config/shell/$1.sh.tmpl" >"$SANDBOX/$1.sh"
}

test_start "layers_render"
rc=0
for layer in 51-logic-functions-extra 90-ux-aliases 91-ux-aliases-lazy; do
  render "$layer" || rc=$?
done
assert_equals "0" "$rc" "the function and alias layers render"

printf 'payload\n' >"$SANDBOX/work/payload.txt"
(cd "$SANDBOX/work" && tar czf sample.tgz payload.txt && rm payload.txt)

# The probe sources the layers in $LAYERS order, then reports.
cat >"$SANDBOX/probe.sh" <<'EOF'
for _l in $(echo "$LAYERS"); do . "$SANDBOX/$_l.sh"; done
_fns() {
  if [ -n "${ZSH_VERSION:-}" ]; then print -l ${(k)functions}; else compgen -A function; fi
}
# Snapshot every real (non-stub) function before any group loads.
mkdir -p "$SANDBOX/snap-$SHELL_NAME"
for _f in $(_fns); do
  _d="$(declare -f "$_f")"
  case "$_d" in *_dotfiles_load_group_*) ;; *) printf '%s\n' "$_d" >"$SANDBOX/snap-$SHELL_NAME/$_f" ;; esac
done
cd "$SANDBOX/work"
echo "extract:$( (extract sample.tgz >/dev/null 2>&1 && cat payload.txt) | head -c 200)"
echo "decode64:$(decode64 aGk= 2>/dev/null)"
for _g in api curl files interactive misc nav security system text; do
  "_dotfiles_load_group_$_g" >/dev/null 2>&1
done
_changed=""
for _f in "$SANDBOX/snap-$SHELL_NAME"/*; do
  [ "$(declare -f "${_f##*/}")" = "$(cat "$_f")" ] || _changed="$_changed ${_f##*/}"
done
echo "changed:${_changed# }"
declare -f goto | grep -q BOOKMARK_FILE && echo "goto:bookmarks"
declare -f backup | grep -q 'backup <file_or_directory> \[format\]' && echo "backup:archives"
EOF

probe() {
  local shell="$1" layers="$2"
  shift 2
  env -i HOME="$SANDBOX/home" PATH="$PATH" TERM=dumb SANDBOX="$SANDBOX" \
    ${BASH_ENV:+BASH_ENV="$BASH_ENV"} ${PS4:+PS4="$PS4"} \
    SHELL_NAME="$shell" LAYERS="$layers" timeout 60 "$shell" "$@" 2>/dev/null | head -c 4000
}

ZSH_OUT="$(probe zsh "90-ux-aliases 91-ux-aliases-lazy 51-logic-functions-extra" -f -c ". \"\$SANDBOX/probe.sh\"")"
BASH_OUT="$(probe bash "51-logic-functions-extra 90-ux-aliases 91-ux-aliases-lazy" --norc --noprofile -c ". \"\$SANDBOX/probe.sh\"")"

for shell in zsh bash; do
  if [[ "$shell" == zsh ]]; then out="$ZSH_OUT"; else out="$BASH_OUT"; fi

  test_start "${shell}_extract_unpacks"
  assert_contains "extract:payload" "$out" "$shell: extract (and so x) unpacks a .tgz instead of recursing"

  test_start "${shell}_decode64_lazy"
  assert_contains "decode64:hi" "$out" "$shell: decode64 works before its group has loaded"

  test_start "${shell}_group_loads_keep_alias_functions"
  assert_contains "changed:"$'\n' "$out" "$shell: loading every function group replaces no alias-layer function"

  test_start "${shell}_goto_is_bookmarks"
  assert_contains "goto:bookmarks" "$out" "$shell: goto is the cd bookmark function"

  test_start "${shell}_backup_is_archives"
  assert_contains "backup:archives" "$out" "$shell: backup is the archives function"
done

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
