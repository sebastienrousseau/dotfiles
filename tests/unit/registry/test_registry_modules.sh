#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1091
# The registry modules (plan P1.6): tools/registry/build_modules.py builds
# registry/modules into reproducible archives and the index entries that
# pin them; docs/registry.json must be what it writes; and a signed index
# installs each module through dot cli install, as a user would.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
BUILD="$REPO_ROOT/tools/registry/build_modules.py"

if ! command -v python3 >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
  echo "SKIP: python3 and jq are needed"
  echo "RESULTS:0:0:0"
  exit 0
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/dot-registry-modules.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
COV_ENV=()
for v in BASH_ENV PS4 COV_TRACE_FILE COV_ROOT; do
  [[ -z "${!v:-}" ]] || COV_ENV+=("$v=${!v}")
done

# root DIR: a repository root at DIR with the modules, the index and the
# committed archives.
root() {
  mkdir -p "$1/docs/registry" "$1/registry"
  cp -R "$REPO_ROOT/registry/modules" "$1/registry/"
  cp -R "$REPO_ROOT/docs/registry/modules" "$1/docs/registry/"
  cp "$REPO_ROOT/docs/registry.json" "$1/docs/"
}

# build ROOT: RC and OUT of a build of ROOT.
build() {
  RC=0
  OUT="$(python3 "$BUILD" --root "$1" --updated 2026-11-11T00:00:00Z 2>&1)" || RC=$?
}

test_start "the_committed_index_is_what_the_build_writes"
RC=0
OUT="$(python3 "$BUILD" --check 2>&1)" || RC=$?
assert_equals "0" "$RC" "--check passes"
assert_contains "the index and archives match the build" "$OUT" "says so"

test_start "builds_are_reproducible"
root "$WORK/a"
root "$WORK/b"
rm -f "$WORK"/a/docs/registry/modules/* "$WORK"/b/docs/registry/modules/*
build "$WORK/a"
assert_equals "0" "$RC" "first build"
build "$WORK/b"
assert_true "cmp -s '$WORK/a/docs/registry.json' '$WORK/b/docs/registry.json'" "the same index"
for f in "$REPO_ROOT"/docs/registry/modules/*.tar.gz; do
  assert_true "cmp -s '$f' '$WORK/a/docs/registry/modules/${f##*/}'" "${f##*/}: the committed bytes"
  assert_true "cmp -s '$f' '$WORK/b/docs/registry/modules/${f##*/}'" "${f##*/}: the same bytes again"
done
assert_equals "2026-11-11T00:00:00Z" "$(jq -r .updated "$WORK/a/docs/registry.json")" "updated as given"

