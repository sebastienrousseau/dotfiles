#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# test-kind: structural
# shellcheck disable=SC1090,SC1091
# nix/flake.nix reads the chezmoi data through a path literal. It pointed at
# ../.chezmoidata.toml, which does not exist, and builtins.pathExists turned
# that into "no features", so every optional package was silently dropped.
# Nix is rarely installed where this suite runs, so the path literals are
# checked statically; with nix present the overlay is also evaluated.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

FLAKE_DIR="$REPO_ROOT/nix"
FLAKE="$FLAKE_DIR/flake.nix"

test_start "nix_flake_relative_paths_exist"
# Every relative path literal (./x or ../x) outside a comment, except
# ./home.nix, which the flake guards with pathExists on purpose.
paths="$(sed 's/#.*//' "$FLAKE" | grep -oE '(^|[[:space:]=(\[])\.\.?/[A-Za-z0-9._/-]+' |
  sed -E 's/^[[:space:]=(\[]//' | sort -u | grep -vx './home.nix')"
assert_contains "../defaults/.chezmoidata.toml" "$paths" "the overlay reads the chezmoi data file"
for p in $paths; do
  assert_true "[[ -e '$FLAKE_DIR/$p' ]]" "$p (relative to nix/) exists"
done

test_start "nix_flake_data_file_is_plain_toml"
# builtins.fromTOML reads it, so it must be TOML without template syntax.
if python3 -c 'import tomllib' 2>/dev/null; then
  assert_true "python3 -c 'import sys,tomllib; tomllib.load(open(sys.argv[1],\"rb\"))' '$REPO_ROOT/defaults/.chezmoidata.toml'" \
    "defaults/.chezmoidata.toml parses as TOML"
else
  echo "  skip: python3 tomllib unavailable"
fi

if command -v nix >/dev/null 2>&1; then
  test_start "nix_overlay_includes_optional_packages"
  names="$(cd "$FLAKE_DIR" && nix --extra-experimental-features 'nix-command flakes' eval --raw --impure --expr \
    'let f = builtins.getFlake (toString ./.); pkgs = import f.inputs.nixpkgs { overlays = [ f.overlays.chezmoi-features ]; }; in toString (map (p: p.pname or p.name) pkgs.dotfiles-conditional.paths)' 2>&1)"
  assert_contains "starship" "$names" "starship is in the conditional env"
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
