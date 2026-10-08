#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2016,SC2034
# `dot registry install` must never execute module content.
#
# A module is third-party data. Its archive used to be previewed with
# `chezmoi apply --dry-run` (templates render during a dry run, so
# `{{ output "sh" ... }}` ran at preview time) and applied with the user's
# own chezmoi config and state (so run_, remove_, exact_ and .chezmoiremove
# acted on all of $HOME). Pinned here:
#   - an archive holding any chezmoi-active name (*.tmpl, .chezmoi*, run_*,
#     exact_*, remove_*, create_*, modify_*, symlink_*, encrypted_*, at any
#     depth) is refused before chezmoi is called, naming the entry;
#   - the preview is a plain listing plus `diff -u` against existing files,
#     with no chezmoi call;
#   - --yes applies with an empty config and a throwaway state, and records
#     every target path in installed.json;
#   - with a real chezmoi, a hook in the user's chezmoi config does not run
#     and a template probe never fires.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

REGISTRY_SCRIPT="$REPO_ROOT/scripts/dot/commands/registry.sh"
# Resolved before the sandbox shadows chezmoi with a stub.
REAL_CHEZMOI="$(command -v chezmoi 2>/dev/null || true)"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox
BIN="$DOTFILES_COV_TMPDIR/bin"
WORK="$DOTFILES_COV_TMPDIR/work"
CALLS="$DOTFILES_COV_TMPDIR/chezmoi.calls"
mkdir -p "$WORK"

if ! command -v jq >/dev/null 2>&1; then
  test_start "jq_available"
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: jq is required by dot registry"
  echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
  exit 1
fi

# curl shim: file:// by copy, everything else fails. Offline throughout.
cat >"$BIN/curl" <<'SHIM'
#!/usr/bin/env bash
out=""; url=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -o) out="${2:-}"; shift 2 ;;
    file://*) url="$1"; shift ;;
    *) shift ;;
  esac
done
[[ -n "$url" ]] || exit 1
src="${url#file://}"
[[ -f "$src" ]] || exit 22
if [[ -n "$out" ]]; then cp "$src" "$out"; else cat "$src"; fi
SHIM
cat >"$BIN/chezmoi" <<'SHIM'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"${DOTFILES_COV_TMPDIR:?}/chezmoi.calls"
exit 0
SHIM
chmod +x "$BIN/curl" "$BIN/chezmoi"

sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

# module_index <name> <src-dir> — tar <src-dir> as <name>/, write an
# unsigned file:// index for it, and point the registry at it.
module_index() {
  local name="$1" src="$2" archive index
  archive="$WORK/$name-1.0.0.tar.gz"
  index="$WORK/$name-index.json"
  rm -rf "$WORK/stage"
  mkdir -p "$WORK/stage"
  cp -R "$src" "$WORK/stage/$name"
  tar -czf "$archive" -C "$WORK/stage" "$name"
  jq -n --arg name "$name" --arg url "file://$archive" --arg sha "$(sha256_of "$archive")" '{
    version: 1,
    modules: [{name: $name, version: "1.0.0", description: "fixture",
      archive_url: $url, sha256: $sha}]
  }' >"$index"
  export DOTFILES_REGISTRY_URL="file://$index"
}

# Local file:// fixtures are unsigned on purpose.
export DOTFILES_REGISTRY_UNSIGNED=1

source "$REGISTRY_SCRIPT"
set +e

OUT="$WORK/out.txt"
ERR="$WORK/err.txt"
run() {
  local rc=0
  cmd_registry "$@" </dev/null >"$OUT" 2>"$ERR" || rc=$?
  cat "$ERR" >&2
  printf '%s' "$rc"
}

MARK="$WORK/MARK"

