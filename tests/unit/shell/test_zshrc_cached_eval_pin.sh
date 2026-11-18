#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2016
# A tool reached both through a mise shim and through its install directory
# must not rewrite its _cached_eval cache in every shell.
#
# A new shell sets up starship eagerly, through mise's shim (a link to mise
# itself), then activates mise, which puts starship's install directory
# first. The cache was pinned to the binary's realpath: mise for the shim,
# the installed starship after activation. They never matched, so every
# shell regenerated the starship cache twice. A mise version change must
# still regenerate it once.
#
# Renders dot_zshrc.tmpl and runs it in `zsh -f -i` with a sandboxed HOME, a
# stub mise (shim dispatch, `which`, `activate`) and a stub starship that
# logs every init it runs.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

if ! command -v zsh >/dev/null 2>&1 || ! command -v chezmoi >/dev/null 2>&1; then
  echo "SKIP: zsh and chezmoi are both required"
  echo "RESULTS:0:0:0"
  exit 0
fi

SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT
ZSH_BIN="$(command -v zsh)"
H="$SANDBOX/home"
S="$SANDBOX/mise"
LOG="$SANDBOX/starship.log"
mkdir -p "$H/.config/mise" "$SANDBOX/render-home" "$S/bin" "$S/shims"
: >"$SANDBOX/chezmoi.toml"
: >"$LOG"

env -i HOME="$SANDBOX/render-home" PATH="$PATH" \
  chezmoi --config "$SANDBOX/chezmoi.toml" --source "$REPO_ROOT/defaults" \
  --persistent-state "$SANDBOX/state.boltdb" execute-template \
  <"$REPO_ROOT/defaults/dot_config/zsh/dot_zshrc.tmpl" >"$H/.zshrc"

# The stub mise: as a shim it runs the current version of the tool it is
# named after; `which` names that binary; `activate` puts its directory first.
cat >"$S/bin/mise" <<EOF
#!/bin/sh
ver=\$(/bin/cat "$S/current")
name=\${0##*/}
if [ "\$name" != mise ]; then exec "$S/installs/\$name/\$ver/\$name" "\$@"; fi
case "\$1" in
  which) echo "$S/installs/\$2/\$ver/\$2" ;;
  activate) printf "export PATH='%s:%s'\n" "$S/installs/starship/\$ver" "\$PATH" ;;
esac
EOF
chmod +x "$S/bin/mise"
ln -s ../bin/mise "$S/shims/starship"

# install <version>: a stub starship <version> that logs each init.
install() {
  mkdir -p "$S/installs/starship/$1"
  cat >"$S/installs/starship/$1/starship" <<EOF
#!/bin/sh
echo "init $1" >>"$LOG"
echo "typeset -g STUB_STARSHIP=$1"
EOF
  chmod +x "$S/installs/starship/$1/starship"
  echo "$1" >"$S/current"
}

# shell: a new interactive shell, starship through the shim, then hydration;
# prints the starship version the prompt ended up with.
shell() {
  env -i HOME="$H" PATH="$S/shims:$S/bin:/usr/bin:/bin" TERM=dumb \
    "$ZSH_BIN" -f -i -c 'source "$HOME/.zshrc"; _dotfiles_async_init; print -r -- "$STUB_STARSHIP"' 2>/dev/null |
    tail -n 1
}

inits() { grep -c '^init' "$LOG"; }
CACHE="$H/.cache/zsh/starship-init.zsh"

install 1.0

test_start "starship_cache_written_once"
assert_equals "1.0" "$(shell)" "the first shell sets up starship 1.0"
assert_equals "1" "$(inits)" "the first shell runs starship init once"

test_start "starship_cache_stable_across_shells"
before="$(ls -i "$CACHE" 2>/dev/null)"
for _ in 1 2 3 4 5; do shell >/dev/null; done
assert_equals "1" "$(inits)" "five more shells run no starship init"
assert_equals "$before" "$(ls -i "$CACHE" 2>/dev/null)" "the cache file is not rewritten"

# A version change through mise: the shim no longer tells, but mise's
# activation resolves the new binary, which differs from the pin.
test_start "starship_cache_follows_a_version_change"
install 1.1
: >"$H/.config/mise/config.toml"
assert_equals "1.1" "$(shell)" "the shell after a version change ends up on 1.1"
assert_equals "2" "$(inits)" "it runs starship init once more"
shell >/dev/null
assert_equals "2" "$(inits)" "later shells use the new cache"

test_start "starship_cache_drops_a_removed_binary"
rm -rf "$S/installs/starship/1.1"
install 1.2
env -i HOME="$H" PATH="$S/shims:$S/bin:/usr/bin:/bin" TERM=dumb \
  "$ZSH_BIN" -f -i -c 'source "$HOME/.zshrc"; print -r -- "$STUB_STARSHIP"' >"$SANDBOX/out" 2>/dev/null
assert_equals "1.2" "$(tail -n 1 "$SANDBOX/out")" "the shim alone regenerates when the pinned binary is gone"

print_summary
