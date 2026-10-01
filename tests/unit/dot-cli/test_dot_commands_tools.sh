#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for dot CLI tools commands
# Tests: packages, tools, tools install, new, sandbox

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/mocks.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

TOOLS_FILE="$REPO_ROOT/scripts/dot/commands/tools.sh"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

# Test: tools.sh file exists
test_start "tools_cmd_file_exists"
assert_file_exists "$TOOLS_FILE" "tools.sh should exist"

# Test: tools.sh is valid shell syntax
test_start "tools_cmd_syntax_valid"
if bash -n "$TOOLS_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: tools.sh has valid syntax"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: tools.sh has syntax errors"
fi

# Test: defines packages command
test_start "tools_cmd_defines_packages"
if grep -q "cmd_packages\|_packages\|packages" "$TOOLS_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: defines packages command"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should define packages command"
fi

# Test: defines tools command
test_start "tools_cmd_defines_tools"
if grep -q "cmd_tools\|_tools" "$TOOLS_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: defines tools command"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should define tools command"
fi

# Test: defines new command (project scaffolding)
test_start "tools_cmd_defines_new"
if grep -q "cmd_new\|_new\|dot_new" "$TOOLS_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: defines new command"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should define new command"
fi

# Test: defines sandbox command
test_start "tools_cmd_defines_sandbox"
if grep -q "sandbox" "$REPO_ROOT/scripts/dot/commands/meta.sh" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: sandbox command is defined in meta module"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: sandbox command should exist in meta module"
fi

# Test: no hardcoded paths
test_start "tools_cmd_no_hardcoded_paths"
if grep -qE '"/home/[a-z]+' "$TOOLS_FILE" 2>/dev/null; then
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should not have hardcoded paths"
else
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: no hardcoded paths"
fi

# Test: uses XDG directories
test_start "tools_cmd_uses_xdg"
if grep -qE 'PWD|HOME|resolve_source_dir|require_source_dir' "$TOOLS_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: uses XDG/HOME variables"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should use XDG directories"
fi

# Test: shellcheck compliance
echo ""
echo "Tools commands tests completed."

test_start "tools_cmd_deep_branches_execute"
tools_tmp="$DOTFILES_COV_TMPDIR/tools-deep"
mkdir -p "$tools_tmp/bin" "$tools_tmp/repo/templates/projects/python/__PROJECT_NAME__" \
  "$tools_tmp/repo/defaults" "$tools_tmp/work"
cat >"$tools_tmp/repo/defaults/.chezmoidata.toml" <<'EOF'
profile = "default"

[features]
ai = true
desktop = false
fleet = true
EOF
printf 'defaults\n' >"$tools_tmp/repo/.chezmoiroot"
cat >"$tools_tmp/repo/templates/projects/python/pyproject.toml" <<'EOF'
[project]
name = "__PROJECT_NAME__"
version = "0.1.0"
EOF
cat >"$tools_tmp/repo/templates/projects/python/__PROJECT_NAME__/__init__.py" <<'EOF'
"""__PROJECT_NAME__ package."""
EOF
cat >"$tools_tmp/bin/brew" <<'SHIM'
#!/usr/bin/env bash
case "${1:-}" in
  --version) echo "Homebrew 9.9.9" ;;
  list) echo "pkg-one"; echo "pkg-two" ;;
esac
SHIM
cat >"$tools_tmp/bin/apt" <<'SHIM'
#!/usr/bin/env bash
echo "apt 9.9.9"
SHIM
cat >"$tools_tmp/bin/dpkg" <<'SHIM'
#!/usr/bin/env bash
echo "ii  one"; echo "ii  two"; echo "rc  old"
SHIM
cat >"$tools_tmp/bin/dnf" <<'SHIM'
#!/usr/bin/env bash
echo "9.9.9"
SHIM
cat >"$tools_tmp/bin/pacman" <<'SHIM'
#!/usr/bin/env bash
case "${1:-}" in
  -Q) echo "one"; echo "two" ;;
  --version) echo "Pacman v9.9.9" ;;
esac
SHIM
cat >"$tools_tmp/bin/nix" <<'SHIM'
#!/usr/bin/env bash
case "${1:-}" in
  --version) echo "nix 9.9.9" ;;
  develop) exit 0 ;;
