#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
#
# Behaviour tests for defaults/.chezmoitemplates/functions/security/keygen.sh.
# Every branch is driven through arguments, stdin (interactive mode)
# and a tightly controlled PATH: `ssh-keygen` and `ssh-add` are shims
# that write fake key files, `uname` is shimmed for the Linux arm,
# and the clipboard tools (cb / pbcopy / xclip / wl-copy / clip.exe)
# are shims that record what they received. No real key material,
# agent or clipboard is touched.
#
# AUTO-GENERATED: false (hand-written)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

# Route child xtrace to the runner's trace stream even when a probe
# captures 2>&1 (fd 19: fd 9 is taken by lock handling elsewhere).
exec 21>&2
export BASH_XTRACEFD=21

FUNC_FILE="$REPO_ROOT/defaults/.chezmoitemplates/functions/security/keygen.sh"
BASH_BIN="$(command -v bash)"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

# ── Controlled PATH ───────────────────────────────────────────────────
# Only what keygen itself needs. The clipboard probes in
# copy_to_clipboard must NOT see the host's pbcopy/xclip, so the
# clipboard shim of each case lives in its own directory.
_kbin="$DOTFILES_COV_TMPDIR/kbin"
mkdir -p "$_kbin"
for _t in bash mkdir chmod uname dirname cat; do
  _p="$(command -v "$_t" 2>/dev/null || true)"
  [[ -n "$_p" ]] && ln -sf "$_p" "$_kbin/$_t"
done

cat >"$_kbin/ssh-keygen" <<'SHIM'
#!/usr/bin/env bash
# Fake ssh-keygen: `-l -f pub` prints a fingerprint; otherwise writes a
# private/public pair at the -f path and records the argv.
printf 'ssh-keygen %s\n' "$*" >>"${KEYGEN_SHIM_LOG:?}"
if [[ "$1" == "-l" ]]; then
  echo "256 SHA256:shim-fingerprint comment (SHIM)"
  exit 0
fi
path=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -f) path="$2"; shift 2 ;;
    *) shift ;;
  esac
done
echo "shim-private-key" >"$path"
echo "ssh-shim AAAA shim@example.com" >"$path.pub"
SHIM
cat >"$_kbin/ssh-add" <<'SHIM'
#!/usr/bin/env bash
printf 'ssh-add %s\n' "$*" >>"${KEYGEN_SHIM_LOG:?}"
exit "${SSH_ADD_RC:-0}"
SHIM
chmod +x "$_kbin/ssh-keygen" "$_kbin/ssh-add"
export KEYGEN_SHIM_LOG="$DOTFILES_COV_TMPDIR/keygen-shim.log"

# Clipboard shims: each records stdin into $CLIP_OUT.
_clip_dir() { # <tool> → dir holding only that clipboard shim
  local d="$DOTFILES_COV_TMPDIR/clip-$1"
  mkdir -p "$d"
  printf '#!/usr/bin/env bash\ncat >"${CLIP_OUT:?}"\n' >"$d/$1"
  chmod +x "$d/$1"
  printf '%s\n' "$d"
}
export CLIP_OUT="$DOTFILES_COV_TMPDIR/clip.txt"

# Linux arm: `uname -s` must say Linux.
_linux="$DOTFILES_COV_TMPDIR/linux"
mkdir -p "$_linux"
printf '#!/usr/bin/env bash\necho Linux\n' >"$_linux/uname"
chmod +x "$_linux/uname"

# Run keygen from a fresh bash with the function file sourced. PATH is
# set INSIDE the child so the sourced prelude and keygen both see it.
_keygen() { # <extra-path> [args...]  (stdin passes through)
  local extra="$1"
  shift
  "$BASH_BIN" -c 'export PATH="$1"; source "$2"; shift 2; keygen "$@"' _ \
    "${extra:+$extra:}$_kbin" "$FUNC_FILE" "$@" 2>&1
}

_fresh_home() { # <name>
  export HOME="$DOTFILES_COV_TMPDIR/homes/$1"
  mkdir -p "$HOME"
}

test_start "help_prints_usage"
_out="$(_keygen "" --help)"
_rc=$?
assert_equals 0 "$_rc" "--help exits 0"
assert_contains "SSH Key Generator (keygen)" "$_out" "help banner printed"

test_start "single_argument_is_a_usage_error"
_fresh_home usage
_out="$(_keygen "" onlyname)"
_rc=$?
assert_equals 1 "$_rc" "one positional exits 1"
assert_contains "Usage: keygen" "$_out" "usage error printed"

