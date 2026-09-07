#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
#
# Guard-path tests for scripts/dot/commands/tools.sh:
#
#   tools install  — the "Nix is not installed" refusal.
#   new            — usage, template-name and project-name validation
#                    (path traversal), unknown template, existing
#                    destination, and a successful render.
#   packages       — the language package-manager report, including the
#                    pipx fallback when `pipx list` fails (a broken
#                    interpreter in real life).
#
# The command file is run directly (it dispatches on "$1" at the
# bottom) with PATH shims for nix/pipx/npm and a sandbox working
# directory, so nothing is installed and no project is written outside
# the sandbox.
#
# AUTO-GENERATED: false (hand-written)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

# Hand children a copy of the real stderr so their xtrace still reaches
# the coverage runner even though the probes capture output with 2>&1.
exec 21>&2
export BASH_XTRACEFD=21

TOOLS="$REPO_ROOT/scripts/dot/commands/tools.sh"
BASH_BIN="$(command -v bash)"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

WORK="$DOTFILES_COV_TMPDIR/work"
mkdir -p "$WORK"

_tools() { # [args…] — run from the sandbox working directory
  (cd "$WORK" && "$BASH_BIN" "$TOOLS" "$@" 2>&1)
}

# ── tools install without nix ────────────────────────────────────────
test_start "tools_install_refuses_without_nix"
_nonix="$DOTFILES_COV_TMPDIR/nonix"
mkdir -p "$_nonix"
for _t in bash cat printf echo sed tr uname date dirname basename \
  head tail wc mkdir cp rm grep awk sort stat find tput python3 git; do
  _p="$(command -v "$_t" 2>/dev/null || true)"
  [[ -n "$_p" ]] && ln -sf "$_p" "$_nonix/$_t"
done
_out="$(cd "$WORK" && PATH="$_nonix" "$BASH_BIN" "$TOOLS" tools install 2>&1)"
_rc=$?
assert_equals 1 "$_rc" "install without nix exits 1"
assert_contains "not installed" "$_out" "the missing prerequisite is named"
assert_contains "https://nixos.org/download/" "$_out" "the verified installer is linked"
assert_contains "use Homebrew/apt for individual tools" "$_out" "an alternative is suggested"

# ── dot new guards ───────────────────────────────────────────────────
test_start "new_without_arguments_prints_usage"
_out="$(_tools new)"
_rc=$?
assert_equals 1 "$_rc" "no arguments exits 1"
assert_contains "Usage: dot new <lang> <name>" "$_out" "usage printed"
assert_contains "Available templates:" "$_out" "templates listed"

_out="$(_tools new python)"
assert_equals 1 "$?" "a missing project name exits 1"

test_start "new_rejects_a_traversing_template_name"
_out="$(_tools new "../../etc" proj)"
_rc=$?
assert_not_equals 0 "$_rc" "a traversing template name is refused"
assert_contains "Invalid template name" "$_out" "the template name is rejected by name"

test_start "new_rejects_a_traversing_project_name"
_out="$(_tools new python "../escape")"
_rc=$?
assert_not_equals 0 "$_rc" "a traversing project name is refused"
assert_contains "Invalid project name" "$_out" "the project name is rejected by name"
assert_file_not_exists "$DOTFILES_COV_TMPDIR/escape" "nothing is created outside the working directory"

test_start "new_reports_an_unknown_template"
_out="$(_tools new nosuchlang proj)"
_rc=$?
assert_equals 1 "$_rc" "an unknown template exits 1"
assert_contains "Unknown template: nosuchlang" "$_out" "the template is named"
assert_contains "Available templates:" "$_out" "the known templates are listed"

test_start "new_refuses_to_overwrite_an_existing_destination"
mkdir -p "$WORK/taken"
_out="$(_tools new python taken)"
_rc=$?
assert_not_equals 0 "$_rc" "an existing destination is refused"
assert_contains "Destination exists" "$_out" "the collision is reported"

# ── packages ─────────────────────────────────────────────────────────
test_start "packages_reports_language_package_managers"
_pm="$DOTFILES_COV_TMPDIR/pm"
mkdir -p "$_pm"
for _t in bash cat printf echo sed tr uname date dirname basename \
  head tail wc mkdir grep awk sort stat find tput; do
  _p="$(command -v "$_t" 2>/dev/null || true)"
  [[ -n "$_p" ]] && ln -sf "$_p" "$_pm/$_t"
done
cat >"$_pm/pipx" <<'SHIM'
#!/usr/bin/env bash
case "${1:-}" in
  --version) echo "1.4.3" ;;
  list)
    if [[ -n "${PIPX_SHIM_BROKEN:-}" ]]; then
      echo "pipx: broken interpreter" >&2
      exit 1
    fi
    [[ -n "${PIPX_SHIM_EMPTY:-}" ]] && exit 0
    printf 'black 24.1.0\nruff 0.3.0\n'
    ;;
esac
exit 0
SHIM
chmod +x "$_pm/pipx"
_out="$(cd "$WORK" && PATH="$_pm" "$BASH_BIN" "$TOOLS" packages 2>&1)"
_rc=$?
assert_equals 0 "$_rc" "packages exits 0"
assert_contains "Package Managers" "$_out" "the system section header is printed"
assert_contains "Language Package Managers" "$_out" "the language section header is printed"
assert_contains "pipx: 1.4.3" "$_out" "the pipx version is reported"
assert_contains "Installed: 2" "$_out" "both installed pipx packages are counted"

test_start "packages_counts_an_empty_pipx_list_as_zero"
_out="$(cd "$WORK" && PATH="$_pm" PIPX_SHIM_EMPTY=1 "$BASH_BIN" "$TOOLS" packages 2>&1)"
assert_equals 0 "$?" "an empty pipx list exits 0"
assert_contains "Installed: 0" "$_out" "no packages counts as zero, not one"

test_start "packages_falls_back_when_pipx_list_fails"
_out="$(cd "$WORK" && PATH="$_pm" PIPX_SHIM_BROKEN=1 "$BASH_BIN" "$TOOLS" packages 2>&1)"
_rc=$?
assert_equals 0 "$_rc" "a failing pipx list does not abort the report"
assert_contains "Installed: N/A" "$_out" "the count degrades to N/A"
assert_contains "Language Package Managers" "$_out" "the rest of the report still renders"

test_start "tools_unknown_subcommand_fails"
_out="$(_tools totally-unknown)"
_rc=$?
assert_equals 1 "$_rc" "an unknown subcommand exits 1"
assert_contains "Unknown tools command" "$_out" "the error names the problem"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
