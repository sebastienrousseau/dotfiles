#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Mode and backend tests for the `hash` CLI.
#
# get_hash_cmd() picks a backend per algorithm with a three-way
# preference (GNU *sum, then the BSD/macOS tool, then openssl). Which
# arm runs depends entirely on what is installed, so each case below
# runs the script with a PATH holding only the backends that arm needs.
# The expected digests are the published values for "hello".

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

# The assertions below capture each child's stdout and stderr, which
# would also swallow the xtrace records the repo's coverage runner reads
# from stderr. Hand every child a copy of this test's real stderr on
# fd 21 and point BASH_XTRACEFD at it, so its line records still reach
# the runner while the captured text stays clean.
exec 21>&2

HASH_FILE="$REPO_ROOT/defaults/dot_local/bin/executable_hash"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

TMP="$DOTFILES_COV_TMPDIR"

# Known digests of the exact string "hello" (no trailing newline).
MD5_HELLO="5d41402abc4b2a76b9719d911017c592"
SHA1_HELLO="aaf4c61ddcc5e8a2dabede0f3b482cd9aea9434d"
SHA256_HELLO="2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"
SHA512_HELLO="9b71d224bd62f3785d96d46ad3ea3d73319bfbc2890caadae2dff72519673ca72323c3d99ba5c11d7c7acc6e14b8c5da0c4663475c2e5c3adef46f73bcdec043"

# ── Backend sets ───────────────────────────────────────────────────────
# gnu:     md5sum / sha1sum / sha256sum / sha512sum
# bsd:     md5 -q / shasum -a N
# openssl: neither of the above, only `openssl`
_mkbin() {
  local dir="$TMP/hash-$1"
  shift
  mkdir -p "$dir"
  local tool p
  for tool in awk tr cat env printf head sed grep "$@"; do
    p="$(command -v "$tool" 2>/dev/null || true)"
    [[ -n "$p" ]] && ln -sf "$p" "$dir/$tool"
  done
  ln -sf "$BASH" "$dir/bash"
  printf '%s' "$dir"
}

# Portable stand-ins so the suite does not depend on which digest tools
# the host happens to ship. Each writes "<digest>  <name>" like the real
# tool, computed with python3's hashlib.
_mkdigest() {
  local dir="$1" name="$2" algo="$3" style="$4"
  cat >"$dir/$name" <<EOF
#!/usr/bin/env bash
# style=$style
_data() {
  if [[ "\$#" -gt 0 ]]; then
    for a in "\$@"; do
      case "\$a" in -*) continue ;; esac
      cat "\$a"
      return
    done
  fi
  cat
}
_data "\$@" | python3 -c '
import hashlib, sys
print(hashlib.new("$algo", sys.stdin.buffer.read()).hexdigest())
' | {
  read -r d
  case "$style" in
    plain) printf "%s\\n" "\$d" ;;
    *) printf "%s  -\\n" "\$d" ;;
  esac
}
EOF
  chmod +x "$dir/$name"
}

GNU_BIN="$(_mkbin gnu python3)"
_mkdigest "$GNU_BIN" md5sum md5 sum
_mkdigest "$GNU_BIN" sha1sum sha1 sum
_mkdigest "$GNU_BIN" sha256sum sha256 sum
_mkdigest "$GNU_BIN" sha512sum sha512 sum

BSD_BIN="$(_mkbin bsd python3)"
_mkdigest "$BSD_BIN" md5 md5 plain
cat >"$BSD_BIN/shasum" <<'EOF'
#!/usr/bin/env bash
algo=1
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    -a)
      algo="$2"
      shift 2
      ;;
    *) break ;;
  esac
done
_src() {
  if [[ "$#" -gt 0 ]]; then cat "$1"; else cat; fi
}
_src "$@" | python3 -c "
import hashlib, sys
print(hashlib.new('sha$algo', sys.stdin.buffer.read()).hexdigest())
" | { read -r d && printf '%s  -\n' "$d"; }
EOF
chmod +x "$BSD_BIN/shasum"

OSSL_BIN="$(_mkbin openssl python3)"
cat >"$OSSL_BIN/openssl" <<'EOF'
#!/usr/bin/env bash
algo="${1:-sha256}"
shift || true
_src() {
  for a in "$@"; do
    case "$a" in -*) continue ;; esac
    cat "$a"
    return
  done
  cat
}
_src "$@" | python3 -c "
import hashlib, sys
print(hashlib.new('$algo', sys.stdin.buffer.read()).hexdigest())
" | { read -r d && printf '%s *-\n' "$d"; }
EOF
chmod +x "$OSSL_BIN/openssl"

H_OUT=""
H_RC=0
# _run_hash <bindir> <stdin> [args...]
_run_hash() {
  local bindir="$1" stdin_text="$2"
  shift 2
  H_RC=0
  H_OUT="$(
    printf '%s' "$stdin_text" |
      env BASH_XTRACEFD=21 PATH="$bindir" HOME="$TMP/hash-home" \
        "$BASH" "$HASH_FILE" "$@" 2>&1
  )" || H_RC=$?
}

_h_expect() {
  local label="$1" want_rc="$2"
  shift 2
  local needle problems=""
  [[ "$H_RC" == "$want_rc" ]] || problems="${problems}\n      rc: want $want_rc, got $H_RC"
  for needle in "$@"; do
    [[ "$H_OUT" == *"$needle"* ]] || problems="${problems}\n      missing: $needle"
  done
  test_start "$label"
  if [[ -z "$problems" ]]; then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
  else
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST$problems"
    printf '%s\n' "$H_OUT" | sed 's/^/      /'
  fi
}

