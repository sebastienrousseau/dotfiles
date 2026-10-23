#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2016,SC2034
# Behaviour of dot_local/bin/executable_corralctl-gitea-mirror.sh: the mirror
# tree must hold exactly the source forge's branches and tags, and sync must
# leave Gitea identical to it. Local bare repositories stand in for GitHub
# and Gitea, a pre-receive hook enforces Gitea's "the default branch cannot
# be deleted" rule, and stubs replace gh, curl (the Gitea API) and corralctl,
# so nothing leaves the machine.
#
# AUTO-GENERATED: false (hand-written, do not regenerate)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

SCRIPT_FILE="$REPO_ROOT/defaults/dot_local/bin/executable_corralctl-gitea-mirror.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
SRC="$WORK/src/acme"
GITEA="$WORK/gitea/acme"
MIRROR="$WORK/mirror"
DEFAULTS="$WORK/gitea-default"
mkdir -p "$SRC" "$GITEA" "$DEFAULTS" "$WORK/stub"

# Every git call ignores the host's config: a global fetch.prune=true once
# masked a missing --prune in the script.
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
_git() { git -c user.name=t -c user.email=t@t -c commit.gpgsign=false -c tag.gpgsign=false "$@"; }

# A source repo with main, a PR branch and a tag.
_mk_source() { # name
  local seed="$WORK/seed-$1"
  _git init -q -b main "$seed"
  _git -C "$seed" commit -q --allow-empty -m "c1 $1"
  _git -C "$seed" tag v1
  _git -C "$seed" branch pr-1
  _git clone -q --bare "$seed" "$SRC/$1.git"
}
_mk_source alpha
_mk_source beta

# A Gitea copy seeded from <from> plus extra refs, whose default is <default>.
_mk_gitea() { # name default
  _git init -q --bare "$GITEA/$1.git"
  printf '%s\n' "$2" >"$DEFAULTS/$1"
  cat >"$GITEA/$1.git/hooks/pre-receive" <<EOF
#!/usr/bin/env bash
def="\$(cat "$DEFAULTS/$1")"
while read -r old new ref; do
  if [[ "\$new" == 0000000000000000000000000000000000000000 && "\$ref" == "refs/heads/\$def" ]]; then
    echo "Branch \$def is the default branch and cannot be deleted" >&2; exit 1
  fi
done
EOF
  chmod +x "$GITEA/$1.git/hooks/pre-receive"
}

# gh prints the TSV the script's --jq would produce; corralctl does nothing,
# so convergence is entirely the script's own; curl serves the Gitea API
# from $DEFAULTS and logs every call.
printf '#!/usr/bin/env bash\ncat "%s"\n' "$WORK/list.tsv" >"$WORK/stub/gh"
printf '#!/usr/bin/env bash\nexit 1\n' >"$WORK/stub/corralctl"
cat >"$WORK/stub/curl" <<EOF
#!/usr/bin/env bash
echo "\$*" >>"$WORK/argv.log"
method=GET data= url=
while [[ \$# -gt 0 ]]; do
  case "\$1" in
  -X) method="\$2"; shift ;;
  --data) data="\$2"; shift ;;
  -H) [[ "\$2" == @* ]] && grep -q '^Authorization: token test-token$' "\${2#@}" || [[ "\$2" != @* ]] || exit 9; shift ;;
  http*) url="\$1" ;;
  esac
  shift
done
name="\${url##*/}"
echo "\$method \$name \$data" >>"$WORK/api.log"
[[ -f "$DEFAULTS/\$name" ]] || exit 22
case "\$method" in
GET) printf '{"name":"%s","default_branch":"%s"}\n' "\$name" "\$(cat "$DEFAULTS/\$name")" ;;
PATCH) sed -E 's/.*"default_branch":"([^"]*)".*/\1/' <<<"\$data" >"$DEFAULTS/\$name" ;;
esac
EOF
chmod +x "$WORK/stub/gh" "$WORK/stub/corralctl" "$WORK/stub/curl"
_list() { printf '%s\n' "$@" | tr '|' '\t' >"$WORK/list.tsv"; }

_run() {
  PATH="$WORK/stub:$PATH" CORRAL_OWNER=acme CORRAL_MIRROR_DIR="$MIRROR" \
    CORRAL_SOURCE_URL="file://$WORK/src" CORRAL_GITEA_GIT_BASE="file://$WORK/gitea/" \
    CORRAL_RETRY_SLEEP=0 CORRAL_JOBS=2 GITEA_URL=http://gitea.test GITEA_TOKEN=test-token \
    bash "$SCRIPT_FILE" "$@" 2>&1
}
_refs() { git -C "$1" for-each-ref --format='%(objectname) %(refname)' refs/heads refs/tags | sort; }
_src_refs() { _refs "$SRC/$1.git"; }