test_start "ssh_dir_creation_failure_exits_1"
_fresh_home sshfile
: >"$HOME/.ssh" # a FILE named .ssh makes mkdir -p fail
_out="$(_keygen "" k user@example.com)"
_rc=$?
assert_equals 1 "$_rc" "unwritable ~/.ssh exits 1"
assert_contains "Failed to create ~/.ssh" "$_out" "mkdir failure reported"

test_start "input_validation_rejects_bad_name_email_type_bits"
_fresh_home validate
_out="$(_keygen "" 'bad name!' user@example.com)"
assert_equals 1 $? "bad name exits 1"
assert_contains "Invalid name format" "$_out" "bad name reported"
_out="$(_keygen "" goodname not-an-email)"
assert_equals 1 $? "bad email exits 1"
assert_contains "Invalid email format" "$_out" "bad email reported"
_out="$(_keygen "" goodname user@example.com rsa abc)"
assert_equals 1 $? "non-numeric rsa bits exits 1"
assert_contains "RSA key length must be a number" "$_out" "non-numeric bits reported"
_out="$(_keygen "" goodname user@example.com rsa 1024)"
assert_equals 1 $? "short rsa bits exits 1"
assert_contains "between 2048 and 8192" "$_out" "rsa range reported"
_out="$(_keygen "" goodname user@example.com ecdsa 999)"
assert_equals 1 $? "bad ecdsa bits exits 1"
assert_contains "256, 384, or 521" "$_out" "ecdsa sizes reported"
_out="$(_keygen "" goodname user@example.com dsa)"
assert_equals 1 $? "unknown type exits 1"
assert_contains "Invalid key type: dsa" "$_out" "unknown type reported"

test_start "ed25519_key_generated_and_copied_via_pbcopy"
_fresh_home ed
: >"$KEYGEN_SHIM_LOG"
: >"$CLIP_OUT"
_out="$(_keygen "$(_clip_dir pbcopy)" mykey me@example.com)"
_rc=$?
assert_equals 0 "$_rc" "ed25519 generation exits 0"
assert_file_exists "$HOME/.ssh/id_ed25519_mykey" "private key written"
assert_file_exists "$HOME/.ssh/id_ed25519_mykey.pub" "public key written"
assert_contains "ssh-keygen -t ed25519 -f $HOME/.ssh/id_ed25519_mykey -C me@example.com" "$(cat "$KEYGEN_SHIM_LOG")" "ssh-keygen invoked with ed25519"
assert_contains "SSH key successfully generated" "$_out" "success message printed"
assert_contains "SHA256:shim-fingerprint" "$_out" "fingerprint printed"
assert_contains "copied to clipboard (macOS)" "$_out" "pbcopy branch reported"
assert_contains "ssh-shim AAAA" "$(cat "$CLIP_OUT")" "public key reached the clipboard shim"
assert_equals "700" "$(stat -f '%Lp' "$HOME/.ssh" 2>/dev/null || stat -c '%a' "$HOME/.ssh")" "the .ssh directory is mode 0700"
assert_equals "600" "$(stat -f '%Lp' "$HOME/.ssh/id_ed25519_mykey" 2>/dev/null || stat -c '%a' "$HOME/.ssh/id_ed25519_mykey")" "private key is 0600"

test_start "existing_key_is_not_regenerated"
: >"$KEYGEN_SHIM_LOG"
_out="$(_keygen "$(_clip_dir pbcopy)" mykey me@example.com)"
_rc=$?
assert_equals 0 "$_rc" "existing key exits 0"
assert_contains "Key already exists" "$_out" "skip warning printed"
assert_equals "" "$(cat "$KEYGEN_SHIM_LOG")" "ssh-keygen not invoked"

test_start "rsa_key_on_linux_with_agent_down_warns_and_uses_xclip"
_fresh_home rsa
: >"$KEYGEN_SHIM_LOG"
_out="$(SSH_ADD_RC=1 _keygen "$_linux:$(_clip_dir xclip)" rsakey me@example.com rsa 4096)"
_rc=$?
assert_equals 0 "$_rc" "rsa generation exits 0"
assert_contains "ssh-keygen -t rsa -b 4096 -f $HOME/.ssh/id_rsa_rsakey" "$(cat "$KEYGEN_SHIM_LOG")" "ssh-keygen invoked with rsa bits"
assert_contains "ssh-add $HOME/.ssh/id_rsa_rsakey" "$(cat "$KEYGEN_SHIM_LOG")" "plain ssh-add used on Linux"
assert_contains "SSH agent not running. Start it and run 'ssh-add $HOME" "$_out" "agent warning printed"
assert_contains "copied to clipboard (Linux)" "$_out" "xclip branch reported"