esac
SHIM
cat >"$tools_tmp/bin/npm" <<'SHIM'
#!/usr/bin/env bash
case "${1:-}" in
  --version) echo "9.9.9" ;;
  list) echo "├── one"; echo "└── two" ;;
  install) exit 0 ;;
esac
SHIM
cat >"$tools_tmp/bin/pnpm" <<'SHIM'
#!/usr/bin/env bash
echo "9.9.9"
SHIM
cat >"$tools_tmp/bin/bun" <<'SHIM'
#!/usr/bin/env bash
echo "9.9.9"
SHIM
cat >"$tools_tmp/bin/cargo" <<'SHIM'
#!/usr/bin/env bash
case "${1:-}" in
  install) echo "tool-a:"; echo "tool-b:" ;;
  --version) echo "cargo 9.9.9" ;;
esac
SHIM
cat >"$tools_tmp/bin/pip3" <<'SHIM'
#!/usr/bin/env bash
echo "pip 9.9.9 from /tmp"
SHIM
cat >"$tools_tmp/bin/pipx" <<'SHIM'
#!/usr/bin/env bash
case "${1:-}" in
  list) echo "one"; echo "two" ;;
  --version) echo "9.9.9" ;;
esac
SHIM
cat >"$tools_tmp/bin/gem" <<'SHIM'
#!/usr/bin/env bash
echo "9.9.9"
SHIM
cat >"$tools_tmp/bin/go" <<'SHIM'
#!/usr/bin/env bash
case "${1:-}" in
  version) echo "go version go9.9.9 darwin/arm64" ;;
  mod) exit 0 ;;
esac
SHIM
cat >"$tools_tmp/bin/mise" <<'SHIM'
#!/usr/bin/env bash
case "${1:-}" in
  ls)
    if [[ "${2:-}" == "--json" ]]; then
      printf '{"node":[{"version":"24.0.0","source":{"path":"%s/.tool-versions"},"requested_version":"24"}]}\n' "${HOME:-/tmp}"
    else
      echo "node 24.0.0 ~/.tool-versions 24"
    fi
    ;;
  prune)
    if [[ "${2:-}" == "--dry-run-code" ]]; then exit 1; fi
    echo "prune ${*:2}"
    ;;
  install|use) echo "$1 ${*:2}" ;;
  *) echo "mise ${*}" ;;
esac
SHIM
chmod +x "$tools_tmp/bin/"*

(
  set +e
  export PATH="$tools_tmp/bin:$PATH"
  export HOME="$tools_tmp/home"
  mkdir -p "$HOME"
  cd "$tools_tmp/work" || exit 1
  set -- tools
  # shellcheck disable=SC1091
  source "$TOOLS_FILE"
  _DOT_SOURCE_DIR_CACHE="$tools_tmp/repo"
  cmd_packages
  cmd_tools
  cmd_env_mise list
  cmd_env_mise prune
  cmd_env_mise prune --yes
  cmd_env_mise install node
  cmd_env_mise use node
  cmd_env_mise unknown
  cmd_profile show
  cmd_profile set workstation
  cmd_new python demo_project
) >/dev/null || true
assert_dir_exists "$tools_tmp/work/demo_project" "tools deep branches created sandbox project"

(
  set +e
  export PATH="$tools_tmp/bin:$PATH"
  export HOME="$tools_tmp/home"
  cd "$tools_tmp/work" || exit 1
  bash "$TOOLS_FILE" tools install node >/dev/null
) || true

# ── tools docs ───────────────────────────────────────────────────────
# Regression: cmd_tools looked for <src>/docs/TOOLS.md and <src>/docs/UTILS.md.
# Both documents live under docs/reference/, so `dot tools docs` answered
# "TOOLS.md not found" on a complete checkout — the subcommand could not work
# for anyone. The reference location is probed first, the legacy one after,
# so a pre-reorg checkout still resolves.
test_start "tools_docs_prints_the_tools_document"
_docs_out="$DOTFILES_COV_TMPDIR/tools-docs.out"
_docs_rc=0
bash "$TOOLS_FILE" tools docs >"$_docs_out" 2>&1 || _docs_rc=$?
assert_equals "0" "$_docs_rc" "tools docs exits 0 on a complete checkout"
assert_file_contains "$_docs_out" "Integrated tools organized by role" \
  "the body of docs/reference/TOOLS.md is printed"