mkdir -p "$TMP/hash-home"

# =======================================================================
# 1. Help and unknown options.
# =======================================================================
_run_hash "$GNU_BIN" "" --help
_h_expect "help_lists_algorithms_and_options" 0 \
  "Usage: hash [OPTIONS] [INPUT]" "-m, --md5" "-5, --sha512" "-c, --check" \
  "hash -a 'hello'"

_run_hash "$GNU_BIN" "" -h
_h_expect "short_help_flag" 0 "Usage: hash [OPTIONS] [INPUT]"

_run_hash "$GNU_BIN" "" --nope
_h_expect "unknown_option_exits_1" 1 "Unknown option: --nope" "Usage: hash"

# =======================================================================
# 2. Each algorithm flag, long and short, against the GNU backends.
# =======================================================================
_run_hash "$GNU_BIN" "" hello
_h_expect "default_algorithm_is_sha256" 0 "$SHA256_HELLO"

_run_hash "$GNU_BIN" "" -m hello
_h_expect "md5_short_flag" 0 "$MD5_HELLO"

_run_hash "$GNU_BIN" "" --md5 hello
_h_expect "md5_long_flag" 0 "$MD5_HELLO"

_run_hash "$GNU_BIN" "" -1 hello
_h_expect "sha1_short_flag" 0 "$SHA1_HELLO"

_run_hash "$GNU_BIN" "" --sha1 hello
_h_expect "sha1_long_flag" 0 "$SHA1_HELLO"

_run_hash "$GNU_BIN" "" -2 hello
_h_expect "sha256_short_flag" 0 "$SHA256_HELLO"

_run_hash "$GNU_BIN" "" --sha256 hello
_h_expect "sha256_long_flag" 0 "$SHA256_HELLO"

_run_hash "$GNU_BIN" "" -5 hello
_h_expect "sha512_short_flag" 0 "$SHA512_HELLO"

_run_hash "$GNU_BIN" "" --sha512 hello
_h_expect "sha512_long_flag" 0 "$SHA512_HELLO"

# =======================================================================
# 3. --all, and reading the input from stdin when no argument is given.
# =======================================================================
_run_hash "$GNU_BIN" "" --all hello
_h_expect "all_mode_prints_every_digest" 0 \
  "MD5:    $MD5_HELLO" "SHA1:   $SHA1_HELLO" \
  "SHA256: $SHA256_HELLO" "SHA512: $SHA512_HELLO"

_run_hash "$GNU_BIN" $'hello\n' -a
_h_expect "all_mode_short_flag_reads_stdin" 0 "MD5:    $MD5_HELLO"

_run_hash "$GNU_BIN" $'hello\n'
_h_expect "input_read_from_stdin" 0 "$SHA256_HELLO"

# =======================================================================
# 4. File mode, including the missing-file guard.
# =======================================================================
printf 'hello' >"$TMP/hash-home/payload.txt"
_run_hash "$GNU_BIN" "" --file "$TMP/hash-home/payload.txt"
_h_expect "file_mode_hashes_file_contents" 0 "$SHA256_HELLO"

_run_hash "$GNU_BIN" "" -f "$TMP/hash-home/payload.txt"
_h_expect "file_mode_short_flag" 0 "$SHA256_HELLO"

_run_hash "$GNU_BIN" "" -f "$TMP/hash-home/absent.txt"
_h_expect "file_mode_missing_file_exits_1" 1 "Error: File not found:"

# =======================================================================
# 5. Check mode, matching and mismatching.
# =======================================================================
_run_hash "$GNU_BIN" "" --check "$SHA256_HELLO" hello
_h_expect "check_mode_match_exits_0" 0 "Hash matches"

# Uppercased with tr, not ${VAR^^}: that expansion is bash 4+, and on
# bash 3.2 it fails as a bad substitution, leaving the assertion below to
# re-inspect the previous run instead of this one.
SHA256_HELLO_UPPER="$(printf '%s' "$SHA256_HELLO" | tr '[:lower:]' '[:upper:]')"
_run_hash "$GNU_BIN" "" -c "$SHA256_HELLO_UPPER" hello
_h_expect "check_mode_is_case_insensitive" 0 "Hash matches"

_run_hash "$GNU_BIN" "" -c deadbeef hello
_h_expect "check_mode_mismatch_exits_1" 1 \
  "Hash mismatch" "Expected: deadbeef" "Got:      $SHA256_HELLO"

# =======================================================================
# 6. Backend selection: BSD tools, then openssl only.
# =======================================================================
_run_hash "$BSD_BIN" "" --all hello
_h_expect "bsd_backends_selected" 0 \
  "MD5:    $MD5_HELLO" "SHA1:   $SHA1_HELLO" \
  "SHA256: $SHA256_HELLO" "SHA512: $SHA512_HELLO"

_run_hash "$OSSL_BIN" "" --all hello
_h_expect "openssl_fallback_selected" 0 \
  "MD5:    $MD5_HELLO" "SHA1:   $SHA1_HELLO" \
  "SHA256: $SHA256_HELLO" "SHA512: $SHA512_HELLO"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