test_start "ecdsa_defaults_to_256_bits_with_cb_clipboard"
_fresh_home ecdsa
: >"$KEYGEN_SHIM_LOG"
_out="$(_keygen "$(_clip_dir cb)" eckey me@example.com ecdsa)"
_rc=$?
assert_equals 0 "$_rc" "ecdsa generation exits 0"
assert_contains "ssh-keygen -t ecdsa -b 256 -f" "$(cat "$KEYGEN_SHIM_LOG")" "default ecdsa bits applied"
assert_contains "Public key copied to clipboard." "$_out" "cb branch reported"

test_start "macos_agent_down_warns_with_keychain_hint"
_fresh_home agentmac
_out="$(SSH_ADD_RC=1 _keygen "$(_clip_dir wl-copy)" mackey me@example.com)"
_rc=$?
assert_equals 0 "$_rc" "generation still exits 0"
assert_contains "ssh-add --apple-use-keychain" "$_out" "keychain hint printed"
assert_contains "copied to clipboard (Wayland)" "$_out" "wl-copy branch reported"

test_start "clip_exe_and_no_clipboard_branches"
_fresh_home clipexe
_out="$(_keygen "$(_clip_dir clip.exe)" winkey me@example.com)"
assert_equals 0 $? "clip.exe generation exits 0"
assert_contains "copied to clipboard (Windows)" "$_out" "clip.exe branch reported"
_fresh_home noclip
_out="$(_keygen "" bare me@example.com)"
assert_equals 0 $? "no-clipboard generation exits 0"
assert_contains "Clipboard tool not available" "$_out" "missing clipboard warned"

test_start "interactive_mode_reads_rsa_answers_from_stdin"
_fresh_home irsa
: >"$KEYGEN_SHIM_LOG"
_out="$(printf 'ikey\nme@example.com\nrsa\n2048\n' | _keygen "")"
_rc=$?
assert_equals 0 "$_rc" "interactive rsa exits 0"
assert_contains "Enter RSA key length" "$_out" "rsa length prompt shown"
assert_contains "ssh-keygen -t rsa -b 2048 -f $HOME/.ssh/id_rsa_ikey" "$(cat "$KEYGEN_SHIM_LOG")" "stdin answers applied"

test_start "interactive_mode_reads_ecdsa_and_default_type"
_fresh_home iecdsa
: >"$KEYGEN_SHIM_LOG"
_out="$(printf 'ekey\nme@example.com\necdsa\n384\n' | _keygen "")"
assert_equals 0 $? "interactive ecdsa exits 0"
assert_contains "Enter ECDSA key length" "$_out" "ecdsa length prompt shown"
assert_contains "ssh-keygen -t ecdsa -b 384 -f" "$(cat "$KEYGEN_SHIM_LOG")" "ecdsa bits applied"
: >"$KEYGEN_SHIM_LOG"
_out="$(printf 'dkey\nme@example.com\n\n' | _keygen "")"
assert_equals 0 $? "interactive default type exits 0"
assert_contains "ssh-keygen -t ed25519 -f $HOME/.ssh/id_ed25519_dkey" "$(cat "$KEYGEN_SHIM_LOG")" "empty type defaults to ed25519"

test_start "interactive_mode_rejects_unknown_type"
_fresh_home ibad
_out="$(printf 'bkey\nme@example.com\nfoo\n' | _keygen "")"
_rc=$?
assert_equals 1 "$_rc" "interactive bad type exits 1"
assert_contains "Invalid key type: foo" "$_out" "bad type reported"

# Fallback loggers: source keygen through a symlink whose directory has
# no ../utils/logging.sh so the inline log_* definitions are used.
test_start "fallback_loggers_used_when_logging_sh_is_absent"
_iso="$DOTFILES_COV_TMPDIR/iso/security"
mkdir -p "$_iso"
ln -s "$FUNC_FILE" "$_iso/keygen.sh"
_fresh_home fallback
_out="$("$BASH_BIN" -c 'export PATH="$1"; source "$2"; shift 2; keygen "$@"' _ \
  "$_kbin" "$_iso/keygen.sh" fbkey me@example.com 2>&1)"
assert_equals 0 $? "fallback-logger generation exits 0"
assert_contains "[INFO] SSH key successfully generated!" "$_out" "fallback log_info format used"
assert_contains "[WARNING] Clipboard tool not available" "$_out" "fallback log_warning format used"
_out="$("$BASH_BIN" -c 'export PATH="$1"; source "$2"; shift 2; keygen "$@"' _ \
  "$_kbin" "$_iso/keygen.sh" 'bad name' me@example.com 2>&1)"
assert_equals 1 $? "fallback-logger validation exits 1"
assert_contains "[ERROR] Invalid name format" "$_out" "fallback log_error format used"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