test_start "each_archive_is_one_directory_of_plain_files"
# registry.sh sets -e; a failed check here must not end the file.
source "$REPO_ROOT/plugins/cli/libexec/registry.sh"
set +e
for f in "$WORK"/a/docs/registry/modules/*.tar.gz; do
  top="$(basename "$f" .tar.gz)"
  assert_true "_registry_archive_is_safe '$f' >/dev/null" "$top: passes the installer's checks"
  assert_equals "$top/" "$(tar -tzf "$f" | head -n 1)" "$top: under $top/"
  assert_equals "$(jq -r --arg n "${top%-*}" '.modules[] | select(.name == $n) | .sha256' "$WORK/a/docs/registry.json")" \
    "$(_dot_sha256_file "$f")" "$top: the index pins its digest"
done
assert_true "_registry_validate_index '$WORK/a/docs/registry.json'" "the index meets the v1 contract"

test_start "a_changed_module_fails_the_check"
printf '\n' >>"$WORK/b/registry/modules/ai-policy-pack/files/dot_config/dotfiles/ai-policy.d/strict.toml"
RC=0
OUT="$(python3 "$BUILD" --root "$WORK/b" --check 2>&1)" || RC=$?
assert_equals "1" "$RC" "exit 1"
assert_contains "docs/registry.json, docs/registry/modules/ai-policy-pack-1.0.0.tar.gz not what the build writes" "$OUT" "names what differs"
assert_contains "re-sign the index" "$OUT" "says what to do"
root "$WORK/d"
printf 'x' >>"$WORK/d/docs/registry/modules/claude-statusline-1.0.0.tar.gz"
RC=0
OUT="$(python3 "$BUILD" --root "$WORK/d" --check 2>&1)" || RC=$?
assert_equals "1|registry modules: docs/registry/modules/claude-statusline-1.0.0.tar.gz not what the build writes; run tools/registry/build_modules.py and re-sign the index" \
  "$RC|$OUT" "a committed archive that is not the build's"
rm "$WORK/d/docs/registry/modules/claude-statusline-1.0.0.tar.gz"
RC=0
python3 "$BUILD" --root "$WORK/d" --check >/dev/null 2>&1 || RC=$?
assert_equals "1" "$RC" "a missing archive"

test_start "check_registry_fails_on_a_stale_index"
# tools/ci/check-registry.sh in a copy of the layout it reads, with no key
# and no signature (its signature check then skips).
mkdir -p "$WORK/e/tools/ci" "$WORK/e/docs/schema"
cp "$REPO_ROOT/tools/ci/check-registry.sh" "$WORK/e/tools/ci/"
ln -s "$REPO_ROOT/tools/registry" "$WORK/e/tools/registry"
ln -s "$REPO_ROOT/plugins" "$WORK/e/plugins"
ln -s "$REPO_ROOT/lib" "$WORK/e/lib"
cp "$REPO_ROOT/docs/schema/dot-registry-v1.json" "$WORK/e/docs/schema/"
root "$WORK/e"
RC=0
OUT="$(bash "$WORK/e/tools/ci/check-registry.sh" 2>&1)" || RC=$?
assert_equals "0" "$RC" "the layout as committed passes"
printf '\n' >>"$WORK/e/registry/modules/claude-statusline/files/dot_local/bin/executable_dot-claude-statusline"
RC=0
OUT="$(bash "$WORK/e/tools/ci/check-registry.sh" 2>&1)" || RC=$?
assert_equals "1" "$RC" "a module changed without a build: exit 1"
assert_contains "not what the build writes" "$OUT" "says why"

test_start "modules_that_cannot_be_published"
bad() {
  rm -rf "$WORK/c"
  root "$WORK/c"
  "$@"
  build "$WORK/c"
}
m="$WORK/c/registry/modules/claude-statusline"
bad eval "jq '.extra = 1' '$m/module.json' >'$WORK/j' && mv '$WORK/j' '$m/module.json'"
assert_equals "1|registry modules: claude-statusline: unknown key 'extra'" "$RC|$OUT" "an unknown key"
bad eval "jq '.name = \"other\"' '$m/module.json' >'$WORK/j' && mv '$WORK/j' '$m/module.json'"
assert_contains "name must be the directory's" "$OUT" "a name that is not the directory's"
bad eval "jq '.version = \"1.0\"' '$m/module.json' >'$WORK/j' && mv '$WORK/j' '$m/module.json'"
assert_contains "version is not semver" "$OUT" "a version that is not semver"
bad eval "jq '.description = \"\"' '$m/module.json' >'$WORK/j' && mv '$WORK/j' '$m/module.json'"
assert_contains "description must be 1-200 characters" "$OUT" "no description"
bad ln -s /etc/hosts "$m/files/dot_local/bin/hosts"
assert_contains "dot_local/bin/hosts is a link" "$OUT" "a link"
bad rm -rf "$m/files/dot_local"
assert_contains "files/ is empty" "$OUT" "no files"

test_start "a_signed_index_installs_each_module"
if ! command -v minisign >/dev/null 2>&1 || ! command -v chezmoi >/dev/null 2>&1; then
  echo "  minisign or chezmoi unavailable: end-to-end skipped"
else
  idx="$WORK/a/docs/registry.json"
  jq --arg d "file://$WORK/a/docs/registry/modules" '.modules[].archive_url |= ($d + "/" + (split("/") | last))' "$idx" >"$WORK/index.json"
  minisign -G -W -p "$WORK/key.pub" -s "$WORK/key.sec" >/dev/null 2>&1 </dev/null
  minisign -S -s "$WORK/key.sec" -m "$WORK/index.json" -t "test index" >/dev/null 2>&1 </dev/null
  H="$WORK/home"
  mkdir -p "$H"
  for name in claude-statusline ai-policy-pack; do
    RC=0
    OUT="$(env -i ${COV_ENV[@]+"${COV_ENV[@]}"} HOME="$H" PATH="$PATH" NO_COLOR=1 TERM=dumb \
      DOTFILES_REGISTRY_URL="file://$WORK/index.json" DOTFILES_REGISTRY_PUBKEY="$WORK/key.pub" \
      bash "$REPO_ROOT/bin/dot" cli install "$name" --yes 2>&1 </dev/null)" || RC=$?
    assert_equals "0" "$RC" "$name: installed"
  done
  assert_true "[[ -x '$H/.local/bin/dot-claude-statusline' ]]" "the status line is in ~/.local/bin, executable"
  assert_equals "Opus · ask" "$(printf '{"model":{"display_name":"Opus"}}' | HOME="$H" DOT_AI_POLICY="$H/.config/dotfiles/ai-policy.d/standard.toml" NO_COLOR=1 "$H/.local/bin/dot-claude-statusline")" \
    "it runs, and reads the installed preset"
  assert_equals "regulated.toml standard.toml strict.toml" "$(cd "$H/.config/dotfiles/ai-policy.d" && echo *)" "the presets, beside ai-policy.toml"
  assert_true "[[ ! -e '$H/.config/dotfiles/ai-policy.toml' ]]" "no preset is enforced until the user copies one"
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
[[ "$TESTS_FAILED" -eq 0 ]]
