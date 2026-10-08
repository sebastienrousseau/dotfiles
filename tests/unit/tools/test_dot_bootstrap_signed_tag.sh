#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2016,SC2034
# bin/dot-bootstrap applies the dotfiles with `chezmoi apply --force`, so what
# it applies must be a release tag signed by a key the script itself pins,
# not whatever the default branch holds. chezmoi comes from the nixpkgs
# commit locked in that tag's flake.lock, not the moving registry entry.
#
# No case reaches the network: `git clone` of the GitHub URL is redirected
# to a local fixture repository, and nix is a stub that records its calls.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

BOOTSTRAP="$REPO_ROOT/bin/dot-bootstrap"
REAL_GIT="$(command -v git)"

WORK="$(mktemp -d -t dot-bootstrap-tag.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT
STUBS="$WORK/stubs"
mkdir -p "$STUBS" "$WORK/keys"

# Plain git for the fixture: no user or system config leaks in.
fgit() { env -i HOME="$WORK" PATH="/usr/bin:/bin" GIT_CONFIG_NOSYSTEM=1 "$REAL_GIT" "$@"; }

ssh-keygen -q -t ed25519 -N '' -C trusted -f "$WORK/keys/trusted"
ssh-keygen -q -t ed25519 -N '' -C stranger -f "$WORK/keys/stranger"

# Fixture upstream: v0.0.1 signed by the trusted key, then a newer commit on
# the default branch that a release has not covered.
UP="$WORK/upstream"
fgit init -q -b main "$UP"
fgit -C "$UP" config user.name Tester
fgit -C "$UP" config user.email tester@example.invalid
fgit -C "$UP" config gpg.format ssh
echo released >"$UP/state"
fgit -C "$UP" add state
fgit -C "$UP" commit -q -m release
fgit -C "$UP" -c user.signingkey="$WORK/keys/trusted" tag -s v0.0.1 -m v0.0.1
echo unreleased >"$UP/state"
fgit -C "$UP" commit -q -am unreleased

# The script under test, with its pinned signer replaced by the fixture key.
# It is a copy, so every other line still runs as written.
cp "$BOOTSTRAP" "$WORK/dot-bootstrap"
trusted_pub="$(cut -d' ' -f1,2 "$WORK/keys/trusted.pub")"
sed -i.bak "s|^\(sebastienrousseau@users.noreply.github.com\) ssh-ed25519 .*|\1 $trusted_pub|" "$WORK/dot-bootstrap"

# git: `clone <github url> <dir>` clones the fixture; everything else is real.
cat >"$STUBS/git" <<EOF
#!/bin/sh
if [ "\$1" = clone ]; then
  shift
  set -- clone "$UP" "\$2"
fi
exec "$REAL_GIT" "\$@"
EOF
printf '#!/bin/sh\necho "nix $*" >>"%s/nix.log"\n' "$WORK" >"$STUBS/nix"
chmod +x "$STUBS/git" "$STUBS/nix"

# run_bootstrap <home>: prints the exit status; output in $WORK/out.txt.
run_bootstrap() {
  local rc=0
  mkdir -p "$1"
  : >"$WORK/nix.log"
  env -i HOME="$1" PATH="$STUBS:/usr/bin:/bin" GIT_CONFIG_NOSYSTEM=1 \
    bash "$WORK/dot-bootstrap" >"$WORK/out.txt" 2>&1 </dev/null || rc=$?
  printf '%s' "$rc"
}

test_start "bootstrap_checks_out_signed_tag"
rc="$(run_bootstrap "$WORK/h1")"
assert_equals "0|released" "$rc|$(cat "$WORK/h1/.dotfiles/state" 2>/dev/null)" \
  "the newest signed release is applied, not the default branch"

test_start "bootstrap_pins_chezmoi_to_locked_nixpkgs"
assert_contains "nix shell --inputs-from . nixpkgs#chezmoi -c chezmoi apply --force" "$(cat "$WORK/nix.log")" \
  "chezmoi comes from the nixpkgs locked in the release's flake.lock"

# A newer tag signed by a key the script does not pin.
fgit -C "$UP" -c user.signingkey="$WORK/keys/stranger" tag -s v0.0.2 -m v0.0.2

test_start "bootstrap_refuses_tag_from_unpinned_key"
rc="$(run_bootstrap "$WORK/h2")"
assert_equals "1|" "$rc|$(cat "$WORK/nix.log")" \
  "a release signed by another key stops the bootstrap before anything is applied"

# A newer unsigned tag.
fgit -C "$UP" tag -d v0.0.2 >/dev/null
fgit -C "$UP" tag -a v0.0.3 -m v0.0.3

test_start "bootstrap_refuses_unsigned_tag"
rc="$(run_bootstrap "$WORK/h3")"
assert_equals "1|" "$rc|$(cat "$WORK/nix.log")" "an unsigned release tag stops the bootstrap"

test_start "bootstrap_existing_checkout_moves_to_signed_tag"
fgit -C "$UP" tag -d v0.0.3 >/dev/null
rc="$(run_bootstrap "$WORK/h1")"
assert_equals "0|released" "$rc|$(cat "$WORK/h1/.dotfiles/state" 2>/dev/null)" \
  "an existing checkout is moved to the verified tag instead of pulled"

# No release tag at all.
fgit -C "$UP" tag -d v0.0.1 >/dev/null

test_start "bootstrap_refuses_repo_without_release"
rc="$(run_bootstrap "$WORK/h4")"
assert_equals "1|" "$rc|$(cat "$WORK/nix.log")" "with no signed release nothing is applied"

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
