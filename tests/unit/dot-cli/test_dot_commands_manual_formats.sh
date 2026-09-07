#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
#
# Behaviour tests for scripts/dot/commands/manual.sh: format selection,
# the cache-then-fetch path, download failures, --offline and --local
# sources, `download` mode, and the per-format open behaviour (pager
# for text, tarball extraction for markdown, URL for html).
#
# `curl`, the opener and $PAGER are PATH shims that record what they
# received, and DOTFILES_MANUAL_URL points at a fake host, so no
# request leaves the machine and nothing opens a window. Cache,
# offline and download directories all live in the sandbox.
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

MANUAL="$REPO_ROOT/scripts/dot/commands/manual.sh"
BASH_BIN="$(command -v bash)"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

LOG="$DOTFILES_COV_TMPDIR/manual.log"
: >"$LOG"

SHIMS="$DOTFILES_COV_TMPDIR/manual-shims"
mkdir -p "$SHIMS"

# curl shim: writes a body to -o <path> unless CURL_SHIM_FAIL is set.
cat >"$SHIMS/curl" <<EOF
#!/usr/bin/env bash
printf 'curl %s\n' "\$*" >>"$LOG"
[[ -n "\${CURL_SHIM_FAIL:-}" ]] && exit 22
out=""
prev=""
for a in "\$@"; do
  [[ "\$prev" == "-o" ]] && out="\$a"
  prev="\$a"
done
[[ -n "\$out" ]] && printf 'fetched-manual-body\n' >"\$out"
exit 0
EOF
# Opener + pager shims.
cat >"$SHIMS/xdg-open" <<EOF
#!/usr/bin/env bash
printf 'xdg-open %s\n' "\$*" >>"$LOG"
EOF
cat >"$SHIMS/fake-pager" <<EOF
#!/usr/bin/env bash
printf 'pager %s\n' "\$*" >>"$LOG"
EOF
cat >"$SHIMS/uname" <<'EOF'
#!/usr/bin/env bash
echo "${MANUAL_TEST_UNAME:-Linux}"
EOF
chmod +x "$SHIMS/curl" "$SHIMS/xdg-open" "$SHIMS/fake-pager" "$SHIMS/uname"

MANUAL_URL="https://manual.test/dotfiles"

_manual() { # [args…]
  DOTFILES_MANUAL_URL="$MANUAL_URL" PAGER="$SHIMS/fake-pager" \
    PATH="$SHIMS:$PATH" "$BASH_BIN" "$MANUAL" "$@" 2>&1
}

CACHE="$XDG_CACHE_HOME/dotfiles/manual"
OFFLINE="$XDG_DATA_HOME/dotfiles/manual"

test_start "manual_help_lists_the_usage_block"
_out="$(_manual --help)"
_rc=$?
assert_equals 0 "$_rc" "--help exits 0"
assert_contains "dot manual pdf" "$_out" "the pdf form is documented"
assert_contains "dot manual download <fmt>" "$_out" "the download form is documented"

test_start "manual_fetches_a_format_once_and_then_serves_it_from_cache"
: >"$LOG"
_out="$(_manual pdf)"
_rc=$?
assert_equals 0 "$_rc" "first pdf open exits 0"
assert_file_exists "$CACHE/dotfiles.pdf" "the pdf was cached"
assert_file_contains "$LOG" "$MANUAL_URL/dotfiles.pdf" "the format-specific URL was fetched"
assert_file_contains "$LOG" "xdg-open $CACHE/dotfiles.pdf" "the cached file was opened"
: >"$LOG"
_out="$(_manual pdf)"
assert_equals 0 "$?" "second pdf open exits 0"
assert_output_not_contains "curl " cat "$LOG"

test_start "manual_reports_a_failed_download"
: >"$LOG"
_out="$(CURL_SHIM_FAIL=1 _manual epub)"
_rc=$?
assert_equals 1 "$_rc" "a failed fetch exits 1"
assert_contains "failed to download $MANUAL_URL/dotfiles.epub" "$_out" "the URL is named in the error"
assert_file_not_exists "$CACHE/dotfiles.epub" "nothing is left in the cache"

test_start "manual_text_format_goes_to_the_pager"
: >"$LOG"
_out="$(_manual text)"
_rc=$?
assert_equals 0 "$_rc" "text open exits 0"
assert_file_contains "$LOG" "pager $CACHE/dotfiles.txt" "the pager received the cached text manual"

