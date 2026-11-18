#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2016
# Theme templates parse only the themes they use, not the whole manifest.
#
# Some 30 templates each ran `include ".theme-manifest/themes.toml" |
# fromToml`, parsing the ~460 KB manifest about 50 ms of CPU apiece on every
# `chezmoi status`, `diff` and `apply`. They now go through the
# `theme-subset` partial, which hands `fromToml` the active theme and
# fallback-dark only.
#
# Checked with the real chezmoi on a copy of the source: a manifest with a
# broken, unrelated theme appended still renders every theme template (the
# broken table is never parsed), and each renders exactly what it renders
# with the pristine manifest.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

if ! command -v chezmoi >/dev/null 2>&1; then
  echo "SKIP: chezmoi not installed"
  echo "RESULTS:0:0:0"
  exit 0
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/dot-theme-subset.XXXXXX")"
trap '[ -n "${KEEP:-}" ] || rm -rf "$WORK"' EXIT
SRC="$WORK/src"
cp -R "$REPO_ROOT/defaults" "$SRC"
mkdir -p "$WORK/home"
: >"$WORK/chezmoi.toml"
MANIFEST="$SRC/.theme-manifest/themes.toml"
cp "$MANIFEST" "$WORK/pristine.toml"

# Every template that reads the manifest.
TEMPLATES=()
while IFS= read -r f; do
  case "$f" in */.chezmoitemplates/theme-name | */.chezmoitemplates/theme-subset) continue ;; esac
  TEMPLATES+=("$f")
done < <(grep -rlE 'theme-manifest/themes\.toml|"theme-subset"' "$SRC" --include='*.tmpl' | sort)

# render_all <theme> <outfile>: render every theme template for <theme>;
# print how many failed.
render_all() {
  local f failed=0
  : >"$2"
  for f in "${TEMPLATES[@]}"; do
    printf '==== %s\n' "${f#"$SRC"/}" >>"$2"
    env -i HOME="$WORK/home" PATH="$PATH" chezmoi --config "$WORK/chezmoi.toml" --source "$SRC" \
      --destination "$WORK/home" --persistent-state "$WORK/state.boltdb" \
      --override-data "{\"theme\":\"$1\"}" execute-template <"$f" >>"$2" 2>&1 ||
      failed=$((failed + 1))
  done
  echo "$failed"
}

test_start "theme_templates_found"
assert_true "[ ${#TEMPLATES[@]} -ge 25 ]" "found ${#TEMPLATES[@]} theme templates"

# An unknown theme falling back to fallback-dark is covered, through the
# deployed kitty template, by test_theme_manifest_location.sh.
for theme in maui-dark fallback-dark; do
  cp "$WORK/pristine.toml" "$MANIFEST"
  render_all "$theme" "$WORK/pristine.$theme" >/dev/null
  printf '\n[themes.zz-broken]\nmode = \n' >>"$MANIFEST"
  failed="$(render_all "$theme" "$WORK/broken.$theme")"

  test_start "theme_templates_skip_unrelated_themes_$theme"
  assert_equals "0" "$failed" "a broken table in an unused theme fails no template ($theme)"

  # The fish completion lists every theme name, so it gains zz-broken.
  test_start "theme_templates_render_unchanged_$theme"
  assert_true "diff -q <(grep -v '^complete -c dot-theme-sync -f -a' '$WORK/pristine.$theme') <(grep -v '^complete -c dot-theme-sync -f -a' '$WORK/broken.$theme')" \
    "every theme template renders the same as with the pristine manifest ($theme)"
done

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
