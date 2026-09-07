#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034,SC2016
# Behavioural coverage for functions/misc/lazy_loaders.sh.
#
# Each loader is only defined when its tool is installed, and the first
# call must (a) drop the trigger aliases, (b) load the real tool and
# (c) re-run the command that triggered it — exactly once. The
# "exactly once" half is what the `unalias` fix restored: while the
# aliases survived the first load, every later call went back through
# the loader (and `lazy_rbenv` re-entered itself without bound because
# `$(rbenv init -)` is alias-expanded at runtime).
#
# Fake nvm/sdkman installs and an rbenv shim live inside the sandbox
# HOME; nothing here touches the host.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

# Hand children a copy of the real stderr so their bash xtrace still
# reaches the coverage runner's trace file even though the probes
# below capture the command's own output with 2>&1.
exec 21>&2
export BASH_XTRACEFD=21

FUNC_FILE="$REPO_ROOT/defaults/.chezmoitemplates/functions/misc/lazy_loaders.sh"
BASH_BIN="${BASH:-$(command -v bash)}"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

# ── Fixtures: fake nvm / sdkman installs + an rbenv binary on PATH ──
# The init files use the `function name {` form on purpose: the trigger
# aliases are live while they are sourced, and bash alias-expands a
# bare `name() {` header into a syntax error.
mkdir -p "$HOME/.nvm" "$HOME/.sdkman/bin"
counts="$DOTFILES_COV_TMPDIR/counts"
mkdir -p "$counts"

cat >"$HOME/.nvm/nvm.sh" <<EOF
echo nvm >>"$counts/nvm.sourced"
function nvm { echo "nvm-real \$*"; }
function node { echo "node-real \$*"; }
function npm { echo "npm-real \$*"; }
EOF
echo ': bash completion stub' >"$HOME/.nvm/bash_completion"

cat >"$HOME/.sdkman/bin/sdkman-init.sh" <<EOF
echo sdk >>"$counts/sdk.sourced"
function sdk { echo "sdk-real \$*"; }
function java { echo "java-real \$*"; }
EOF

cat >"$DOTFILES_COV_TMPDIR/bin/rbenv" <<EOF
#!/usr/bin/env bash
echo rbenv >>"$counts/rbenv.called"
if [[ "\${1:-}" == "init" ]]; then
  echo 'function rbenv { echo "rbenv-real \$*"; }; function ruby { echo "ruby-real \$*"; }'
else
  echo "rbenv-bin \$*"
fi
EOF
chmod +x "$DOTFILES_COV_TMPDIR/bin/rbenv"

# Driver: aliases only expand on lines parsed after the alias exists,
# so every probe is its own line of a real script run by the same bash
# the harness uses.
driver="$DOTFILES_COV_TMPDIR/driver.sh"
cat >"$driver" <<EOF
shopt -s expand_aliases
source "$FUNC_FILE"
echo "--- aliases-before"
alias nvm node npm yarn npx rbenv ruby gem bundle sdk java gradle mvn kotlin
node --version
node --second
sdk version
ruby -v
echo "--- aliases-after"
alias node 2>/dev/null || echo "node-alias-gone"
alias ruby 2>/dev/null || echo "ruby-alias-gone"
alias kotlin 2>/dev/null || echo "kotlin-alias-gone"
EOF

test_start "lazy_loaders_wires_aliases_for_installed_tools"
out="$(run_with_timeout 30 "$BASH_BIN" "$driver" 2>&1)"
rc=$?
assert_equals 0 "$rc" "driver completes (no runaway recursion)"
assert_contains "alias node='lazy_nvm node'" "$out" "node alias points at lazy_nvm"
assert_contains "alias bundle='lazy_rbenv bundle'" "$out" "bundle alias points at lazy_rbenv"
assert_contains "alias kotlin='lazy_sdk kotlin'" "$out" "kotlin alias points at lazy_sdk"

test_start "lazy_nvm_sources_nvm_and_reruns_command"
assert_contains "node-real --version" "$out" "nvm.sh functions replace the alias stub"

test_start "lazy_rbenv_evals_init_and_reruns_command"
assert_contains "ruby-real -v" "$out" "rbenv init - output is eval'd, then ruby runs"

test_start "lazy_sdk_sources_init_and_reruns_command"
assert_contains "sdk-real version" "$out" "sdkman-init.sh functions replace the alias stub"

test_start "lazy_loaders_drop_their_trigger_aliases"
assert_contains "node-alias-gone" "$out" "nvm aliases removed after loading"
assert_contains "ruby-alias-gone" "$out" "rbenv aliases removed after loading"
assert_contains "kotlin-alias-gone" "$out" "sdkman aliases removed after loading"

test_start "lazy_nvm_loads_once_not_per_invocation"
assert_contains "node-real --second" "$out" "second call still reaches the real node"
assert_equals 1 "$(wc -l <"$counts/nvm.sourced" | tr -d ' ')" "nvm.sh sourced exactly once"

test_start "lazy_rbenv_calls_rbenv_init_once"
assert_equals 1 "$(wc -l <"$counts/rbenv.called" | tr -d ' ')" "rbenv invoked once (no re-entry)"

test_start "lazy_loaders_absent_when_tools_missing"
empty_home="$DOTFILES_COV_TMPDIR/empty-home"
mkdir -p "$empty_home"
out="$(HOME="$empty_home" PATH="/usr/bin:/bin" "$BASH_BIN" -c \
  'source "$1"; declare -f lazy_nvm lazy_rbenv lazy_sdk >/dev/null && echo DEFINED || echo UNDEFINED' \
  _ "$FUNC_FILE" 2>&1)"
assert_contains "UNDEFINED" "$out" "no loader is defined without nvm/rbenv/sdkman"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