# refused_case <label> <relative path inside the module> [content] [named]
# <named> is the component the refusal must name (default: the base name).
refused_case() {
  local label="$1" rel="$2" content="${3:-x}" src="$WORK/src-$1" rc
  local named="${4:-$(basename "$2")}" mod="mod-${1//_/-}"
  rm -rf "$src" "$CALLS" "$MARK" "$(_registry_cache_dir)"
  mkdir -p "$src/$(dirname "$rel")"
  printf 'export SAFE=1\n' >"$src/dot_safe"
  printf '%s\n' "$content" >"$src/$rel"
  module_index "$mod" "$src"

  test_start "${label}_preview_is_refused"
  rc="$(run install "$mod")"
  assert_equals "1" "$rc" "a module carrying $rel is refused"

  test_start "${label}_refusal_names_the_entry"
  assert_file_contains "$OUT" "($named)" "the error names the offending component"

  test_start "${label}_chezmoi_never_called"
  assert_file_not_exists "$CALLS" "refused before any chezmoi call"

  test_start "${label}_apply_is_refused_too"
  rc="$(run install "$mod" --yes)"
  assert_equals "1" "$rc" "--yes does not bypass the refusal"
  assert_file_not_exists "$CALLS" "still no chezmoi call"
  assert_file_not_exists "$MARK" "no probe marker was created"
}

refused_case "template" "dot_probe.tmpl" "{{ output \"sh\" \"-c\" \"touch $MARK\" }}"
refused_case "run_script" "run_once_x.sh" "#!/bin/sh
touch $MARK"
refused_case "chezmoiremove" ".chezmoiremove" ".bashrc"
refused_case "nested_exact" "dir/exact_sub/file" "x" "exact_sub"
refused_case "chezmoiscripts" ".chezmoiscripts/run_x.sh" "x" ".chezmoiscripts"
refused_case "remove" "remove_dot_bashrc" ""
refused_case "create" "create_dot_x" "x"
refused_case "modify" "modify_dot_x" "x"
refused_case "symlink" "symlink_dot_x" "/etc/passwd"
refused_case "encrypted" "encrypted_dot_x.age" "x"
refused_case "external_dir" "external_dot_x/file" "x" "external_dot_x"
refused_case "nested_template" "dot_config/app/config.toml.tmpl" "x"

# ===========================================================================
# A plain-file module still previews and installs.
# ===========================================================================
PLAIN="$WORK/src-plain"
rm -rf "$PLAIN" "$CALLS" "$(_registry_cache_dir)"
mkdir -p "$PLAIN/dot_config/app"
printf 'export PLAIN=new\n' >"$PLAIN/dot_profile"
printf 'color = "blue"\n' >"$PLAIN/dot_config/app/private_config.toml"
printf 'run\n' >"$PLAIN/literal_run_me"
printf 'export PLAIN=old\n' >"$HOME/.profile"
module_index "plain" "$PLAIN"

test_start "plain_module_preview_succeeds"
rc="$(run install plain)"
assert_equals "0" "$rc" "a plain-file module previews"

test_start "plain_module_preview_lists_the_files"
assert_file_contains "$OUT" "plain/dot_profile" "the archive listing names dot_profile"
assert_file_contains "$OUT" "plain/dot_config/app/private_config.toml" "nested files are listed"

test_start "plain_module_preview_diffs_existing_files"
assert_file_contains "$OUT" "-export PLAIN=old" "the current line is shown as removed"
assert_file_contains "$OUT" "+export PLAIN=new" "the module line is shown as added"
assert_file_contains "$OUT" "new: ~/.config/app/config.toml" "a file that does not exist yet is announced"
assert_file_contains "$OUT" "new: ~/run_me" "literal_ is stripped and stops prefix parsing"

test_start "plain_module_preview_does_not_call_chezmoi"
assert_file_not_exists "$CALLS" "the preview is chezmoi-free"

test_start "plain_module_preview_writes_nothing"
assert_file_contains "$HOME/.profile" "PLAIN=old" "the preview left \$HOME alone"
assert_dir_not_exists "$(_registry_data_dir)/plain" "nothing was persisted"

test_start "plain_module_apply_succeeds"
rc="$(run install plain --yes)"
assert_equals "0" "$rc" "--yes installs a plain module"

