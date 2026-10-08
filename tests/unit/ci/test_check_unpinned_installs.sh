#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2016,SC2034
# tools/ci/check-unpinned-installs.sh: a chezmoi run_* script that installs
# something unpinned (@latest, cargo install without --locked, a git clone
# of a moving branch) fails the lint. Each fixture is a throwaway tree with a
# copy of the checker and one run_* script.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

checker="$REPO_ROOT/tools/ci/check-unpinned-installs.sh"

WORK="$(mktemp -d -t unpinned-installs.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

# fixture <name> <relative-path> <line>: prints the checker's exit status.
fixture() {
  local root="$WORK/$1" rc=0
  mkdir -p "$root/tools/ci" "$(dirname "$root/$2")"
  cp "$checker" "$root/tools/ci/check-unpinned-installs.sh"
  printf '#!/usr/bin/env bash\n%s\n' "$3" >"$root/$2"
  bash "$root/tools/ci/check-unpinned-installs.sh" >"$root.out" 2>&1 || rc=$?
  printf '%s' "$rc"
}

test_start "repository_has_no_unpinned_installs"
rc=0
bash "$checker" >"$WORK/repo.out" 2>&1 || rc=$?
assert_equals "0" "$rc" "every run_* script in the repository pins what it installs"

test_start "flags_go_install_latest"
assert_equals "1" "$(fixture go install/provision/run_onchange_27-go.sh.tmpl 'go install golang.org/x/tools/gopls@latest')" \
  "go install ...@latest is flagged"

test_start "flags_mise_use_latest_variable"
assert_equals "1" "$(fixture mise install/provision/run_onchange_15-ai.sh.tmpl '    mise use -g "$tool@latest"')" \
  "mise use -g tool@latest is flagged"

test_start "flags_cargo_install_without_locked"
assert_equals "1" "$(fixture cargo install/provision/run_onchange_26-rust.sh.tmpl '  cargo install "$package" || true')" \
  "cargo install without --locked is flagged"

test_start "flags_git_clone_of_branch"
assert_equals "1" "$(fixture clone install/provision/run_onchange_12-tmux.sh.tmpl 'git clone https://github.com/tmux-plugins/tpm "$dir"')" \
  "a plain git clone is flagged"

test_start "flags_in_defaults_run_scripts"
assert_equals "1" "$(fixture defaults defaults/run_onchange_after_x.sh.tmpl 'npm install -g foo@latest')" \
  "run_* scripts under defaults/ are scanned too"

test_start "flags_last_line_without_newline"
mkdir -p "$WORK/nonl/tools/ci" "$WORK/nonl/install/provision"
cp "$checker" "$WORK/nonl/tools/ci/check-unpinned-installs.sh"
printf '#!/usr/bin/env bash\ngo install x@latest' >"$WORK/nonl/install/provision/run_onchange_97-n.sh"
rc=0
bash "$WORK/nonl/tools/ci/check-unpinned-installs.sh" >"$WORK/nonl.out" 2>&1 || rc=$?
assert_equals "1" "$rc" "a final line with no newline is still checked"

test_start "report_names_file_line_and_summary"
fixture report install/provision/run_onchange_96-r.sh.tmpl 'go install x@latest' >/dev/null
assert_contains "install/provision/run_onchange_96-r.sh.tmpl:2:" "$(cat "$WORK/report.out")" \
  "the finding points at the file and line"
assert_contains "Unpinned installs in run_* scripts" "$(cat "$WORK/report.out")" "a summary line closes the report"

test_start "flags_install_followed_by_comment"
assert_equals "1" "$(fixture trailing install/provision/run_onchange_95-t.sh.tmpl 'go install x@latest # TODO pin')" \
  "a trailing comment does not hide the install before it"

test_start "allows_pinned_forms"
assert_equals "0" "$(fixture pinned install/provision/run_onchange_99-ok.sh.tmpl 'go install golang.org/x/tools/gopls@v0.23.0
cargo install --locked --version 0.13.13 cargo-edit
cargo install --list
git clone --no-checkout https://github.com/tmux-plugins/tpm "$dir"
git -C "$dir" checkout --quiet --detach "$commit"')" \
  "exact versions, --locked and a pinned checkout pass"

test_start "ignores_comments_and_other_files"
assert_equals "0" "$(fixture comments install/provision/run_onchange_98-c.sh.tmpl '# go install x@latest is what we avoid')" \
  "a comment describing the pattern is not flagged"
assert_equals "0" "$(fixture other install/lib/helper.sh 'go install x@latest')" \
  "files that are not run_* scripts are out of scope"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