test_start "manual_html_opens_the_site_rather_than_a_file"
: >"$LOG"
_out="$(_manual html)"
assert_equals 0 "$?" "html open exits 0"
assert_file_contains "$LOG" "xdg-open $MANUAL_URL/" "the manual site URL is opened"
: >"$LOG"
_out="$(_manual html-multi)"
assert_file_contains "$LOG" "xdg-open $MANUAL_URL/html/" "html-multi opens the multi-page URL"

test_start "manual_markdown_extracts_the_tarball"
_srcdir="$DOTFILES_COV_TMPDIR/md-src"
mkdir -p "$_srcdir"
printf '# Manual\n' >"$_srcdir/index.md"
mkdir -p "$CACHE"
tar -czf "$CACHE/dotfiles-md.tar.gz" -C "$_srcdir" index.md
: >"$LOG"
_out="$(_manual markdown)"
_rc=$?
assert_equals 0 "$_rc" "markdown open exits 0"
assert_contains "Markdown source extracted to:" "$_out" "the extraction directory is reported"

test_start "manual_offline_source"
mkdir -p "$OFFLINE"
printf 'offline-manual\n' >"$OFFLINE/dotfiles.pdf"
: >"$LOG"
_out="$(_manual pdf --offline)"
_rc=$?
assert_equals 0 "$_rc" "offline open exits 0"
assert_file_contains "$LOG" "xdg-open $OFFLINE/dotfiles.pdf" "the offline copy was opened"
assert_output_not_contains "curl " cat "$LOG"

_out="$(_manual epub --offline)"
_rc=$?
assert_equals 1 "$_rc" "a missing offline copy exits 1"
assert_contains "offline copy not found at $OFFLINE/dotfiles.epub" "$_out" "the expected path is named"

test_start "manual_local_build_is_reported_when_absent"
_out="$(_manual pdf --local)"
_rc=$?
assert_equals 1 "$_rc" "a missing local build exits 1"
assert_contains "local build not found" "$_out" "the missing build is reported"
assert_contains "build-manual.sh" "$_out" "the way to produce it is suggested"

test_start "manual_download_mode_copies_into_the_working_directory"
_dl="$DOTFILES_COV_TMPDIR/downloads"
mkdir -p "$_dl"
: >"$LOG"
_out="$(cd "$_dl" && DOTFILES_MANUAL_URL="$MANUAL_URL" PATH="$SHIMS:$PATH" \
  "$BASH_BIN" "$MANUAL" download pdf 2>&1)"
_rc=$?
assert_equals 0 "$_rc" "download exits 0"
assert_file_exists "$_dl/dotfiles.pdf" "the manual landed in the working directory"
assert_contains "saved: ./dotfiles.pdf" "$_out" "the destination is reported"

test_start "manual_custom_url_override"
: >"$LOG"
_out="$(DOTFILES_MANUAL_URL="$MANUAL_URL" PATH="$SHIMS:$PATH" \
  "$BASH_BIN" "$MANUAL" epub --url=https://mirror.test/manual 2>&1)"
assert_file_contains "$LOG" "https://mirror.test/manual/dotfiles.epub" "--url= replaces the manual host"

test_start "manual_open_falls_back_to_a_message_on_other_platforms"
: >"$LOG"
_out="$(MANUAL_TEST_UNAME=FreeBSD _manual pdf)"
_rc=$?
assert_equals 0 "$_rc" "an unsupported platform still exits 0"
assert_contains "saved to: $CACHE/dotfiles.pdf" "$_out" "the path is printed instead of opened"

test_start "manual_reports_when_no_opener_is_available"
_bare="$DOTFILES_COV_TMPDIR/no-opener"
mkdir -p "$_bare"
for _t in bash cat printf echo sed find wc mkdir dirname basename tr uname date stat cp curl tar head; do
  _p="$(command -v "$_t" 2>/dev/null || true)"
  [[ -n "$_p" ]] && ln -sf "$_p" "$_bare/$_t"
done
ln -sf "$SHIMS/curl" "$_bare/curl"
# Keep the uname shim: without it the real `uname` reports Darwin here
# and manual.sh calls /usr/bin/open by absolute path, which would open a
# window on the machine running the tests.
ln -sf "$SHIMS/uname" "$_bare/uname"
_out="$(MANUAL_TEST_UNAME=Linux DOTFILES_MANUAL_URL="$MANUAL_URL" PATH="$_bare" \
  "$BASH_BIN" "$MANUAL" pdf 2>&1)"
_rc=$?
assert_equals 1 "$_rc" "no opener exits 1"
assert_contains "no opener found" "$_out" "the missing openers are named"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
