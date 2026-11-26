#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2016,SC2034
# install.sh bootstrap_gum trusts /etc/apt/keyrings/charm.gpg through apt's
# signed-by, which accepts every primary key in the file. The keyring must
# hold exactly the pinned key: a second key appended after it is refused.
#
# install.sh is never run. bootstrap_gum is lifted out of `declare -f main`
# and run with curl serving a throwaway key, sudo and gpg rewriting
# /etc/apt into the sandbox, and apt-get recording its calls.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/module_fixture.sh"

REAL_GPG="$(command -v gpg || true)"
if [[ -z "$REAL_GPG" ]]; then
  echo "SKIP: gpg is not installed"
  echo "RESULTS:0:0:0"
  exit 0
fi

SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT
INST="$SANDBOX/installer"
STUBS="$SANDBOX/stubs"
FAKE="$SANDBOX/root"
export GNUPGHOME="$SANDBOX/gnupg"
mkdir -p "$INST" "$STUBS" "$FAKE" "$GNUPGHOME"
# A PATH holding only ordinary tools, so a gum installed here stays hidden.
dot_fixture_basebin "$SANDBOX/base" tee install chmod
chmod 700 "$GNUPGHOME"
cp "$REPO_ROOT/install.sh" "$INST/install.sh"

env -i HOME="$SANDBOX" PATH="/usr/bin:/bin" "$BASH" --norc --noprofile -c \
  'source "$1" && declare -f main' _ "$INST/install.sh" |
  awk '/^    function bootstrap_gum \(\) *$/ { on = 1 }
       on { print }
       on && /^    };?$/ { on = 0 }' >"$INST/nested.sh"

# Two throwaway primary keys: the pinned one and an attacker's.
gen_key() {
  "$REAL_GPG" --batch --quiet --passphrase '' --quick-gen-key "$1" ed25519 sign never 2>/dev/null
  "$REAL_GPG" --with-colons --list-keys "$1" | awk -F: '/^fpr:/ { print $10; exit }'
}
PIN_FPR="$(gen_key 'Pinned <pinned@example.invalid>')"
EVIL_FPR="$(gen_key 'Evil <evil@example.invalid>')"
"$REAL_GPG" --armor --export "$PIN_FPR" >"$SANDBOX/pinned.asc"
"$REAL_GPG" --armor --export "$PIN_FPR" "$EVIL_FPR" >"$SANDBOX/pinned-plus-evil.asc"
"$REAL_GPG" --armor --export "$EVIL_FPR" >"$SANDBOX/evil.asc"

# The lifted function with the sandbox key as its pin, whether the pin is
# assigned inside it or at the top of install.sh.
sed "s/CHARM_GPG_EXPECTED_FPR=\"[0-9A-F]\{40\}\"/CHARM_GPG_EXPECTED_FPR=\"$PIN_FPR\"/" \
  "$INST/nested.sh" >"$INST/nested-pinned.sh"

# Rewrite /etc/apt into the sandbox, then run the real command.
cat >"$STUBS/rewrite" <<EOF
#!$BASH
args=()
for a in "\$@"; do
  case "\$a" in /etc/apt*) a="$FAKE\$a" ;; esac
  args+=("\$a")
done
exec "\${args[@]}"
EOF
printf '#!/bin/sh\nexec "%s/rewrite" "$@"\n' "$STUBS" >"$STUBS/sudo"
printf '#!/bin/sh\nexec "%s/rewrite" "%s" "$@"\n' "$STUBS" "$REAL_GPG" >"$STUBS/gpg"
printf '#!/bin/sh\necho "apt-get $*" >>"%s/calls.log"\n' "$SANDBOX" >"$STUBS/apt-get"
chmod +x "$STUBS/rewrite" "$STUBS/sudo" "$STUBS/gpg" "$STUBS/apt-get"

# run_gum <served-key> [gnupghome]: bootstrap_gum on "debian" with curl
# serving the key and GNUPGHOME set to gnupghome (default: the sandbox's);
# prints the return code.
run_gum() {
  local home="${2:-$GNUPGHOME}"
  rm -rf "${FAKE:?}/etc" "$SANDBOX/calls.log"
  printf '#!/bin/sh\nwhile [ $# -gt 0 ]; do [ "$1" = -o ] && { cp "%s" "$2"; exit 0; }; shift; done\nexit 22\n' \
    "$1" >"$STUBS/curl"
  chmod +x "$STUBS/curl"
  env -i HOME="$SANDBOX" PATH="$STUBS:$SANDBOX/base" GNUPGHOME="$home" \
    "$BASH" --norc --noprofile -c 'source "$1"; source "$2"
      OS=Linux target_os=debian
      CHARM_GPG_EXPECTED_FPR="$3"
      rc=0; bootstrap_gum || rc=$?; echo "rc=$rc"' \
    _ "$INST/install.sh" "$INST/nested-pinned.sh" "$PIN_FPR" >"$SANDBOX/out.txt" 2>&1
  sed -n 's/^rc=//p' "$SANDBOX/out.txt"
}

