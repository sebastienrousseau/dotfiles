#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091
# The theme manifest stays out of chezmoi's data. chezmoi hands everything
# under .chezmoidata to each template it renders, so the 350 KB manifest
# there made `chezmoi apply --dry-run` take about 1.9 s instead of under 1 s
# and failed the weekly 2 s budget. Templates load it with
# `include ".theme-manifest/themes.toml" | fromToml` instead. Checked with the
# real chezmoi against a throwaway destination: the data has no themes, a
# theme template still renders the manifest's palette, and .chezmoidata
# stays small.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

if ! command -v chezmoi >/dev/null 2>&1; then
  echo "SKIP: chezmoi not installed"
  echo "RESULTS:0:0:0"
  exit 0
fi

SRC="$REPO_ROOT/defaults"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/dot-theme-manifest.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/home"

# cz <args...> — chezmoi on the repo source, a throwaway destination and state.
cz() {
  chezmoi --source "$SRC" --destination "$WORK/home" \
    --persistent-state "$WORK/state.boltdb" --cache "$WORK/cache" "$@"
}

test_start "chezmoi_data_carries_no_theme_manifest"
cz data --format json >"$WORK/data.json" 2>/dev/null
assert_equals "false" "$(python3 -c 'import json,sys; print(str("themes" in json.load(open(sys.argv[1]))).lower())' "$WORK/data.json")" \
  "the manifest is not part of every template's data"

# bg <theme> — term.bg of <theme>, read straight from the manifest.
bg() {
  python3 -c 'import sys, tomllib; print(tomllib.load(open(sys.argv[1], "rb"))["themes"][sys.argv[2]]["term"]["bg"])' \
    "$SRC/.theme-manifest/themes.toml" "$1"
}

test_start "theme_template_renders_the_manifest_palette"
cz --override-data '{"theme":"maui-dark"}' cat "$WORK/home/.config/kitty/kitty.conf" >"$WORK/kitty.conf" 2>/dev/null
assert_file_contains "$WORK/kitty.conf" "background $(bg maui-dark)" "kitty background is maui-dark's term.bg"

test_start "unknown_theme_still_falls_back"
cz --override-data '{"theme":"no-such-theme"}' cat "$WORK/home/.config/kitty/kitty.conf" >"$WORK/fallback.conf" 2>&1
assert_file_contains "$WORK/fallback.conf" "background $(bg fallback-dark)" "theme-name resolves fallback-dark"

test_start "chezmoidata_stays_within_its_size_budget"
data_bytes=0
for f in "$SRC"/.chezmoidata/*; do
  data_bytes=$((data_bytes + $(wc -c <"$f")))
done
assert_true "[ $data_bytes -le 65536 ]" \
  ".chezmoidata is ${data_bytes} bytes; over 64 KiB slows every template render"

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
