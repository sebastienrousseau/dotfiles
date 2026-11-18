#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2016
# install.sh clones a release tag on a first install. It used to apply
# whatever the clone held: the tag signature was never checked, and a
# checkout that was not the requested tag only printed a warning. It now
# runs `git verify-tag` against the KEYS.asc signers embedded in install.sh
# and stops, leaving nothing behind, on a bad signature or a HEAD that is
# not the tagged commit.
#
# Two layers: install.sh end to end against stubbed git/chezmoi/curl (as
# the other install tests do), and verify_release_tag against real git with
# a throwaway SSH key.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

WORK="$(mktemp -d -t dot-install-verify-tag.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

# ── install.sh end to end, stubbed ──────────────────────────────────────

# new_case NAME VERIFY_RC HEAD_SHA: stubs where `git verify-tag` exits
# VERIFY_RC, HEAD is HEAD_SHA and the tag's commit is aaaa...
new_case() {
  C="$WORK/$1"
  mkdir -p "$C/bin" "$C/home"
  : >"$C/log"
  printf '#!/usr/bin/env bash\nexit 1\n' >"$C/bin/curl"
  cat >"$C/bin/chezmoi" <<'STUB'
#!/usr/bin/env bash
printf 'chezmoi %s\n' "$*" >>"$TMP_LOG"
exit 0
STUB
  cat >"$C/bin/git" <<STUB
#!/usr/bin/env bash
printf 'git %s\n' "\$*" >>"\$TMP_LOG"
case " \$* " in
  *" clone "*) mkdir -p "\${*: -1}/.git"; exit 0 ;;
  *" verify-tag "*) exit $2 ;;
  *" rev-parse HEAD "*) echo $3; exit 0 ;;
  *" rev-parse "*) echo aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa; exit 0 ;;
  *" config --global "*) exit 1 ;;
esac
exit 0
STUB
  chmod +x "$C/bin/curl" "$C/bin/chezmoi" "$C/bin/git"
}

run_install() {
  RC=0
  OUT="$(env -u SOURCE_DIR -u DOTFILES_PROVISION -u DOTFILES_MINIMAL \
    -u CODESPACES -u REMOTE_CONTAINERS \
    TMP_LOG="$C/log" PATH="$C/bin:/usr/bin:/bin" HOME="$C/home" \
    DOTFILES_NONINTERACTIVE=1 DOTFILES_SILENT=1 \
    bash "$REPO_ROOT/install.sh" v1.2.3 2>&1 </dev/null)" || RC=$?
}

GOOD=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa

test_start "install_verifies_the_release_tag_signature"
new_case good 0 "$GOOD"
run_install
assert_equals "0" "$RC" "a verified tag installs"
assert_contains "verify-tag v1.2.3" "$(cat "$C/log")" "git verify-tag ran on the requested tag"
assert_contains "gpg.ssh.allowedSignersFile=" "$(cat "$C/log")" "against an explicit allowed-signers file"
assert_dir_exists "$C/home/.dotfiles/.git" "the verified clone is the source"

test_start "install_stops_on_a_bad_signature"
new_case badsig 1 "$GOOD"
run_install
assert_not_equals "0" "$RC" "install.sh fails"
assert_contains "failed signature verification" "$OUT" "and says why"
assert_dir_not_exists "$C/home/.dotfiles" "no unverified source is left to apply on a re-run"
assert_equals "" "$(grep '^chezmoi apply' "$C/log")" "chezmoi apply never ran"

test_start "install_stops_when_head_is_not_the_tag"
new_case moved 0 bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
run_install
assert_not_equals "0" "$RC" "a ref mismatch is fatal, not a warning"
assert_dir_not_exists "$C/home/.dotfiles" "and leaves no source behind"
assert_equals "" "$(grep '^chezmoi apply' "$C/log")" "chezmoi apply never ran"

# ── the embedded trust root ─────────────────────────────────────────────

test_start "embedded_signers_match_keys_asc"
embedded="$(bash -c 'source "$1" >/dev/null 2>&1; printf "%s\n" "$DOTFILES_ALLOWED_SIGNERS"' _ "$REPO_ROOT/install.sh")"
assert_not_empty "$embedded" "install.sh embeds allowed signers"
assert_equals "$(awk '!/^#/ && NF' "$REPO_ROOT/KEYS.asc")" "$embedded" \
  "the embedded signers are exactly KEYS.asc's key lines"

# ── verify_release_tag against real git ─────────────────────────────────

if ! command -v ssh-keygen >/dev/null 2>&1; then
  echo "SKIP: ssh-keygen not available for the real-git cases"
  echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
  exit "$((TESTS_FAILED > 0))"
fi

R="$WORK/real"
mkdir -p "$R"
ssh-keygen -q -t ed25519 -N '' -C trusted -f "$R/trusted" >/dev/null
ssh-keygen -q -t ed25519 -N '' -C other -f "$R/other" >/dev/null
TRUSTED_SIGNERS="tester@example.invalid namespaces=\"git\" $(cut -d' ' -f1,2 "$R/trusted.pub")"

g() { git -C "$R/repo" -c commit.gpgsign=false -c tag.gpgSign=false -c user.name=t -c user.email=tester@example.invalid -c gpg.format=ssh "$@"; }
git init -q "$R/repo"
g commit -q --allow-empty -m one
g -c user.signingkey="$R/trusted" tag -s -m signed v1.0.0
g -c user.signingkey="$R/other" tag -s -m other v1.0.1
g tag -a -m unsigned v1.0.2

verify() { (source "$REPO_ROOT/install.sh" >/dev/null 2>&1 && verify_release_tag "$R/repo" "$1" "$TRUSTED_SIGNERS"); }

test_start "real_git_accepts_a_tag_signed_by_an_allowed_key"
verify v1.0.0
assert_equals "0" "$?" "good signature, HEAD at the tag"

test_start "real_git_rejects_a_tag_signed_by_another_key"
verify v1.0.1
assert_not_equals "0" "$?" "signature from a key not in the signers"

test_start "real_git_rejects_an_unsigned_tag"
verify v1.0.2
assert_not_equals "0" "$?" "annotated but unsigned"

test_start "real_git_rejects_head_off_the_tag"
g commit -q --allow-empty -m two
verify v1.0.0
assert_not_equals "0" "$?" "good tag, but HEAD is another commit"

test_start "real_git_default_signers_reject_a_foreign_key"
(source "$REPO_ROOT/install.sh" >/dev/null 2>&1 && g checkout -q v1.0.0 && verify_release_tag "$R/repo" v1.0.0)
assert_not_equals "0" "$?" "the embedded signers do not trust the throwaway key"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