assert_output_not_contains "TOOLS.md not found" "cat '$_docs_out'"

test_start "tools_docs_falls_back_to_the_legacy_location"
# A tree that only has the pre-reorg docs/TOOLS.md must still resolve.
_legacy="$DOTFILES_COV_TMPDIR/legacy-repo"
mkdir -p "$_legacy/docs" "$_legacy/lib/dot"
printf 'legacy-tools-doc\n' >"$_legacy/docs/TOOLS.md"
_docs_rc=0
(
  set +e
  # shellcheck disable=SC1090
  source "$REPO_ROOT/lib/dot/utils.sh"
  # shellcheck disable=SC1090
  set -- tools
  source "$TOOLS_FILE" >/dev/null 2>&1
  _DOT_SOURCE_DIR_CACHE="$_legacy"
  cmd_tools docs
) >"$_docs_out" 2>&1 || _docs_rc=$?
assert_file_contains "$_docs_out" "legacy-tools-doc" "the legacy docs/TOOLS.md is still found"

test_start "tools_docs_reports_a_tree_with_neither_document"
_bare="$DOTFILES_COV_TMPDIR/bare-repo"
mkdir -p "$_bare/docs"
_docs_rc=0
(
  set +e
  # shellcheck disable=SC1090
  source "$REPO_ROOT/lib/dot/utils.sh"
  set -- tools
  # shellcheck disable=SC1090
  source "$TOOLS_FILE" >/dev/null 2>&1
  _DOT_SOURCE_DIR_CACHE="$_bare"
  cmd_tools docs
) >"$_docs_out" 2>&1 || _docs_rc=$?
assert_equals "1" "$_docs_rc" "a tree with no tools document fails"
assert_file_contains "$_docs_out" "TOOLS.md not found" "the missing document is named"

# Slice 3 (#883): exercise the script under sandbox for line coverage
cov_exercise_script "$TOOLS_FILE"

# Each present manager prints its exact line; the helpers' edge cases hold.
test_start "packages_lines_and_probe_edge_cases"
pk_tmp="$(mktemp -d)"
mkdir -p "$pk_tmp/bin" "$pk_tmp/home"
for m in pnpm bun; do printf '#!/usr/bin/env bash\necho 9.9.9\n' >"$pk_tmp/bin/$m"; done
printf '#!/usr/bin/env bash\necho "pip 8.8.8 from /x"\n' >"$pk_tmp/bin/pip3"
printf '#!/usr/bin/env bash\necho "go version go7.7.7 linux/amd64"\n' >"$pk_tmp/bin/go"
printf '#!/usr/bin/env bash\necho one; echo two; exit 3\n' >"$pk_tmp/bin/fails-with-output"
printf '#!/usr/bin/env bash\nexit 3\n' >"$pk_tmp/bin/fails-silently"
printf '#!/usr/bin/env bash\nexit 0\n' >"$pk_tmp/bin/says-nothing"
printf '#!/usr/bin/env bash\necho late; sleep 30\n' >"$pk_tmp/bin/never-ends"
chmod +x "$pk_tmp/bin/"*
pk_out="$(
  run_with_timeout 30 env PATH="$pk_tmp/bin:/usr/bin:/bin" HOME="$pk_tmp/home" bash -c '
    f="$1"; set -- tools; source "$f"
    source "${f%/*}/tools/packages.sh"
    show_language_package_managers
    echo "count-fail-out=[$(_pkg_count . fails-with-output)]"
    echo "count-fail-silent=[$(_pkg_count . fails-silently)]"
    echo "count-ok=[$(_pkg_count . pnpm)]"
    echo "word-empty=[$(_pkg_word 0 says-nothing)]"
    echo "word-field=[$(_pkg_word 2 pip3)]"
    echo "word-timeout=[$(DOTFILES_PACKAGES_TIMEOUT=1 _pkg_word 0 never-ends)]"
  ' _ "$TOOLS_FILE" 2>&1
)"
assert_contains "  pnpm: 9.9.9" "$pk_out" "pnpm line"
assert_contains "  Bun: 9.9.9" "$pk_out" "Bun line"
assert_contains "  pip: 8.8.8" "$pk_out" "pip line takes the version field"
assert_contains "  Go: go7.7.7" "$pk_out" "Go line takes the version field"
assert_contains "count-fail-out=[2]" "$pk_out" "a failing command's output still counts"
assert_contains "count-fail-silent=[N/A]" "$pk_out" "a silent failure reads N/A"
assert_contains "count-ok=[1]" "$pk_out" "a successful command is counted"
assert_contains "word-empty=[installed]" "$pk_out" "no output reads installed"
assert_contains "word-field=[8.8.8]" "$pk_out" "field selection"
assert_contains "word-timeout=[timed out]" "$pk_out" "a version probe past its limit reads timed out"
rm -rf "$pk_tmp"

