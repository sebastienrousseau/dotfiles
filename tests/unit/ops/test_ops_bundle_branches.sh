#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
#
# Branch coverage for scripts/ops/bundle.sh: usage errors, the
# XDG_RUNTIME_DIR fallback, the flock guard (free and contended), the
# tar/zstd prerequisite check, a successful bundle and a failed tar.
# `tar`, `zstd` and `flock` are PATH shims — no archive of the host is
# ever produced.
#
# AUTO-GENERATED: false (hand-written)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

# Route child xtrace to the runner's trace stream even when a probe
# captures 2>&1. bundle.sh does `exec 9>lockfile` when flock exists,
# so fd 9 is NOT usable here — fd 19 keeps the trace intact.
exec 21>&2
export BASH_XTRACEFD=21

SCRIPT_FILE="$REPO_ROOT/scripts/ops/bundle.sh"
BASH_BIN="$(command -v bash)"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

_link_real_tools() {
  local dir="$1" t p
  shift
  for t in "$@"; do
    p="$(command -v "$t" 2>/dev/null || true)"
    [[ -n "$p" ]] && ln -sf "$p" "$dir/$t"
  done
}

# Base tool set bundle.sh + ui.sh/log.sh need, without tar/zstd/flock.
_base="$DOTFILES_COV_TMPDIR/base"
mkdir -p "$_base"
# `rm`/`tail` matter beyond the obvious: log.sh pipes through `tail`,
# and bundle.sh's EXIT trap runs `rm -f` — a missing `rm` makes the
# trap exit 127 and mask the script's real status.
_link_real_tools "$_base" bash env dirname basename date mkdir stat cat sed awk grep \
  head tail tr uname tput hostname printf rm ln cp mv sort wc du find id sleep touch chmod

# tar shim: creates the -cf target (or fails when TAR_SHIM_FAIL=1);
# zstd shim only needs to exist for the prerequisite probe.
_arch="$DOTFILES_COV_TMPDIR/arch"
mkdir -p "$_arch"
cat >"$_arch/tar" <<'SHIM'
#!/usr/bin/env bash
printf 'tar %s\n' "$*" >>"${BUNDLE_SHIM_LOG:?}"
[[ "${TAR_SHIM_FAIL:-0}" == "1" ]] && exit 1
out=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -cf) out="$2"; shift 2 ;;
    *) shift ;;
  esac
done
echo "fake-zstd-archive" >"$out"
SHIM
printf '#!/usr/bin/env bash\nexit 0\n' >"$_arch/zstd"
chmod +x "$_arch/tar" "$_arch/zstd"
export BUNDLE_SHIM_LOG="$DOTFILES_COV_TMPDIR/bundle-shim.log"

_bundle() { # <path> [args]
  local path="$1"
  shift
  PATH="$path" "$BASH_BIN" "$SCRIPT_FILE" "$@" 2>&1
}

test_start "help_and_unknown_option"
_out="$(_bundle "$_arch:$_base" --help)"
assert_equals 0 $? "--help exits 0"
assert_contains "Usage: bundle.sh [output-dir]" "$_out" "usage printed"
_out="$(_bundle "$_arch:$_base" --bogus)"
assert_equals 2 $? "unknown option exits 2"
assert_contains "Unknown option: --bogus" "$_out" "option named"

test_start "bundle_written_to_requested_dir_with_runtime_dir_fallback"
: >"$BUNDLE_SHIM_LOG"
_outdir="$DOTFILES_COV_TMPDIR/out"
_out="$(XDG_RUNTIME_DIR=/nonexistent/runtime _bundle "$_arch:$_base" "$_outdir")"
_rc=$?
assert_equals 0 "$_rc" "bundle exits 0"
assert_contains "Adding: $HOME/.dotfiles" "$_out" "existing path listed"
assert_contains "Bundle created" "$_out" "success line printed"
_file="$(find "$_outdir" -name 'dotfiles_offline_bundle_*.tar.zst' | head -1)"
assert_not_empty "$_file" "archive file created"
assert_contains "tar --zstd -cf $_file -P $HOME/.dotfiles" "$(cat "$BUNDLE_SHIM_LOG")" "tar invoked with zstd and existing paths only"
assert_contains "tar --zstd -xf $_file -P" "$_out" "restore hint printed"

test_start "flock_free_proceeds_and_contended_exits_0"
_flock="$DOTFILES_COV_TMPDIR/flock"
mkdir -p "$_flock"
printf '#!/usr/bin/env bash\nexit "${FLOCK_SHIM_RC:-0}"\n' >"$_flock/flock"
chmod +x "$_flock/flock"
_out="$(XDG_RUNTIME_DIR="$DOTFILES_COV_TMPDIR" _bundle "$_flock:$_arch:$_base" "$DOTFILES_COV_TMPDIR/out2")"
assert_equals 0 $? "free lock exits 0"
assert_contains "Bundle created" "$_out" "bundle proceeds after flock"
assert_file_exists "$DOTFILES_COV_TMPDIR/dotfiles-bundle.lock" "lock file opened in XDG_RUNTIME_DIR"
_out="$(FLOCK_SHIM_RC=1 XDG_RUNTIME_DIR="$DOTFILES_COV_TMPDIR" _bundle "$_flock:$_arch:$_base" "$DOTFILES_COV_TMPDIR/out3")"
assert_equals 0 $? "contended lock exits 0"
assert_contains "Already running" "$_out" "already-running warning printed"
assert_dir_not_exists "$DOTFILES_COV_TMPDIR/out3" "no output dir created when locked out"

test_start "missing_zstd_exits_1"
_taronly="$DOTFILES_COV_TMPDIR/taronly"
mkdir -p "$_taronly"
ln -sf "$_arch/tar" "$_taronly/tar"
_out="$(_bundle "$_taronly:$_base" "$DOTFILES_COV_TMPDIR/out4")"
_rc=$?
assert_equals 1 "$_rc" "missing zstd exits 1"
assert_contains "tar and zstd are required" "$_out" "prerequisite error printed"

test_start "tar_failure_exits_1"
_out="$(TAR_SHIM_FAIL=1 _bundle "$_arch:$_base" "$DOTFILES_COV_TMPDIR/out5")"
_rc=$?
assert_equals 1 "$_rc" "tar failure exits 1"
assert_contains "Failed to create bundle" "$_out" "failure reported"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
