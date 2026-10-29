#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091
# Alias layers as deployed: names that collide, call nothing, or shadow.
#
# Renders the eager (90) and lazy (91) alias layers with chezmoi and
# sources them, in that order, in zsh and bash with a sandboxed HOME and
# stubs on PATH for every tool the alias files test for. Then reads back
# the aliases a user gets. Collisions resolve as the alias README records;
# aliases that call a missing subcommand or shadow a real binary with
# different syntax are gone.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

echo "Testing alias layer collisions..."

if ! command -v zsh >/dev/null 2>&1 || ! command -v chezmoi >/dev/null 2>&1; then
  echo "SKIP: zsh and chezmoi are both required"
  echo "RESULTS:0:0:0"
  exit 0
fi

SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT
CHEZMOI_BIN="$(command -v chezmoi)"
: >"$SANDBOX/chezmoi.toml"
mkdir -p "$SANDBOX/render-home" "$SANDBOX/home" "$SANDBOX/bin"

test_start "alias_layers_render"
rc=0
for layer in 90-ux-aliases 91-ux-aliases-lazy; do
  env -i HOME="$SANDBOX/render-home" PATH="$PATH" \
    "$CHEZMOI_BIN" --config "$SANDBOX/chezmoi.toml" --source "$REPO_ROOT/defaults" \
    --persistent-state "$SANDBOX/state.boltdb" execute-template \
    <"$REPO_ROOT/defaults/dot_config/shell/$layer.sh.tmpl" >"$SANDBOX/$layer.sh" || rc=$?
done
assert_equals "0" "$rc" "the alias layers render"

for tool in dot docker dig npm go fd gcloud gdate agy; do
  printf '#!/bin/sh\nexit 0\n' >"$SANDBOX/bin/$tool"
  chmod +x "$SANDBOX/bin/$tool"
done

# Prints "name=value" (or "name=none") for each alias asked about, then
# "self:" and every alias that maps a name to itself.
cat >"$SANDBOX/probe.sh" <<'EOF'
. "$SANDBOX/90-ux-aliases.sh"
. "$SANDBOX/91-ux-aliases-lazy.sh"
_av() {
  if [ -n "${ZSH_VERSION:-}" ]; then
    printf '%s=%s\n' "$1" "${aliases[$1]:-none}"
  else
    printf '%s=%s\n' "$1" "${BASH_ALIASES[$1]:-none}"
  fi
}
for _a in $(echo "$ASK"); do _av "$_a"; done
if [ -n "${ZSH_VERSION:-}" ]; then
  _names="${(k)aliases}"
else
  _names="${!BASH_ALIASES[*]}"
fi
_self=""
for _a in $(echo "$_names"); do
  [ "$(_av "$_a")" = "$_a=$_a" ] && _self="$_self $_a"
done
echo "self:${_self# }"
EOF

ASK="d dcl dki gci gcpd gcccc gcccl hom npb npd npg npsv gocv gofmt find gcn"
probe() {
  local shell="$1"
  shift
  # Only the stubs and the base system on PATH, so host tools do not count.
  timeout 60 env -i HOME="$SANDBOX/home" PATH="$SANDBOX/bin:/usr/bin:/bin" TERM=dumb \
    SANDBOX="$SANDBOX" ASK="$ASK" ${BASH_ENV:+BASH_ENV="$BASH_ENV"} ${PS4:+PS4="$PS4"} \
    "$(command -v "$shell")" "$@" -c ". \"\$SANDBOX/probe.sh\"" 2>/dev/null
}

ZSH_OUT="$(probe zsh -f)"
BASH_OUT="$(probe bash --norc --noprofile)"

for shell in zsh bash; do
  if [[ "$shell" == zsh ]]; then out="$ZSH_OUT"; else out="$BASH_OUT"; fi

  # Collisions, resolved for the more common use (see aliases/README.md).
  test_start "${shell}_d_is_dot"
  assert_contains $'\nd=dot\n' $'\n'"$out" "$shell: d is dot, even with docker and dig installed"
  test_start "${shell}_dcl_dki_are_docker"
  assert_contains $'dcl=docker compose logs\ndki=docker info\n' "$out" "$shell: dcl and dki are the docker aliases"
  test_start "${shell}_gcloud_duplicates"
  assert_contains $'gci=gcloud compute instances\ngcpd=gcloud projects describe\ngcccc=gcloud container clusters create\ngcccl=gcloud container clusters list\n' \
    "$out" "$shell: each gcloud alias has one definition; gcpd describes, never deletes"

  test_start "${shell}_hom_without_downloads"
  assert_contains "hom=cd_with_history \"\${HOME_DIR}\"" "$out" "$shell: hom exists without a ~/Downloads directory"

  # Aliases for subcommands that do not exist, or that shadow a binary.
  test_start "${shell}_broken_aliases_removed"
  assert_contains $'npb=none\nnpd=none\nnpg=none\nnpsv=none\ngocv=none\ngofmt=none\nfind=none\ngcn=none\n' \
    "$out" "$shell: npb npd npg npsv gocv gofmt find gcn are not defined"

  test_start "${shell}_no_self_aliases"
  assert_contains $'self:\n' "$out"$'\n' "$shell: no alias maps a name to itself"
done

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
