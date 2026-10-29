#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091
# examples/mise-plugin-dot/bin/install end to end: a curl stub serves a
# fake dot-<v>.tar.gz release (built around the real Makefile.dist) and its
# SHA256SUMS, a dot stub stands in for `dot config init`, and real make and
# tar install into a sandbox install path.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

PLUGIN_INSTALL="${PLUGIN_INSTALL:-$REPO_ROOT/examples/mise-plugin-dot/bin/install}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
REL="$WORK/serve/sebastienrousseau/dotfiles/releases/download/v9.9.9"
mkdir -p "$WORK/bin" "$REL"

# The fake release: the archive layout Makefile.dist installs from.
stage="$WORK/stage/dot-9.9.9"
mkdir -p "$stage"/{bin,lib,scripts,plugins,security,docs,defaults} \
  "$stage"/share/{man/man1,bash-completion/completions,zsh/site-functions,fish/vendor_completions.d}
cp "$REPO_ROOT/tools/release/Makefile.dist" "$stage/Makefile"
printf '#!/bin/sh\necho "dot fake 9.9.9"\n' >"$stage/bin/dot"
chmod +x "$stage/bin/dot"
echo defaults >"$stage/.chezmoiroot"
: >"$stage/share/man/man1/dot.1"
: >"$stage/share/bash-completion/completions/dot"
: >"$stage/share/zsh/site-functions/_dot"
: >"$stage/share/fish/vendor_completions.d/dot.fish"
tar -czf "$REL/dot-9.9.9.tar.gz" -C "$WORK/stage" dot-9.9.9
(cd "$REL" && { sha256sum dot-9.9.9.tar.gz 2>/dev/null || shasum -a 256 dot-9.9.9.tar.gz; } >dot-9.9.9.SHA256SUMS)

# curl stub: serve $SERVE/<path after github.com/>, 404 (exit 22) otherwise.
cat >"$WORK/bin/curl" <<'STUB'
#!/usr/bin/env bash
out="" url=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -o) out="$2"; shift ;;
    http*) url="$1" ;;
  esac
  shift
done
echo "curl $url" >>"$CALLS"
f="$SERVE/${url#https://github.com/}"
[[ -f "$f" ]] || exit 22
cp "$f" "$out"
STUB
# dot stub: records the call and its sandboxing env, then clones a fake
# source into CHEZMOI_SOURCE_DIR (a dot checkout unless CLONE=bare).
cat >"$WORK/bin/dot" <<'STUB'
#!/usr/bin/env bash
echo "dot $* src=$CHEZMOI_SOURCE_DIR cfg=$XDG_CONFIG_HOME" >>"$CALLS"
mkdir -p "$CHEZMOI_SOURCE_DIR"
[[ "${CLONE:-}" == bare ]] && exit 0
mkdir -p "$CHEZMOI_SOURCE_DIR/tools/release"
: >"$CHEZMOI_SOURCE_DIR/tools/release/stage-dot.sh"
printf 'install:\n\tmkdir -p "$(PREFIX)/bin"\n\tprintf "#!/bin/sh\\necho dot from clone\\n" >"$(PREFIX)/bin/dot"\n\tchmod +x "$(PREFIX)/bin/dot"\n' \
  >"$CHEZMOI_SOURCE_DIR/GNUmakefile"
STUB
chmod +x "$WORK/bin/curl" "$WORK/bin/dot"
TOOLPATH="$WORK/bin:$(dirname "$(command -v make)"):/usr/bin:/bin"
N=0

# plugin <version> [VAR=value...]: run bin/install into a fresh install
# path; sets OUT, RC, DEST and CALLS.
plugin() {
  local version="$1"
  shift
  DEST="$WORK/dest$((++N))"
  CALLS="$WORK/calls$N"
  : >"$CALLS"
  OUT="$(env -i ${BASH_ENV:+BASH_ENV="$BASH_ENV"} ${PS4:+PS4="$PS4"} \
    HOME="$WORK/home" PATH="$TOOLPATH" SERVE="$WORK/serve" CALLS="$CALLS" \
    ASDF_INSTALL_VERSION="$version" ASDF_INSTALL_PATH="$DEST" "$@" \
    bash "$PLUGIN_INSTALL" 2>&1)"
  RC=$?
}

test_start "mise_install_tagged_release_installs_the_verified_asset"
plugin v9.9.9
assert_equals "0" "$RC" "install succeeds"
assert_equals "dot fake 9.9.9" "$("$DEST/bin/dot" 2>&1)" "bin/dot runs the release's CLI"
assert_file_exists "$DEST/lib/dotfiles/.chezmoiroot" "the CLI tree is under lib/dotfiles"
assert_contains "curl https://github.com/sebastienrousseau/dotfiles/releases/download/v9.9.9/dot-9.9.9.SHA256SUMS" \
  "$(cat "$CALLS")" "the checksum asset is fetched"

test_start "mise_install_accepts_a_version_without_v"
plugin 9.9.9
assert_equals "0" "$RC" "9.9.9 resolves to tag v9.9.9"

test_start "mise_install_refuses_a_checksum_mismatch"
cp "$REL/dot-9.9.9.SHA256SUMS" "$WORK/sums.bak"
printf '%064d  dot-9.9.9.tar.gz\n' 0 >"$REL/dot-9.9.9.SHA256SUMS"
plugin v9.9.9
assert_not_equals "0" "$RC" "a mismatch fails"
assert_contains "SHA256 mismatch for dot-9.9.9.tar.gz" "$OUT" "and says so"
assert_file_not_exists "$DEST/bin/dot" "nothing is installed"

test_start "mise_install_refuses_an_unverifiable_archive"
rm -f "$REL/dot-9.9.9.SHA256SUMS"
plugin v9.9.9
assert_not_equals "0" "$RC" "no checksum asset fails"
assert_contains "refusing an unverified archive" "$OUT" "fails closed"
assert_file_not_exists "$DEST/bin/dot" "nothing is installed"
cp "$WORK/sums.bak" "$REL/dot-9.9.9.SHA256SUMS"

test_start "mise_install_unknown_release_points_at_supported_installers"
plugin v0.2.502
assert_not_equals "0" "$RC" "a release without the asset fails"
assert_contains "no dot-0.2.502.tar.gz asset" "$OUT" "names the missing asset"
assert_contains "docs/guides/INSTALL.md" "$OUT" "points at the supported installers"

test_start "mise_install_owner_repo_uses_dot_config_init_in_a_sandbox"
plugin alice/cfg
assert_equals "0" "$RC" "install succeeds"
calls="$(cat "$CALLS")"
assert_contains "dot config init alice/cfg --no-apply src=" "$calls" "dot config init, no apply"
assert_false '[[ "$calls" != *" cfg=/"* || "$calls" == *"cfg=$WORK/home/"* ]]' "chezmoi config goes to a private dir, not the user's"
assert_false '[[ "$calls" == *"src= "* || "$calls" == *"src=$WORK/home/"* ]]' "the clone goes to a private dir, not the user's source"
assert_equals "dot from clone" "$("$DEST/bin/dot" 2>&1)" "make install from the clone"

test_start "mise_install_owner_repo_without_the_cli_fails_loudly"
plugin alice/cfg CLONE=bare
assert_not_equals "0" "$RC" "a repo without the CLI fails"
assert_contains "alice/cfg does not carry the dot CLI" "$OUT" "and says why"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