# A package manager that never answers must not hang `dot packages`. The
# stuck cargo leaves a grandchild holding stdout, as rustup's proxy does, so
# only killing the whole process group lets the $( ) capture return.
test_start "packages_bounds_a_stuck_package_manager"
stuck_tmp="$(mktemp -d)"
mkdir -p "$stuck_tmp/bin" "$stuck_tmp/home"
cat >"$stuck_tmp/bin/cargo" <<'SHIM'
#!/usr/bin/env bash
case "${1:-}" in
  install) sleep 60 & wait ;;
  --version) echo "cargo 9.9.9" ;;
esac
SHIM
cat >"$stuck_tmp/bin/npm" <<'SHIM'
#!/usr/bin/env bash
case "${1:-}" in
  --version) echo "9.9.9" ;;
  list) echo "├── one" ;;
esac
SHIM
chmod +x "$stuck_tmp/bin/"*
stuck_start=$SECONDS
stuck_out="$(
  run_with_timeout 30 env PATH="$stuck_tmp/bin:/usr/bin:/bin" HOME="$stuck_tmp/home" \
    DOTFILES_PACKAGES_TIMEOUT=2 bash -c 'f="$1"; set -- tools; source "$f"; cmd_packages' _ "$TOOLS_FILE" 2>&1
)"
stuck_rc=$?
stuck_elapsed=$((SECONDS - stuck_start))
assert_equals "0" "$stuck_rc" "dot packages finishes with a stuck package manager (took ${stuck_elapsed}s)"
assert_equals "true" "$([[ $stuck_elapsed -lt 15 ]] && echo true || echo false)" \
  "the stuck probe is cut off at its limit, not the 60s it would take (${stuck_elapsed}s)"
assert_contains "Installed: timed out" "$stuck_out" "the stuck cargo count is reported as timed out"
assert_contains "npm: 9.9.9" "$stuck_out" "the other package managers are still reported"
rm -rf "$stuck_tmp"

# `dot tools install` checks every tool name before entering the Nix shell
# and passes flags through: a name with shell metacharacters must never
# reach nix, and a flag must not be rejected as a name.
test_start "tools_install_validates_names_and_passes_flags"
nix_tmp="$(mktemp -d)"
mkdir -p "$nix_tmp/bin" "$nix_tmp/home"
printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$*" >>"%s/nix.calls"\n' "$nix_tmp" >"$nix_tmp/bin/nix"
chmod +x "$nix_tmp/bin/nix"
nix_run() {
  env PATH="$nix_tmp/bin:$PATH" HOME="$nix_tmp/home" CHEZMOI_SOURCE_DIR="$REPO_ROOT" \
    bash "$TOOLS_FILE" tools install "$@" >"$nix_tmp/out" 2>&1
}
nix_run 'bad;name'
bad_rc=$?
assert_not_equals "0" "$bad_rc" "an invalid tool name fails"
assert_file_contains "$nix_tmp/out" "Invalid tool name: bad;name" "and is named"
assert_equals "0" "$(cat "$nix_tmp/nix.calls" 2>/dev/null | wc -l | tr -d ' ')" "nix is never run for it"
nix_run --impure node
assert_equals "0" "$?" "a flag and a valid name are accepted"
assert_contains "develop $REPO_ROOT/nix --impure node" "$(cat "$nix_tmp/nix.calls" 2>/dev/null)" \
  "nix develop receives the flag and the name"
rm -rf "$nix_tmp"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