test_start "apply_uses_an_empty_config_and_throwaway_state"
assert_file_exists "$CALLS" "chezmoi was called to apply"
call="$(cat "$CALLS" 2>/dev/null)"
assert_contains "--config /dev/null --config-format toml" "$call" "the user's chezmoi config is not read"
assert_contains "--persistent-state " "$call" "a private persistent state is used"
assert_contains "--cache " "$call" "a private cache is used"
assert_contains "--exclude scripts,externals,encrypted,templates,symlinks,remove" "$call" "active entry types are excluded"
assert_contains "--source $(_registry_data_dir)/plain/1.0.0" "$call" "the persisted module is the source"
assert_contains "--destination $HOME" "$call" "the destination is \$HOME"
assert_not_contains_state=0
case "$call" in
  *"$XDG_CONFIG_HOME/chezmoi"* | *"$XDG_DATA_HOME/chezmoi"*) assert_not_contains_state=1 ;;
esac
assert_equals "0" "$assert_not_contains_state" "no path of the user's chezmoi state is passed"

test_start "apply_state_is_not_left_behind"
state_arg="$(sed -n 's/.*--persistent-state \([^ ]*\).*/\1/p' "$CALLS" | head -n 1)"
assert_not_empty "$state_arg" "the state path was passed"
assert_file_not_exists "$state_arg" "the throwaway state is removed afterwards"

test_start "installed_json_records_every_target_path"
installed="$(_registry_data_dir)/plain/installed.json"
assert_file_exists "$installed" "installed.json was written"
files="$(jq -r '.files | sort | join(",")' "$installed" 2>/dev/null)"
assert_equals "$HOME/.config/app/config.toml,$HOME/.profile,$HOME/run_me" "$files" \
  "every target path is recorded, in target form"
assert_equals "plain" "$(jq -r '.name' "$installed" 2>/dev/null)" "the module metadata is kept"

# ===========================================================================
# Target-name translation, unit level.
# ===========================================================================
test_start "target_name_translation"
assert_equals ".ssh/config" "$(_registry_target_path "private_dot_ssh/private_config")" "private_ and dot_ are translated"
assert_equals "bin/tool" "$(_registry_target_path "bin/executable_tool")" "executable_ is stripped"
assert_equals ".x" "$(_registry_target_path "readonly_empty_dot_x")" "stacked attributes are stripped"
assert_equals "dot_x" "$(_registry_target_path "literal_dot_x")" "literal_ keeps the rest verbatim"
assert_equals "notes" "$(_registry_target_path "notes.literal")" "a .literal suffix is stripped"
assert_equals "./.y" "$(_registry_target_path "./dot_y")" "a ./ component passes through"

test_start "forbidden_component_unit"
assert_equals "exact_sub" "$(_registry_forbidden_component "a/exact_sub/b")" "the offending component is named"
_registry_forbidden_component "dot_config/app/private_config.toml" >/dev/null
assert_equals "1" "$?" "a plain path is allowed"
_registry_forbidden_component "dot_config/tmpl/notes" >/dev/null
assert_equals "1" "$?" "tmpl as a whole name is plain"

# ===========================================================================
# Real chezmoi: the user's config hook must not run, and the module applies.
# ===========================================================================
if [[ -n "$REAL_CHEZMOI" ]]; then
  HOOK_MARK="$WORK/HOOK_MARK"
  mkdir -p "$XDG_CONFIG_HOME/chezmoi"
  printf '[hooks.apply.pre]\ncommand = "touch"\nargs = ["%s"]\n' "$HOOK_MARK" \
    >"$XDG_CONFIG_HOME/chezmoi/chezmoi.toml"
  rm -f "$BIN/chezmoi"
  ln -s "$REAL_CHEZMOI" "$BIN/chezmoi"
  rm -rf "$(_registry_data_dir)" "$(_registry_cache_dir)"
  printf 'export PLAIN=old\n' >"$HOME/.profile"
  module_index "plain" "$PLAIN"

  test_start "real_chezmoi_apply_installs_the_files"
  rc="$(run install plain --yes)"
  assert_equals "0" "$rc" "the real chezmoi apply succeeds"
  assert_file_contains "$HOME/.profile" "PLAIN=new" "the module file was applied"
  assert_file_contains "$HOME/.config/app/config.toml" 'color = "blue"' "nested files were applied"

  test_start "real_chezmoi_ignores_the_users_config_hooks"
  assert_file_not_exists "$HOOK_MARK" "the user's chezmoi hook did not run"
else
  printf '  - skipped real-chezmoi cases: chezmoi not installed\n'
fi

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
[[ "$TESTS_FAILED" -eq 0 ]]