# ── refresh ───────────────────────────────────────────────────────────────

test_start "mirror_refresh_copies_every_branch_and_tag"
_list "alpha|public|python|main" "beta|private|rust|main"
_run refresh >/dev/null
assert_equals "$(_src_refs alpha)" "$(_refs "$MIRROR/public/python/alpha")" "alpha mirrors main, pr-1 and v1"
assert_equals "$(_src_refs beta)" "$(_refs "$MIRROR/private/rust/beta")" "visibility and language set the path"

test_start "mirror_refresh_prunes_and_forces"
_git -C "$SRC/alpha.git" branch -D pr-1 >/dev/null
moved="$(_git -C "$SRC/alpha.git" commit-tree -m c2 -p main 'main^{tree}')"
_git -C "$SRC/alpha.git" update-ref refs/heads/main "$moved"
_git -C "$SRC/alpha.git" tag -f v1 "$moved" >/dev/null
_run refresh >/dev/null
assert_equals "$(_src_refs alpha)" "$(_refs "$MIRROR/public/python/alpha")" "deleted branch pruned, moved tag forced"

test_start "mirror_refresh_moves_on_language_change"
_list "alpha|public|go|main" "beta|private|rust|main"
out="$(_run refresh)"
assert_dir_exists "$MIRROR/public/go/alpha/.git" "repo follows its new primary language"
assert_dir_not_exists "$MIRROR/public/python/alpha" "old location is gone"
assert_contains "MOVE  alpha" "$out" "the move is reported"

test_start "mirror_refresh_drops_repos_gone_from_source"
_list "alpha|public|go|main"
out="$(_run refresh)"
assert_dir_not_exists "$MIRROR/private/rust/beta" "a repo no longer listed leaves the mirror tree"
assert_contains "GONE  beta" "$out" "the removal is reported"

test_start "mirror_refresh_refuses_empty_listing"
: >"$WORK/list.tsv"
_run refresh >/dev/null
assert_equals "1" "$?" "an empty listing fails"
assert_dir_exists "$MIRROR/public/go/alpha/.git" "and deletes nothing"

# ── sync ──────────────────────────────────────────────────────────────────

# Gitea's alpha has drifted the way the NAS copies had: its default is a
# stale branch GitHub no longer has, main has diverged, and there is a
# Gitea-only tag.
_mk_gitea alpha stale
c1="$(git -C "$SRC/alpha.git" rev-parse "$moved^")"
_git -C "$SRC/alpha.git" push -q "$GITEA/alpha.git" "$c1:refs/heads/stale"
old_main="$(_git -C "$GITEA/alpha.git" commit-tree -m gitea-only "$c1^{tree}")"
git -C "$GITEA/alpha.git" update-ref refs/heads/main "$old_main"
git -C "$GITEA/alpha.git" update-ref refs/tags/gitea-only "$old_main"
_list "alpha|public|go|main"

test_start "mirror_sync_converges_drifted_gitea"
out="$(_run sync)"
rc=$?
assert_equals "0" "$rc" "sync succeeds once gitea matches"
assert_equals "$(_src_refs alpha)" "$(_refs "$GITEA/alpha.git")" "gitea holds exactly GitHub's branches and tags"
assert_equals "main" "$(cat "$DEFAULTS/alpha")" "gitea default branch follows GitHub's"
assert_contains "DEFAULT alpha stale -> main" "$out" "the default change is reported"
assert_contains "FORCE alpha was $old_main refs/heads/main" "$out" "the overwritten ref is logged with its old hash"
assert_contains "verify: 1 identical, 0 different" "$out" "verify confirms parity"

test_start "mirror_sync_authenticates_without_token_in_argv"
assert_true 'grep -q "^PATCH alpha" "$WORK/api.log"' "the default branch is changed through the API"
assert_false 'grep -q test-token "$WORK/argv.log"' "the token never appears on a command line"

test_start "mirror_sync_is_idempotent"
: >"$WORK/api.log"
out="$(_run sync)"
assert_equals "0" "$?" "a second sync succeeds"
assert_false 'grep -q "^FORCE\|^DEFAULT" <<<"$out"' "and changes nothing"

test_start "mirror_sync_fails_when_gitea_cannot_converge"
_list "alpha|public|go|main" "beta|private|rust|main"
_run refresh >/dev/null # beta is back on GitHub but has no Gitea repo
out="$(_run sync)"
assert_equals "1" "$?" "sync fails while a repository differs"
assert_contains "DIFF  beta" "$out" "and names it"
assert_contains "FAIL  beta (cannot read gitea refs; not forcing)" "$out" \
  "an unreadable gitea copy is never force-pushed blind"

test_start "mirror_rejects_unknown_command"
_run bogus >/dev/null
assert_equals "2" "$?" "usage error exits 2"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