keyring_state() { [[ -e "$FAKE/etc/apt/keyrings/charm.gpg" ]] && echo present || echo absent; }
apt_state() { [[ -s "$SANDBOX/calls.log" ]] && echo called || echo untouched; }

test_start "charm_single_pinned_key_accepted"
rc="$(run_gum "$SANDBOX/pinned.asc")"
assert_equals "0|present|called" "$rc|$(keyring_state)|$(apt_state)" \
  "the pinned key alone is trusted and gum is installed"
assert_equals "apt-get update|apt-get install gum -y" \
  "$(paste -sd'|' "$SANDBOX/calls.log" 2>/dev/null)" \
  "apt-get refreshes the index, then installs gum"

# The caller's GnuPG home is not the keyring's business: a GNUPGHOME that
# does not exist (or that the user cannot write) made gpg exit before it
# listed anything, and the pinned key was refused as "0 key(s)".
test_start "charm_pinned_key_accepted_without_a_usable_gnupg_home"
rc="$(run_gum "$SANDBOX/pinned.asc" "$SANDBOX/no-such-gnupg-home")"
assert_equals "0|present|called" "$rc|$(keyring_state)|$(apt_state)" \
  "the pinned key is trusted whatever state the caller's GnuPG home is in"

# sudo gpg --dearmor writes under root's umask; a strict one (as on the
# GitHub runners) left a keyring the user, and apt's _apt user, could not
# read, and the pinned key was refused as "found 0 key(s)". The sandbox
# runs as one user, so it checks what apt needs: a world-readable keyring
# even when the dearmor runs with umask 0277.
test_start "charm_keyring_is_world_readable_after_a_strict_root_umask"
printf '#!/bin/sh\n[ "$1" = gpg ] && umask 0277\nexec "%s/rewrite" "$@"\n' "$STUBS" >"$STUBS/sudo"
rc="$(run_gum "$SANDBOX/pinned.asc")"
mode="$(stat -c %a "$FAKE/etc/apt/keyrings/charm.gpg" 2>/dev/null || stat -f %Lp "$FAKE/etc/apt/keyrings/charm.gpg" 2>/dev/null)"
assert_equals "0|present|called|644" "$rc|$(keyring_state)|$(apt_state)|$mode" \
  "the pinned key is trusted and the keyring is mode 644"
printf '#!/bin/sh\nexec "%s/rewrite" "$@"\n' "$STUBS" >"$STUBS/sudo"
chmod -R u+rwX "$FAKE" 2>/dev/null || true

test_start "charm_failed_apt_update_skips_install"
printf '#!/bin/sh\necho "apt-get $*" >>"%s/calls.log"\n[ "$1" != update ]\n' "$SANDBOX" >"$STUBS/apt-get"
rc="$(run_gum "$SANDBOX/pinned.asc")"
assert_equals "1|apt-get update" "$rc|$(paste -sd'|' "$SANDBOX/calls.log" 2>/dev/null)" \
  "a failed index refresh fails the bootstrap without installing gum"
printf '#!/bin/sh\necho "apt-get $*" >>"%s/calls.log"\n' "$SANDBOX" >"$STUBS/apt-get"

test_start "charm_appended_second_key_refused"
rc="$(run_gum "$SANDBOX/pinned-plus-evil.asc")"
assert_equals "1|absent|untouched" "$rc|$(keyring_state)|$(apt_state)" \
  "a keyring with a second primary key is refused and removed"

test_start "charm_wrong_key_refused"
rc="$(run_gum "$SANDBOX/evil.asc")"
assert_equals "1|absent|untouched" "$rc|$(keyring_state)|$(apt_state)" \
  "a keyring holding only another key is refused and removed"

test_start "charm_refusal_names_pin"
assert_contains "$PIN_FPR" "$(cat "$SANDBOX/out.txt")" \
  "the refusal names the expected fingerprint"

print_summary
